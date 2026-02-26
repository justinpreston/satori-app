import Foundation
import Testing
@testable import Satori

@MainActor
struct HomeViewModelTests {
    @Test
    func engineStateFallsBackFromSnapshotToStatus() {
        let app = makeApp()
        let viewModel = HomeViewModel(app: app)

        #expect(viewModel.engineState == "INIT")

        app.statusResponse = StatusResponse.fixture(engineState: "WARMUP")
        #expect(viewModel.engineState == "WARMUP")

        app.dashboardSnapshot = DashboardSnapshot(
            timestamp: nil,
            portfolio: nil,
            strategies: nil,
            recentTrades: nil,
            riskMetrics: nil,
            performance: nil,
            engineState: "ACTIVE",
            alerts: nil,
            execution: nil,
            infrastructure: nil
        )
        #expect(viewModel.engineState == "ACTIVE")
    }

    @Test
    func derivedMetricStringsUseExpectedFormatting() {
        let app = makeApp()
        let viewModel = HomeViewModel(app: app)

        app.riskMetrics = RiskMetrics.fixture(dailyPnlPct: -1.256, drawdownPct: 2.349)
        app.positions = [
            PositionRecord(symbol: "MSFT", qty: 4, avgPrice: 400, marketValue: 1_600, unrealizedPnL: 10),
            PositionRecord(symbol: "NVDA", qty: 2, avgPrice: 800, marketValue: 1_620, unrealizedPnL: 20),
        ]
        app.pdtStatus = PdtStatus.fixture(count: 2, limit: 4, remaining: 2)
        app.dashboardSnapshot = DashboardSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            portfolio: nil,
            strategies: nil,
            recentTrades: nil,
            riskMetrics: nil,
            performance: nil,
            engineState: "ACTIVE",
            alerts: [
                AlertRecord(id: "a1", timestamp: nil, severity: "warning", message: "Warn 1", source: "risk", dismissed: false),
                AlertRecord(id: "a2", timestamp: nil, severity: "warning", message: "Warn 2", source: "risk", dismissed: false),
                AlertRecord(id: "a3", timestamp: nil, severity: "info", message: "Info", source: "risk", dismissed: false),
            ],
            execution: nil,
            infrastructure: nil
        )

        #expect(viewModel.dailyPnlPctText == "-1.26%")
        #expect(viewModel.drawdownPctText == "2.35%")
        #expect(viewModel.openPositionsCount == 2)
        #expect(viewModel.pdtText == "2/4 (2 remaining)")
        #expect(viewModel.vetoCountProxy == 2)
        #expect(viewModel.lastBarText != "N/A")
    }

    private func makeApp() -> AppViewModel {
        AppViewModel(
            webSocketService: MockWebSocketService(),
            restClient: MockRESTClient(),
            cliService: MockCLIService(),
            artifactStore: MockArtifactStore(),
            settingsStore: SettingsStore(defaults: UserDefaults(suiteName: "satori.tests.homevm.\(UUID().uuidString)")!)
        )
    }
}
