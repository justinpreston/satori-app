import Combine
import Foundation

@MainActor
final class StrategiesViewModel: ObservableObject {
    private let app: AppViewModel

    init(app: AppViewModel) {
        self.app = app
    }

    var strategies: [StrategySummary] {
        app.strategies
    }

    func detail(for strategy: StrategySummary) -> StrategyDetail? {
        app.strategyDetail[strategy.name]
    }
}
