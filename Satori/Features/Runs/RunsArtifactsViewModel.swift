import Combine
import Foundation

@MainActor
final class RunsArtifactsViewModel: ObservableObject {
    private let app: AppViewModel
    var filter = ArtifactFilter()

    init(app: AppViewModel) {
        self.app = app
    }

    var runs: [RunArtifactSummary] {
        app.artifactRuns.filter { run in
            let strategyMatch = filter.strategy.isEmpty || run.strategyName.localizedCaseInsensitiveContains(filter.strategy)
            let typeMatch = filter.runType == nil || run.runType == filter.runType
            return strategyMatch && typeMatch
        }
    }

    func refresh() {
        app.refreshArtifacts()
    }
}
