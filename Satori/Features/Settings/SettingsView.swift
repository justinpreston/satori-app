import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: AppViewModel
    @StateObject private var viewModel: SettingsViewModel

    init(app: AppViewModel) {
        self.app = app
        _viewModel = StateObject(wrappedValue: SettingsViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                engineCard
                pathsCard
                reconnectCard
                aboutCard

                HStack {
                    Button("Reload") {
                        viewModel.reloadFromApp()
                    }
                    .buttonStyle(InazumaActionButtonStyle())

                    Button("Save") {
                        viewModel.save()
                    }
                    .buttonStyle(InazumaActionButtonStyle())
                    .keyboardShortcut(.defaultAction)

                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
    }

    private var engineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            InazumaSectionHeader("Engine Connection")

            HStack {
                Picker("API Scheme", selection: $viewModel.editable.apiScheme) {
                    ForEach(APIScheme.allCases) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }

                Picker("WebSocket Scheme", selection: $viewModel.editable.wsScheme) {
                    ForEach(WebSocketScheme.allCases) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
            }

            TextField("Host", text: $viewModel.editable.host)
                .inazumaInputField()
            Stepper(value: $viewModel.editable.port, in: 1...65535) {
                Text("Port: \(viewModel.editable.port.formatted(.number.grouping(.never)))")
                    .font(.callout.weight(.semibold))
            }

            TextField("API Base Path (optional)", text: $viewModel.editable.apiBasePath)
                .inazumaInputField()
            TextField("WebSocket Path", text: $viewModel.editable.wsPath)
                .inazumaInputField()

            Divider().overlay(InazumaPalette.cyanBorder.opacity(0.4))

            resolvedURLRow("Resolved API URL", value: viewModel.editable.baseAPIURL?.absoluteString)
            resolvedURLRow("Resolved WS URL", value: viewModel.editable.wsURL?.absoluteString)

            Text("Use a remote host or domain here. For internet endpoints prefer https + wss.")
                .font(InazumaTypography.caption)
                .foregroundStyle(InazumaPalette.textMuted)
        }
        .inazumaCard()
    }

    private var pathsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            InazumaSectionHeader("Paths")

            pathRow(title: "CLI path", value: $viewModel.editable.cliPath, browseAction: nil)
            pathRow(title: "Engine root", value: $viewModel.editable.engineRootPath) {
                viewModel.pickDirectory(for: \.engineRootPath)
            }
            pathRow(title: "Runs root", value: $viewModel.editable.runsRootPath) {
                viewModel.pickDirectory(for: \.runsRootPath)
            }
        }
        .inazumaCard()
    }

    private var reconnectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            InazumaSectionHeader("Reconnect")

            HStack {
                Text("Base seconds")
                    .foregroundStyle(InazumaPalette.textSecondary)
                Spacer()
                TextField("", value: $viewModel.editable.reconnectBaseSeconds, format: .number)
                    .frame(width: 100)
                    .inazumaInputField()
            }
            .font(.callout)

            HStack {
                Text("Max seconds")
                    .foregroundStyle(InazumaPalette.textSecondary)
                Spacer()
                TextField("", value: $viewModel.editable.reconnectMaxSeconds, format: .number)
                    .frame(width: 100)
                    .inazumaInputField()
            }
            .font(.callout)

            Text("App-level scoped directories enabled. macOS App Sandbox entitlements are deferred.")
                .font(InazumaTypography.caption)
                .foregroundStyle(InazumaPalette.textMuted)
        }
        .inazumaCard()
    }

    private var aboutCard: some View {
        HStack {
            Text("Satori client")
            Divider().frame(height: 14)
            Text("Build Feb 2026")
            Divider().frame(height: 14)
            Text("Target macOS 14+")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(InazumaPalette.textMuted)
        .padding(12)
        .inazumaCard(borderColor: InazumaPalette.cyanBorder.opacity(0.6))
    }

    private func resolvedURLRow(_ title: String, value: String?) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(InazumaPalette.textSecondary)
                .frame(width: 130, alignment: .leading)

            Text(value ?? "Invalid settings")
                .font(.caption)
                .foregroundStyle(value == nil ? InazumaPalette.red : InazumaPalette.textPrimary)
                .textSelection(.enabled)
                .lineLimit(1)

            Spacer()

            if let value {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func pathRow(title: String, value: Binding<String>, browseAction: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(InazumaPalette.textSecondary)
                .frame(width: 90, alignment: .leading)

            TextField(title, text: value)
                .inazumaInputField()

            Text(value.wrappedValue.truncMiddle(maxLength: 54))
                .font(.caption2)
                .foregroundStyle(InazumaPalette.textMuted)
                .lineLimit(1)
                .help(value.wrappedValue)

            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value.wrappedValue, forType: .string)
            }
            .buttonStyle(.bordered)

            if let browseAction {
                Button("Browse") {
                    browseAction()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private extension String {
    func truncMiddle(maxLength: Int) -> String {
        guard count > maxLength else { return self }
        let prefixCount = maxLength / 2 - 2
        let suffixCount = maxLength / 2 - 1
        return "\(prefix(prefixCount))...\(suffix(suffixCount))"
    }
}
