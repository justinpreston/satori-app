import Foundation

enum StrategyState: Equatable {
    case active
    case live
    case paper
    case shadow
    case warmup
    case cooling
    case paused
    case stopped
    case unknown(String)

    init(rawValue: String?) {
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch trimmed.lowercased() {
        case "active":
            self = .active
        case "live":
            self = .live
        case "paper":
            self = .paper
        case "shadow":
            self = .shadow
        case "warmup":
            self = .warmup
        case "cooling":
            self = .cooling
        case "paused":
            self = .paused
        case "stopped":
            self = .stopped
        default:
            self = .unknown(trimmed.isEmpty ? "UNKNOWN" : trimmed)
        }
    }

    var label: String {
        switch self {
        case .active:
            return "ACTIVE"
        case .live:
            return "LIVE"
        case .paper:
            return "PAPER"
        case .shadow:
            return "SHADOW"
        case .warmup:
            return "WARMUP"
        case .cooling:
            return "COOLING"
        case .paused:
            return "PAUSED"
        case .stopped:
            return "STOPPED"
        case .unknown:
            return "UNKNOWN"
        }
    }
}

enum EngineSeverity: Equatable {
    case safe
    case warning
    case critical
    case unknown

    init(engineState: String?) {
        switch StrategyState(rawValue: engineState) {
        case .active, .live:
            self = .safe
        case .warmup, .cooling, .paper, .shadow:
            self = .warning
        case .paused, .stopped:
            self = .critical
        case .unknown:
            self = .unknown
        }
    }
}

enum AlertSeverity: Equatable {
    case info
    case warning
    case critical
    case unknown

    init(rawValue: String?) {
        let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch normalized {
        case "info", "notice":
            self = .info
        case "warning", "warn":
            self = .warning
        case "critical", "error":
            self = .critical
        default:
            self = .unknown
        }
    }
}

enum ValidationState: Equatable {
    case valid
    case invalid(String)

    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }

    var message: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}

enum SettingsConnectionTestState: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
}

struct SettingsValidation: Equatable {
    let host: ValidationState
    let port: ValidationState
    let apiURL: ValidationState
    let wsURL: ValidationState
    let engineRootPath: ValidationState
    let runsRootPath: ValidationState

    var canSave: Bool {
        host.isValid && port.isValid && apiURL.isValid && wsURL.isValid
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case strategies = "Strategies"
    case runs = "Runs & Artifacts"
    case risk = "Risk"
    case universe = "Universe"
    case settings = "Runtime"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home:
            "speedometer"
        case .strategies:
            "list.bullet.rectangle"
        case .runs:
            "shippingbox"
        case .risk:
            "shield.lefthalf.filled"
        case .universe:
            "globe.americas"
        case .settings:
            "server.rack"
        }
    }
}

enum WebSocketConnectionStatus: String {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

enum APIScheme: String, Codable, CaseIterable, Identifiable {
    case http
    case https

    var id: String { rawValue }
}

enum WebSocketScheme: String, Codable, CaseIterable, Identifiable {
    case ws
    case wss

    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var apiScheme: APIScheme
    var wsScheme: WebSocketScheme
    var host: String
    var port: Int
    var apiBasePath: String
    var wsPath: String
    var cliPath: String
    var engineRootPath: String
    var runsRootPath: String
    var reconnectBaseSeconds: Double
    var reconnectMaxSeconds: Double

    static let `default`: AppSettings = {
        let resolvedPaths = resolveDefaultPaths()
        return AppSettings(
            apiScheme: .http,
            wsScheme: .ws,
            host: "localhost",
            port: 8780,
            apiBasePath: "",
            wsPath: "/ws",
            cliPath: resolvedPaths.cliPath,
            engineRootPath: resolvedPaths.engineRootPath,
            runsRootPath: resolvedPaths.runsRootPath,
            reconnectBaseSeconds: 1,
            reconnectMaxSeconds: 8
        )
    }()

    var wsURL: URL? {
        buildURL(scheme: wsScheme.rawValue, path: normalizedPath(wsPath, defaultPath: "/ws"))
    }

    var baseAPIURL: URL? {
        buildURL(scheme: apiScheme.rawValue, path: normalizedPath(apiBasePath, defaultPath: ""))
    }

    func validation(portText: String? = nil) -> SettingsValidation {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let hostState: ValidationState = parsedHostPort == nil && trimmedHost.isEmpty
            ? .invalid("Host is required")
            : parsedHostPort == nil && !trimmedHost.contains(".") && trimmedHost != "localhost"
                ? .invalid("Host is malformed")
                : parsedHostPort == nil && trimmedHost.contains(" ")
                    ? .invalid("Host is malformed")
                    : .valid

        let resolvedPortText = (portText ?? String(port)).trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedPort = Int(resolvedPortText)
        let portState: ValidationState
        if let parsedPort, (1...65535).contains(parsedPort) {
            portState = .valid
        } else {
            portState = .invalid("Port must be 1-65535")
        }

        let candidatePort = parsedPort ?? port
        let apiURLState: ValidationState = buildURL(
            scheme: apiScheme.rawValue,
            path: normalizedPath(apiBasePath, defaultPath: ""),
            overridePort: candidatePort
        ) == nil ? .invalid("API URL is invalid") : .valid
        let wsURLState: ValidationState = buildURL(
            scheme: wsScheme.rawValue,
            path: normalizedPath(wsPath, defaultPath: "/ws"),
            overridePort: candidatePort
        ) == nil ? .invalid("WebSocket URL is invalid") : .valid

        let fileManager = FileManager.default
        let engineState: ValidationState = fileManager.fileExists(atPath: engineRootPath)
            ? .valid
            : .invalid("Engine path not found")
        let runsState: ValidationState = fileManager.fileExists(atPath: runsRootPath)
            ? .valid
            : .invalid("Runs path not found")

        return SettingsValidation(
            host: hostState,
            port: portState,
            apiURL: apiURLState,
            wsURL: wsURLState,
            engineRootPath: engineState,
            runsRootPath: runsState
        )
    }

    private enum CodingKeys: String, CodingKey {
        case apiScheme
        case wsScheme
        case host
        case port
        case apiBasePath
        case wsPath
        case cliPath
        case engineRootPath
        case runsRootPath
        case reconnectBaseSeconds
        case reconnectMaxSeconds
    }

    init(
        apiScheme: APIScheme,
        wsScheme: WebSocketScheme,
        host: String,
        port: Int,
        apiBasePath: String,
        wsPath: String,
        cliPath: String,
        engineRootPath: String,
        runsRootPath: String,
        reconnectBaseSeconds: Double,
        reconnectMaxSeconds: Double
    ) {
        self.apiScheme = apiScheme
        self.wsScheme = wsScheme
        self.host = host
        self.port = port
        self.apiBasePath = apiBasePath
        self.wsPath = wsPath
        self.cliPath = cliPath
        self.engineRootPath = engineRootPath
        self.runsRootPath = runsRootPath
        self.reconnectBaseSeconds = reconnectBaseSeconds
        self.reconnectMaxSeconds = reconnectMaxSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        host = try container.decodeIfPresent(String.self, forKey: .host) ?? defaults.host
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? defaults.port
        apiScheme = try container.decodeIfPresent(APIScheme.self, forKey: .apiScheme) ?? defaults.apiScheme
        wsScheme = try container.decodeIfPresent(WebSocketScheme.self, forKey: .wsScheme) ?? defaults.wsScheme
        apiBasePath = try container.decodeIfPresent(String.self, forKey: .apiBasePath) ?? defaults.apiBasePath
        wsPath = try container.decodeIfPresent(String.self, forKey: .wsPath) ?? defaults.wsPath
        cliPath = try container.decodeIfPresent(String.self, forKey: .cliPath) ?? defaults.cliPath
        engineRootPath = try container.decodeIfPresent(String.self, forKey: .engineRootPath) ?? defaults.engineRootPath
        runsRootPath = try container.decodeIfPresent(String.self, forKey: .runsRootPath) ?? defaults.runsRootPath
        reconnectBaseSeconds = try container.decodeIfPresent(Double.self, forKey: .reconnectBaseSeconds) ?? defaults.reconnectBaseSeconds
        reconnectMaxSeconds = try container.decodeIfPresent(Double.self, forKey: .reconnectMaxSeconds) ?? defaults.reconnectMaxSeconds
    }

    private func normalizedPath(_ value: String, defaultPath: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultPath }
        return trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
    }

    private var parsedHostPort: (host: String, port: Int?)? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "//\(trimmed)"
        guard let components = URLComponents(string: candidate), let parsedHost = components.host else {
            return nil
        }
        return (parsedHost, components.port)
    }

    private func buildURL(scheme: String, path: String, overridePort: Int? = nil) -> URL? {
        let parsed = parsedHostPort
        let resolvedHost = parsed?.host ?? host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedHost.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = resolvedHost
        components.port = parsed?.port ?? overridePort ?? port
        components.path = path
        return components.url
    }

    private static func resolveDefaultPaths(fileManager: FileManager = .default) -> (cliPath: String, engineRootPath: String, runsRootPath: String) {
        let home = fileManager.homeDirectoryForCurrentUser
        let candidateRoots = [
            home.appendingPathComponent("Documents/GitHub/satori"),
            home.appendingPathComponent("github/satori"),
            home.appendingPathComponent(".local/share/satori"),
        ]

        let engineRoot = candidateRoots.first(where: { fileManager.fileExists(atPath: $0.path) }) ?? candidateRoots[0]
        let runsRoot = engineRoot.appendingPathComponent("runs")

        let candidateCLIs = [
            engineRoot.appendingPathComponent(".venv/bin/satori"),
            home.appendingPathComponent(".local/bin/satori"),
        ]
        let cliPath = candidateCLIs.first(where: { fileManager.fileExists(atPath: $0.path) }) ?? candidateCLIs[0]

        return (cliPath.path, engineRoot.path, runsRoot.path)
    }
}

struct CommandLogState: Identifiable {
    let id = UUID()
    let title: String
    var lines: [String]
    var running: Bool
    var exitCode: Int32?
}

enum RunType: String, CaseIterable {
    case backtest
    case validate
    case shadow
}

enum RunVerdict: String {
    case go = "GO"
    case noGo = "NO_GO"
    case unknown = "UNKNOWN"
}

struct RunArtifactSummary: Identifiable, Hashable {
    let id: String
    let runType: RunType
    let strategyName: String
    let timestamp: Date
    let directory: URL
    let sharpe: Double?
    let maxDrawdown: Double?
    let walkForwardRatio: Double?
    let monteCarloPValue: Double?
    let slippageSensitivity: Double?
    let verdict: RunVerdict

    var runTypeLabel: String { runType.rawValue.capitalized }
    var verdictLabel: String { verdict.rawValue }
    var sharpeSortValue: Double { sharpe ?? -.infinity }
    var maxDrawdownSortValue: Double { maxDrawdown ?? -.infinity }
}

enum ArtifactFileKind: String, CaseIterable {
    case metricsJSON = "metrics.json"
    case tradesCSV = "trades.csv"
    case equityPNG = "equity.png"
    case runMetadataJSON = "run_metadata.json"
    case vetoSummaryJSON = "veto_summary.json"
}

enum ArtifactContent {
    case json(String)
    case csv([String])
    case image(URL)
    case text(String)
}

struct ArtifactFilter {
    var strategy: String = ""
    var runType: RunType?
}

struct MetricDiff: Identifiable {
    var id: String { metric }
    let metric: String
    let baselineValue: Double
    let candidateValue: Double
    let delta: Double
}
