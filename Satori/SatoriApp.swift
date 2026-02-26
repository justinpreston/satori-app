import SwiftUI

@main
struct SatoriApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1380, height: 900)
        .windowResizability(.automatic)

        Settings {
            AppPreferencesView()
                .frame(minWidth: 460, minHeight: 300)
        }
    }
}

private struct AppPreferencesView: View {
    @AppStorage("runs.inspectorVisibleByDefault") private var inspectorVisibleByDefault = true
    @AppStorage("app.showToolbarMetrics") private var showToolbarMetrics = true

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show Runs inspector by default", isOn: $inspectorVisibleByDefault)
                Toggle("Show toolbar connectivity metrics", isOn: $showToolbarMetrics)
            }

            Section("Appearance") {
                Text("Satori follows system Light/Dark appearance and accent color.")
                    .foregroundStyle(.secondary)
            }

            Section("Runtime Configuration") {
                Text("Engine endpoints and run paths are configured in the Runtime sidebar section.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
