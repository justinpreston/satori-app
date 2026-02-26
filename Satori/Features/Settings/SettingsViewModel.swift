import Combine
import AppKit
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var editable: AppSettings
    private let app: AppViewModel

    init(app: AppViewModel) {
        self.app = app
        self.editable = app.settings
    }

    func reloadFromApp() {
        editable = app.settings
    }

    func save() {
        app.saveSettings(editable)
    }

    func pickDirectory(for keyPath: WritableKeyPath<AppSettings, String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            editable[keyPath: keyPath] = url.path
        }
    }
}
