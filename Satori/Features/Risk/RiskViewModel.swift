import Combine
import Foundation

@MainActor
final class RiskViewModel: ObservableObject {
    private let app: AppViewModel

    init(app: AppViewModel) {
        self.app = app
    }

    var riskMetrics: RiskMetrics? {
        app.riskMetrics
    }

    var pdtStatus: PdtStatus? {
        app.pdtStatus
    }

    func riskColor(value: Double, warningAt: Double, dangerAt: Double) -> String {
        if abs(value) >= dangerAt {
            return "Red"
        }
        if abs(value) >= warningAt {
            return "Yellow"
        }
        return "Green"
    }
}
