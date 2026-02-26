import Combine
import AppKit
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var editable: AppSettings
    @Published var portText: String
    @Published private(set) var validation: SettingsValidation
    @Published private(set) var connectionState: SettingsConnectionTestState = .idle
    private let app: AppViewModel
    private var cancellables = Set<AnyCancellable>()

    init(app: AppViewModel) {
        self.app = app
        self.editable = app.settings
        self.portText = String(app.settings.port)
        self.validation = app.settings.validation(portText: String(app.settings.port))
        observeInputs()
    }

    func reloadFromApp() {
        editable = app.settings
        portText = String(app.settings.port)
        validation = editable.validation(portText: portText)
        connectionState = .idle
    }

    func save() {
        guard validation.canSave else {
            connectionState = .failure("Fix validation errors before saving.")
            return
        }

        var updated = editable
        if let parsedPort = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)) {
            updated.port = parsedPort
            editable.port = parsedPort
        }
        app.saveSettings(updated)
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

    func testConnection() {
        guard validation.canSave else {
            connectionState = .failure("Fix host/port/URL validation before testing.")
            return
        }

        var candidate = editable
        if let parsedPort = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)) {
            candidate.port = parsedPort
            editable.port = parsedPort
        }

        connectionState = .testing
        Task {
            connectionState = await app.testConnection(candidate)
        }
    }

    var canSave: Bool {
        validation.canSave
    }

    private func observeInputs() {
        $editable
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                validation = editable.validation(portText: portText)
            }
            .store(in: &cancellables)

        $portText
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                if let parsedPort = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)),
                   editable.port != parsedPort {
                    editable.port = parsedPort
                }
                validation = editable.validation(portText: portText)
            }
            .store(in: &cancellables)
    }
}
