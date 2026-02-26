import Combine
import Foundation

protocol WebSocketServiceProtocol: AnyObject {
    var statusPublisher: AnyPublisher<WebSocketConnectionStatus, Never> { get }
    var snapshotPublisher: AnyPublisher<DashboardSnapshot, Never> { get }
    var correlationAlertPublisher: AnyPublisher<CorrelationAlertMessage, Never> { get }
    var lastMessageAtPublisher: AnyPublisher<Date?, Never> { get }
    var latencyPublisher: AnyPublisher<Double, Never> { get }

    func configure(baseReconnectSeconds: Double, maxReconnectSeconds: Double)
    func connect(url: URL)
    func disconnect()
}

protocol RESTClientProtocol {
    func fetchStatus(baseURL: URL) async throws -> StatusResponse
    func fetchPositions(baseURL: URL) async throws -> [PositionRecord]
    func fetchTrades(baseURL: URL, limit: Int?, symbol: String?, strategy: String?, date: String?) async throws -> [TradeRecord]
    func fetchRisk(baseURL: URL) async throws -> RiskMetrics
    func fetchPdt(baseURL: URL) async throws -> PdtStatus
    func fetchStrategies(baseURL: URL) async throws -> [StrategySummary]
    func fetchStrategiesDetail(baseURL: URL) async throws -> [String: StrategyDetail]
    func fetchUniverse(baseURL: URL) async throws -> UniverseSnapshot
}

protocol CLIServiceProtocol {
    func run(_ request: CLIRequest) -> AsyncThrowingStream<CLIOutputEvent, Error>
    func launchMonitor(_ request: MonitorLaunchRequest) throws
}

protocol ArtifactStoreProtocol {
    func indexRuns(root: URL) async throws -> [RunArtifactSummary]
    func listRuns(filter: ArtifactFilter) async -> [RunArtifactSummary]
    func loadArtifact(run: RunArtifactSummary, fileKind: ArtifactFileKind) async throws -> ArtifactContent
    func diffMetrics(run: RunArtifactSummary, baseline: RunArtifactSummary) async throws -> [MetricDiff]
}
