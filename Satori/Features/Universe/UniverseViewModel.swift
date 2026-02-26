import Combine
import Foundation

@MainActor
final class UniverseViewModel: ObservableObject {
    private let app: AppViewModel

    init(app: AppViewModel) {
        self.app = app
    }

    var universe: UniverseSnapshot? {
        app.universe
    }
}
