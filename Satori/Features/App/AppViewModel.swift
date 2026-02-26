import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var settings: AppSettings = .default
    @Published var wsStatus: WebSocketConnectionStatus = .disconnected
    @Published var lastMessageAt: Date?
    @Published var latencyMs: Double = 0
    @Published var correlationAlerts: [CorrelationAlert] = []

    @Published var dashboardSnapshot: DashboardSnapshot?
    @Published var statusResponse: StatusResponse?
    @Published var positions: [PositionRecord] = []
    @Published var trades: [TradeRecord] = []
    @Published var riskMetrics: RiskMetrics?
    @Published var pdtStatus: PdtStatus?
    @Published var strategies: [StrategySummary] = []
    @Published var strategyDetail: [String: StrategyDetail] = [:]
    @Published var universe: UniverseSnapshot?
    @Published var artifactRuns: [RunArtifactSummary] = []

    @Published var commandLog: CommandLogState?
    @Published var infoBanner: String = ""
    @Published var errorMessage: String?

    var presentedErrorMessage: String? {
        guard let errorMessage else { return nil }
        if errorMessage.hasPrefix("Refresh failed:") {
            return nil
        }
        return errorMessage
    }

    let webSocketService: WebSocketServiceProtocol
    let restClient: RESTClientProtocol
    let cliService: CLIServiceProtocol
    let artifactStore: ArtifactStoreProtocol
    private let settingsStore: SettingsStore

    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var isRefreshing = false

    init(
        webSocketService: WebSocketServiceProtocol? = nil,
        restClient: RESTClientProtocol? = nil,
        cliService: CLIServiceProtocol? = nil,
        artifactStore: ArtifactStoreProtocol? = nil,
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.webSocketService = webSocketService ?? WebSocketService()
        self.restClient = restClient ?? RESTClient()
        self.cliService = cliService ?? CLIService()
        self.artifactStore = artifactStore ?? ArtifactStore()
        self.settingsStore = settingsStore

        self.webSocketService.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.wsStatus = $0 }
            .store(in: &cancellables)

        self.webSocketService.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                dashboardSnapshot = snapshot
                if let snapshotRisk = snapshot.riskMetrics {
                    riskMetrics = snapshotRisk
                }
                if let snapshotTrades = snapshot.recentTrades {
                    trades = snapshotTrades
                }
                if let snapshotStrategies = snapshot.strategies {
                    strategies = snapshotStrategies.map { key, value in
                        StrategySummary(
                            name: key,
                            state: value.state,
                            enabled: true,
                            intraday: nil,
                            signals: value.signals,
                            openPositions: value.positions,
                            tradesToday: value.tradesToday,
                            pnlToday: value.pnlToday,
                            pnlTotal: nil,
                            pnl: value.pnl,
                            winRatePct: nil,
                            pnlHistory: nil
                        )
                    }
                    .sorted { $0.name < $1.name }
                }
                if let snapshotPortfolio = snapshot.portfolio {
                    positions = snapshotPortfolio.positions
                }
            }
            .store(in: &cancellables)

        self.webSocketService.correlationAlertPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.correlationAlerts = $0.alerts }
            .store(in: &cancellables)

        self.webSocketService.lastMessageAtPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lastMessageAt = $0 }
            .store(in: &cancellables)

        self.webSocketService.latencyPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.latencyMs = $0 }
            .store(in: &cancellables)

        self.webSocketService.decodeErrorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self else { return }
                if case let WebSocketDecodeError.contractMismatch(consecutiveCount, _) = error {
                    infoBanner = "Dashboard contract mismatch (\(consecutiveCount) decode errors) — verify engine version."
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        refreshTask?.cancel()
        webSocketService.disconnect()
    }

    func start() {
        Task {
            settings = await settingsStore.load()
            webSocketService.configure(
                baseReconnectSeconds: settings.reconnectBaseSeconds,
                maxReconnectSeconds: settings.reconnectMaxSeconds
            )
            if let endpoints = resolvedEndpoints(from: settings, showBlockingErrors: false) {
                webSocketService.connect(url: endpoints.wsURL)
            }
            await refreshAll()
            startRefreshLoop()
        }
    }

    func stop() {
        refreshTask?.cancel()
        webSocketService.disconnect()
    }

    func saveSettings(_ updated: AppSettings) {
        Task {
            do {
                guard let endpoints = resolvedEndpoints(from: updated, showBlockingErrors: true) else {
                    return
                }
                try await settingsStore.save(updated)
                settings = updated
                webSocketService.configure(
                    baseReconnectSeconds: settings.reconnectBaseSeconds,
                    maxReconnectSeconds: settings.reconnectMaxSeconds
                )
                webSocketService.connect(url: endpoints.wsURL)
                await refreshAll()
                infoBanner = "Settings saved"
            } catch {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
            }
        }
    }

    func testConnection(_ candidate: AppSettings) async -> SettingsConnectionTestState {
        guard let endpoints = resolvedEndpoints(from: candidate, showBlockingErrors: false) else {
            return .failure("Invalid server settings")
        }

        do {
            let status = try await restClient.fetchStatus(baseURL: endpoints.apiURL)
            let stamp = status.timestamp?.formatted(date: .omitted, time: .shortened) ?? "unknown"
            return .success("Connected (engine: \(status.engineState), timestamp: \(stamp))")
        } catch {
            return .failure(shortError(error))
        }
    }

    func refreshAll(showBlockingError: Bool = false) async {
        if isRefreshing {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let endpoints = resolvedEndpoints(from: settings, showBlockingErrors: showBlockingError) else {
            return
        }

        var issues: [String] = []

        func capture(_ label: String, operation: () async throws -> Void) async {
            do {
                try await operation()
            } catch {
                issues.append("\(label): \(shortError(error))")
            }
        }

        await capture("status") { statusResponse = try await restClient.fetchStatus(baseURL: endpoints.apiURL) }
        await capture("positions") { positions = try await restClient.fetchPositions(baseURL: endpoints.apiURL) }
        await capture("trades") { trades = try await restClient.fetchTrades(baseURL: endpoints.apiURL, limit: 50, symbol: nil, strategy: nil, date: nil) }
        await capture("risk") { riskMetrics = try await restClient.fetchRisk(baseURL: endpoints.apiURL) }
        await capture("pdt") { pdtStatus = try await restClient.fetchPdt(baseURL: endpoints.apiURL) }
        await capture("strategies") { strategies = try await restClient.fetchStrategies(baseURL: endpoints.apiURL) }
        await capture("strategy detail") { strategyDetail = try await restClient.fetchStrategiesDetail(baseURL: endpoints.apiURL) }
        await capture("universe") { universe = try await restClient.fetchUniverse(baseURL: endpoints.apiURL) }
        await capture("artifacts") { artifactRuns = try await artifactStore.indexRuns(root: URL(fileURLWithPath: settings.runsRootPath)) }

        if issues.isEmpty {
            if infoBanner.hasPrefix("Refresh issues:") {
                infoBanner = ""
            }
        } else {
            let summary = "Refresh issues: \(issues.joined(separator: "  •  "))"
            if showBlockingError {
                errorMessage = summary
            } else {
                infoBanner = summary
            }
        }
    }

    func dismissCommandLog() {
        commandLog = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    func openMonitor() {
        guard let endpoints = resolvedEndpoints(from: settings, showBlockingErrors: true) else {
            return
        }
        do {
            let request = MonitorLaunchRequest(
                executablePath: settings.cliPath,
                wsURL: endpoints.wsURL,
                workingDirectory: URL(fileURLWithPath: settings.engineRootPath)
            )
            try cliService.launchMonitor(request)
            infoBanner = "Launched monitor in Terminal"
        } catch {
            errorMessage = "Failed to launch monitor: \(error.localizedDescription)"
        }
    }

    func runBacktest(_ input: BacktestLaunchInput) {
        runCLI(
            title: "Backtest",
            arguments: [
                "backtest", "run",
                "--strategy", input.strategy,
                "--start", input.startDate,
                "--end", input.endDate,
                "--config", input.configPath
            ]
        )
    }

    func runValidate(_ input: ValidateLaunchInput) {
        var args = ["validate", "--result", input.resultPath, "--folds", String(input.folds), "--permutations", String(input.permutations)]
        if input.resultPath.isEmpty {
            args = ["validate"]
        }
        runCLI(title: "Validate", arguments: args)
    }

    func runPromote(_ input: PromoteLaunchInput) {
        var args = ["promote", input.strategy, input.returnsCSV, input.equityCSV, "--config", input.configPath]
        if input.override {
            args.append("--override")
        }
        if input.returnsCSV.isEmpty || input.equityCSV.isEmpty {
            errorMessage = "returns_csv and equity_csv are required for promote"
            return
        }
        runCLI(title: "Promote", arguments: args)
    }

    func refreshArtifacts() {
        Task {
            do {
                artifactRuns = try await artifactStore.indexRuns(root: URL(fileURLWithPath: settings.runsRootPath))
            } catch {
                errorMessage = "Failed to refresh artifacts: \(error.localizedDescription)"
            }
        }
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await refreshAll()
            }
        }
    }

    private func runCLI(title: String, arguments: [String]) {
        let request = CLIRequest(
            executablePath: settings.cliPath,
            arguments: arguments,
            workingDirectory: URL(fileURLWithPath: settings.engineRootPath)
        )
        commandLog = CommandLogState(title: title, lines: ["$ \(settings.cliPath) \(arguments.joined(separator: " "))"], running: true, exitCode: nil)

        Task {
            do {
                for try await event in cliService.run(request) {
                    switch event {
                    case .stdout(let text):
                        appendToLog(text)
                    case .stderr(let text):
                        appendToLog("[stderr] \(text)")
                    case .timeout(let elapsed):
                        appendToLog("[timeout] command exceeded \(Int(elapsed))s")
                        commandLog?.running = false
                        commandLog?.exitCode = -1
                        infoBanner = "Command timed out after \(Int(elapsed))s"
                    case .didExit(let code):
                        commandLog?.running = false
                        commandLog?.exitCode = code
                    }
                }
                await refreshAll()
            } catch {
                appendToLog("[error] \(error.localizedDescription)")
                commandLog?.running = false
            }
        }
    }

    private func appendToLog(_ text: String) {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.isEmpty }
        commandLog?.lines.append(contentsOf: lines)
    }

    private func resolvedEndpoints(from settings: AppSettings, showBlockingErrors: Bool) -> (apiURL: URL, wsURL: URL)? {
        guard let apiURL = settings.baseAPIURL, let wsURL = settings.wsURL else {
            let message = "Invalid server settings. Check scheme, host, port, and endpoint paths."
            if showBlockingErrors {
                errorMessage = message
            } else {
                infoBanner = message
            }
            return nil
        }
        return (apiURL, wsURL)
    }

    private func shortError(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .typeMismatch:
                return "unexpected response shape"
            case .valueNotFound:
                return "missing value in response"
            case .keyNotFound(let key, _):
                return "missing key '\(key.stringValue)'"
            case .dataCorrupted:
                return "corrupt response payload"
            @unknown default:
                return "decode error"
            }
        }
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }
        return error.localizedDescription
    }
}
