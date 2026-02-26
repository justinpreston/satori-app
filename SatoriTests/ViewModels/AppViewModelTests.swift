import Foundation
import Testing
@testable import Satori

@MainActor
struct AppViewModelTests {
    @Test
    func refreshAllLoadsSnapshotAndServiceData() async throws {
        let webSocket = MockWebSocketService()
        let rest = MockRESTClient()
        let cli = MockCLIService()
        let artifacts = MockArtifactStore()
        let settingsStore = makeSettingsStore()

        rest.positionsResult = .success([
            PositionRecord(symbol: "AAPL", qty: 10, avgPrice: 180, marketValue: 1_800, unrealizedPnL: 45),
        ])
        rest.tradesResult = .success([
            TradeRecord(orderID: "ord-1", symbol: "AAPL", side: "BUY", qty: 10, price: 180, strategy: "surge", timestamp: Date(timeIntervalSince1970: 1_700_000_100), slippageBps: nil, latencyMs: nil),
        ])
        rest.strategiesResult = .success([
            StrategySummary(
                name: "surge",
                state: "active",
                enabled: true,
                intraday: true,
                signals: 1,
                openPositions: 1,
                tradesToday: 1,
                pnlToday: 12.4,
                pnlTotal: 100.0,
                pnl: 100.0,
                winRatePct: 55.0,
                pnlHistory: [100, 101, 102]
            ),
        ])
        rest.strategyDetailsResult = .success([
            "surge": StrategyDetail(
                name: "surge",
                state: "active",
                universe: ["AAPL", "MSFT"],
                intraday: true,
                dynamicUniverse: true,
                signalCount: 2,
                openPositions: 1,
                dailyPnl: 12.4
            ),
        ])
        artifacts.indexResult = .success([
            RunArtifactSummary(
                id: "run-1",
                runType: .backtest,
                strategyName: "surge",
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                directory: URL(fileURLWithPath: "/tmp/run-1"),
                sharpe: 1.3,
                maxDrawdown: -0.08,
                walkForwardRatio: nil,
                monteCarloPValue: nil,
                slippageSensitivity: nil,
                verdict: .go
            ),
        ])

        let app = AppViewModel(
            webSocketService: webSocket,
            restClient: rest,
            cliService: cli,
            artifactStore: artifacts,
            settingsStore: settingsStore
        )

        await app.refreshAll()

        #expect(app.statusResponse?.engineState == "ACTIVE")
        #expect(app.positions.count == 1)
        #expect(app.trades.count == 1)
        #expect(app.riskMetrics?.vix == 18.4)
        #expect(app.pdtStatus?.count == 1)
        #expect(app.strategies.count == 1)
        #expect(app.strategyDetail["surge"]?.state == "active")
        #expect(app.universe?.strategies["surge"] != nil)
        #expect(app.artifactRuns.count == 1)
        #expect(app.infoBanner.isEmpty)
    }

    @Test
    func refreshAllAggregatesServiceErrorsIntoBanner() async throws {
        let webSocket = MockWebSocketService()
        let rest = MockRESTClient()
        let cli = MockCLIService()
        let artifacts = MockArtifactStore()
        let settingsStore = makeSettingsStore()

        rest.statusResult = .failure(MockServiceError.forced("status unavailable"))
        rest.riskResult = .failure(URLError(.timedOut))

        let app = AppViewModel(
            webSocketService: webSocket,
            restClient: rest,
            cliService: cli,
            artifactStore: artifacts,
            settingsStore: settingsStore
        )

        await app.refreshAll()

        #expect(app.infoBanner.contains("status"))
        #expect(app.infoBanner.contains("risk"))
        #expect(app.statusResponse == nil)
    }

    @Test
    func runValidateStreamsCommandOutputAndExitCode() async throws {
        let webSocket = MockWebSocketService()
        let rest = MockRESTClient()
        let cli = MockCLIService()
        let artifacts = MockArtifactStore()
        let settingsStore = makeSettingsStore()

        cli.events = [
            .stdout("line one\n"),
            .stderr("warning line\n"),
            .didExit(0),
        ]

        let app = AppViewModel(
            webSocketService: webSocket,
            restClient: rest,
            cliService: cli,
            artifactStore: artifacts,
            settingsStore: settingsStore
        )

        app.runValidate(ValidateLaunchInput())
        try await Task.sleep(nanoseconds: 250_000_000)

        #expect(cli.runRequests.count == 1)
        #expect(cli.runRequests.first?.arguments == ["validate"])
        #expect(app.commandLog?.lines.contains(where: { $0.contains("line one") }) == true)
        #expect(app.commandLog?.lines.contains(where: { $0.contains("[stderr] warning line") }) == true)
        #expect(app.commandLog?.exitCode == 0)
        #expect(app.commandLog?.running == false)
    }

    private func makeSettingsStore() -> SettingsStore {
        let suite = "satori.tests.appvm.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SettingsStore(defaults: defaults)
    }
}
