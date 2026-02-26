import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    private let app: AppViewModel

    init(app: AppViewModel) {
        self.app = app
    }

    var engineState: String {
        app.dashboardSnapshot?.engineState ?? app.statusResponse?.engineState ?? "INIT"
    }

    var wsStatus: WebSocketConnectionStatus {
        app.wsStatus
    }

    var dailyPnlPctText: String {
        guard let value = app.riskMetrics?.dailyPnlPct else { return "N/A" }
        return String(format: "%.2f%%", value)
    }

    var drawdownPctText: String {
        guard let value = app.riskMetrics?.drawdownPct else { return "N/A" }
        return String(format: "%.2f%%", value)
    }

    var openPositionsCount: Int {
        app.positions.count
    }

    var pdtText: String {
        guard let pdt = app.pdtStatus else { return "N/A" }
        return "\(pdt.count)/\(pdt.limit) (\(pdt.remaining) remaining)"
    }

    var vetoCountProxy: Int {
        app.dashboardSnapshot?.alerts?.filter { $0.severity.lowercased() == "warning" }.count ?? 0
    }

    var lastBarText: String {
        guard let ts = app.dashboardSnapshot?.timestamp else { return "N/A" }
        return ts.formatted(date: .abbreviated, time: .standard)
    }
}
