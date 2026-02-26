import SwiftUI

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings
    @StateObject private var app = AppViewModel()
    @State private var selection: AppSection? = .home
    @AppStorage("app.showToolbarMetrics") private var showToolbarMetrics = true

    var body: some View {
        ZStack {
            InazumaWindowBackdrop()

            NavigationSplitView {
                VStack(spacing: 0) {
                    List(AppSection.allCases, selection: $selection) { section in
                        HStack(spacing: 10) {
                            Image(systemName: section.systemImage)
                                .font(.body.weight(.medium))
                                .foregroundStyle(selection == section ? InazumaPalette.cyan : InazumaPalette.textSecondary)
                                .frame(width: 18)
                            Text(section.rawValue)
                                .font(.body.weight(.medium))
                                .foregroundStyle(selection == section ? InazumaPalette.textPrimary : InazumaPalette.textSecondary)
                            Spacer()
                            if let badge = navBadge(for: section) {
                                Text(badge)
                                    .font(InazumaTypography.metric(size: 10, weight: .bold))
                                    .foregroundStyle(InazumaPalette.cyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(InazumaPalette.cyan.opacity(0.14))
                                    .overlay {
                                        Capsule().stroke(InazumaPalette.cyanBorder.opacity(0.75), lineWidth: 1)
                                    }
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowSeparator(.hidden)
                        .listRowBackground(selection == section ? InazumaPalette.cyan.opacity(0.14) : Color.clear)
                        .tag(section)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)

                    Divider().overlay(InazumaPalette.cyanBorder.opacity(0.35))
                    HStack {
                        Text("Equity")
                        Spacer()
                        Text(equityText)
                    }
                    .font(.caption)
                    .foregroundStyle(InazumaPalette.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                    HStack {
                        Text("Mode")
                        Spacer()
                        Text("Paper")
                    }
                    .font(.caption)
                    .foregroundStyle(InazumaPalette.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .background(InazumaPalette.bgSidebar)
                .navigationTitle("Satori")
                .frame(minWidth: 220)
            } detail: {
                ZStack {
                    InazumaPalette.bgPrimary
                        .ignoresSafeArea()

                    Group {
                        switch selection ?? .home {
                        case .home:
                            HomeView(app: app)
                        case .strategies:
                            StrategiesView(app: app)
                        case .runs:
                            RunsArtifactsView(app: app)
                        case .risk:
                            RiskView(app: app)
                        case .universe:
                            UniverseView(app: app)
                        case .settings:
                            SettingsView(app: app)
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Button("Refresh") {
                            Task { await app.refreshAll() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(InazumaPalette.cyan)

                        if !app.infoBanner.isEmpty {
                            Text(app.infoBanner)
                                .font(InazumaTypography.caption)
                                .foregroundStyle(InazumaPalette.textSecondary)
                                .lineLimit(1)
                                .help(app.infoBanner)
                        }

                        Spacer()

                        if showToolbarMetrics {
                            HStack(spacing: 10) {
                                InazumaStatusDot(color: wsStatusColor)
                                Text("WS: \(app.wsStatus.rawValue)  \(String(format: "%.1f", app.latencyMs))ms")
                                    .font(InazumaTypography.metric(size: 12, weight: .medium))
                                    .foregroundStyle(InazumaPalette.textSecondary)

                                Divider().frame(height: 14)

                                Text("Engine: \(engineState)")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(InazumaPalette.textSecondary)
                            }
                        }

                        Button {
                            openSettings()
                        } label: {
                            Label("Preferences", systemImage: "gearshape")
                        }
                        .help("Open app preferences")
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
            .tint(InazumaPalette.cyan)
        }
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarBackground(InazumaPalette.bgElevated, for: .windowToolbar)
        .task {
            app.start()
        }
        .onDisappear {
            app.stop()
        }
        .sheet(item: $app.commandLog) { log in
            NavigationStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(log.title)
                        .font(.headline)
                        .foregroundStyle(InazumaPalette.textPrimary)
                    ScrollView {
                        Text(log.lines.joined(separator: "\n"))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(InazumaPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Text(log.running ? "Running..." : "Finished")
                            .foregroundStyle(InazumaPalette.textSecondary)
                        if let code = log.exitCode {
                            Text("exit \(code)")
                                .foregroundStyle(code == 0 ? InazumaPalette.green : InazumaPalette.red)
                        }
                        Spacer()
                        Button("Close") {
                            app.dismissCommandLog()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(InazumaPalette.cyan)
                    }
                }
                .padding()
                .frame(minWidth: 720, minHeight: 420)
                .background(InazumaPalette.bgPrimary)
            }
        }
        .alert("Error", isPresented: Binding(get: {
            app.presentedErrorMessage != nil
        }, set: { newValue in
            if !newValue {
                app.dismissError()
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.presentedErrorMessage ?? "Unknown error")
        }
    }

    private var equityText: String {
        guard let equity = app.dashboardSnapshot?.portfolio?.equity else { return "N/A" }
        return "$\(String(format: "%.0f", equity))"
    }

    private func navBadge(for section: AppSection) -> String? {
        switch section {
        case .strategies:
            return app.strategies.isEmpty ? nil : "\(app.strategies.count)"
        case .runs:
            return app.artifactRuns.isEmpty ? nil : "\(app.artifactRuns.count)"
        case .risk:
            return app.correlationAlerts.isEmpty ? nil : "\(app.correlationAlerts.count)"
        default:
            return nil
        }
    }

    private var engineState: String {
        app.dashboardSnapshot?.engineState ?? app.statusResponse?.engineState ?? "INIT"
    }

    private var wsStatusColor: Color {
        switch app.wsStatus {
        case .connected:
            if app.latencyMs < 10 { return InazumaPalette.green }
            if app.latencyMs < 100 { return InazumaPalette.amber }
            return InazumaPalette.red
        case .connecting, .reconnecting:
            return InazumaPalette.amber
        case .disconnected:
            return InazumaPalette.red
        }
    }
}
