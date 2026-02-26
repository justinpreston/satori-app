import Combine
import Foundation
@testable import Satori

enum MockServiceError: Error {
    case forced(String)
}

final class MockWebSocketService: WebSocketServiceProtocol {
    let statusSubject = CurrentValueSubject<WebSocketConnectionStatus, Never>(.disconnected)
    let snapshotSubject = PassthroughSubject<DashboardSnapshot, Never>()
    let correlationAlertSubject = PassthroughSubject<CorrelationAlertMessage, Never>()
    let lastMessageAtSubject = CurrentValueSubject<Date?, Never>(nil)
    let latencySubject = CurrentValueSubject<Double, Never>(0)
    let decodeErrorSubject = PassthroughSubject<Error, Never>()

    private(set) var configuredValues: [(base: Double, max: Double)] = []
    private(set) var connectedURLs: [URL] = []
    private(set) var disconnectCallCount = 0

    var statusPublisher: AnyPublisher<WebSocketConnectionStatus, Never> { statusSubject.eraseToAnyPublisher() }
    var snapshotPublisher: AnyPublisher<DashboardSnapshot, Never> { snapshotSubject.eraseToAnyPublisher() }
    var correlationAlertPublisher: AnyPublisher<CorrelationAlertMessage, Never> { correlationAlertSubject.eraseToAnyPublisher() }
    var lastMessageAtPublisher: AnyPublisher<Date?, Never> { lastMessageAtSubject.eraseToAnyPublisher() }
    var latencyPublisher: AnyPublisher<Double, Never> { latencySubject.eraseToAnyPublisher() }
    var decodeErrorPublisher: AnyPublisher<Error, Never> { decodeErrorSubject.eraseToAnyPublisher() }

    func configure(baseReconnectSeconds: Double, maxReconnectSeconds: Double) {
        configuredValues.append((baseReconnectSeconds, maxReconnectSeconds))
    }

    func connect(url: URL) {
        connectedURLs.append(url)
        statusSubject.send(.connected)
    }

    func disconnect() {
        disconnectCallCount += 1
        statusSubject.send(.disconnected)
    }
}

final class MockRESTClient: RESTClientProtocol {
    var statusResult: Result<StatusResponse, Error> = .success(.fixture())
    var positionsResult: Result<[PositionRecord], Error> = .success([])
    var tradesResult: Result<[TradeRecord], Error> = .success([])
    var riskResult: Result<RiskMetrics, Error> = .success(.fixture())
    var pdtResult: Result<PdtStatus, Error> = .success(.fixture())
    var strategiesResult: Result<[StrategySummary], Error> = .success([])
    var strategyDetailsResult: Result<[String: StrategyDetail], Error> = .success([:])
    var universeResult: Result<UniverseSnapshot, Error> = .success(.fixture())

    private(set) var statusCallCount = 0
    private(set) var tradesCallCount = 0

    func fetchStatus(baseURL _: URL) async throws -> StatusResponse {
        statusCallCount += 1
        return try statusResult.get()
    }

    func fetchPositions(baseURL _: URL) async throws -> [PositionRecord] {
        try positionsResult.get()
    }

    func fetchTrades(baseURL _: URL, limit _: Int?, symbol _: String?, strategy _: String?, date _: String?) async throws -> [TradeRecord] {
        tradesCallCount += 1
        return try tradesResult.get()
    }

    func fetchRisk(baseURL _: URL) async throws -> RiskMetrics {
        try riskResult.get()
    }

    func fetchPdt(baseURL _: URL) async throws -> PdtStatus {
        try pdtResult.get()
    }

    func fetchStrategies(baseURL _: URL) async throws -> [StrategySummary] {
        try strategiesResult.get()
    }

    func fetchStrategiesDetail(baseURL _: URL) async throws -> [String: StrategyDetail] {
        try strategyDetailsResult.get()
    }

    func fetchUniverse(baseURL _: URL) async throws -> UniverseSnapshot {
        try universeResult.get()
    }
}

final class MockCLIService: CLIServiceProtocol {
    var events: [CLIOutputEvent] = [.didExit(0)]
    var monitorLaunchError: Error?
    private(set) var runRequests: [CLIRequest] = []
    private(set) var launchRequests: [MonitorLaunchRequest] = []

    func run(_ request: CLIRequest) -> AsyncThrowingStream<CLIOutputEvent, Error> {
        runRequests.append(request)
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func launchMonitor(_ request: MonitorLaunchRequest) throws {
        launchRequests.append(request)
        if let monitorLaunchError {
            throw monitorLaunchError
        }
    }
}

final class MockArtifactStore: ArtifactStoreProtocol {
    var indexResult: Result<[RunArtifactSummary], Error> = .success([])
    private(set) var indexedRoots: [URL] = []

    func indexRuns(root: URL) async throws -> [RunArtifactSummary] {
        indexedRoots.append(root)
        return try indexResult.get()
    }

    func listRuns(filter _: ArtifactFilter) async -> [RunArtifactSummary] {
        []
    }

    func loadArtifact(run _: RunArtifactSummary, fileKind _: ArtifactFileKind) async throws -> ArtifactContent {
        .text("")
    }

    func diffMetrics(run _: RunArtifactSummary, baseline _: RunArtifactSummary) async throws -> [MetricDiff] {
        []
    }
}

extension StatusResponse {
    static func fixture(engineState: String = "ACTIVE") -> StatusResponse {
        StatusResponse(engineState: engineState, timestamp: Date(timeIntervalSince1970: 1_700_000_000), numWsClients: 2)
    }
}

extension RiskMetrics {
    static func fixture(dailyPnlPct: Double = 0.5, drawdownPct: Double = 1.2) -> RiskMetrics {
        RiskMetrics(
            drawdownPct: drawdownPct,
            dailyPnlPct: dailyPnlPct,
            killSwitchActive: false,
            vix: 18.4,
            equityPeak: 101_000,
            dailyStartEquity: 100_000,
            pdt: nil
        )
    }
}

extension PdtStatus {
    static func fixture(count: Int = 1, limit: Int = 4, remaining: Int = 3) -> PdtStatus {
        PdtStatus(count: count, limit: limit, remaining: remaining, exempt: false, trades: [])
    }
}

extension UniverseSnapshot {
    static func fixture() -> UniverseSnapshot {
        UniverseSnapshot(strategies: ["surge": UniverseStrategy(tier1: ["AAPL", "NVDA"], tier2: ["AMD"])], lastScan: Date(timeIntervalSince1970: 1_700_000_000))
    }
}
