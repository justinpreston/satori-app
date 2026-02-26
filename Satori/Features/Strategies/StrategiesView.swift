import AppKit
import SwiftUI

struct StrategiesView: View {
    @ObservedObject var app: AppViewModel
    @StateObject private var viewModel: StrategiesViewModel
    @State private var selected: StrategySummary?
    @State private var searchText = ""
    @State private var sortOption: StrategySortOption = .name

    init(app: AppViewModel) {
        self.app = app
        _viewModel = StateObject(wrappedValue: StrategiesViewModel(app: app))
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(InazumaPalette.textMuted)
                    TextField("Search strategy", text: $searchText)
                        .inazumaInputField()
                }
                .inazumaCard(borderColor: InazumaPalette.cyanBorder.opacity(0.6))

                Picker("Sort", selection: $sortOption) {
                    ForEach(StrategySortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredStrategies) { strategy in
                            strategyRow(strategy)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .padding(14)
            .frame(minWidth: 320)
            .animation(.easeOut(duration: 0.2), value: selected?.id)

            Group {
                if let selected {
                    detailPane(for: selected)
                } else {
                    ContentUnavailableView(
                        "Select a strategy",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Choose a strategy from the list.")
                    )
                    .foregroundStyle(InazumaPalette.textSecondary)
                }
            }
            .padding(14)
            .frame(minWidth: 520)
        }
    }

    private func strategyRow(_ strategy: StrategySummary) -> some View {
        let isSelected = selected?.id == strategy.id
        let detail = viewModel.detail(for: strategy)

        return Button {
            selected = strategy
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    InazumaStatusDot(color: stateColor(strategy.state), size: 6)
                    Text(strategy.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(InazumaPalette.textPrimary)
                    Spacer()
                    Text(sharpeText(strategy))
                        .font(InazumaTypography.metric(size: 13, weight: .bold))
                        .foregroundStyle(InazumaPalette.cyan)
                }

                HStack(spacing: 8) {
                    InazumaPill(text: (strategy.state ?? "N/A").uppercased(), severity: stateSeverity(strategy.state), monospaced: true)
                    Text("Gates: N/A")
                        .font(InazumaTypography.metric(size: 10, weight: .medium))
                        .foregroundStyle(InazumaPalette.textMuted)
                    Spacer()
                    Text(detail?.state ?? "N/A")
                        .font(InazumaTypography.metric(size: 10, weight: .medium))
                        .foregroundStyle(InazumaPalette.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? InazumaPalette.bgElevated : InazumaPalette.bgCard.opacity(0.9))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? InazumaPalette.cyan : Color.clear)
                    .frame(width: 3)
            }
            .inazumaHoverCard(highlighted: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func detailPane(for strategy: StrategySummary) -> some View {
        let detail = viewModel.detail(for: strategy)
        let runs = strategyRuns(for: strategy)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(strategy.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(InazumaPalette.textPrimary)
                            Text("State: \(strategy.state ?? "N/A")  |  Universe: \((detail?.universe ?? []).count) tickers")
                                .font(InazumaTypography.metric(size: 12, weight: .medium))
                                .foregroundStyle(InazumaPalette.textSecondary)
                        }
                        Spacer()
                        InazumaPill(text: (strategy.state ?? "UNKNOWN").uppercased(), severity: stateSeverity(strategy.state), monospaced: true)
                    }
                }
                .inazumaCard(glow: true)

                InazumaSectionHeader("Gate Status")
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(gateItems(for: strategy), id: \.name) { gate in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(gate.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(InazumaPalette.textSecondary)
                                Text(gate.symbol)
                                    .font(InazumaTypography.metric(size: 20, weight: .bold))
                                    .foregroundStyle(gate.color)
                                Text(gate.detail)
                                    .font(InazumaTypography.metric(size: 10, weight: .medium))
                                    .foregroundStyle(InazumaPalette.textMuted)
                            }
                            .frame(width: 140, alignment: .leading)
                            .inazumaCard(borderColor: gate.color.opacity(0.35))
                        }
                    }
                }

                InazumaSectionHeader("Equity Curve")
                VStack(alignment: .leading, spacing: 8) {
                    if let history = strategy.pnlHistory, history.count > 1 {
                        SparklineView(values: history)
                            .frame(height: 180)
                        Text("7-sample sparkline preview")
                            .font(InazumaTypography.caption)
                            .foregroundStyle(InazumaPalette.textMuted)
                    } else {
                        Text("Run a backtest to generate equity curve")
                            .font(InazumaTypography.caption)
                            .foregroundStyle(InazumaPalette.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                    }
                }
                .inazumaCard()

                InazumaSectionHeader("Config Summary")
                VStack(alignment: .leading, spacing: 8) {
                    configLine("Entry", "N/A")
                    configLine("Exit", "N/A")
                    configLine("Size", "N/A")
                    configLine("Max Positions", detail?.openPositions.map(String.init) ?? "N/A")
                    configLine("Universe Type", detail?.dynamicUniverse == true ? "dynamic" : "fixed")
                }
                .inazumaCard()

                InazumaSectionHeader("Recent Runs")
                VStack(spacing: 0) {
                    if runs.isEmpty {
                        Text("No runs found")
                            .font(InazumaTypography.caption)
                            .foregroundStyle(InazumaPalette.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    } else {
                        ForEach(Array(runs.prefix(10).enumerated()), id: \.element.id) { index, run in
                            HStack(spacing: 10) {
                                InazumaStatusDot(color: verdictColor(run.verdict), size: 6)
                                Text(run.runType.rawValue)
                                    .font(InazumaTypography.metric(size: 11, weight: .semibold))
                                    .foregroundStyle(InazumaPalette.cyan)
                                    .frame(width: 80, alignment: .leading)
                                Text(runSummary(run))
                                    .font(InazumaTypography.metric(size: 11, weight: .medium))
                                    .foregroundStyle(InazumaPalette.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(run.timestamp.relativeTimeString())
                                    .font(InazumaTypography.metric(size: 10, weight: .medium))
                                    .foregroundStyle(InazumaPalette.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)

                            if index < runs.prefix(10).count - 1 {
                                Divider().overlay(InazumaPalette.cyanBorder.opacity(0.35))
                            }
                        }
                    }
                }
                .inazumaCard()

                InazumaSectionHeader("Artifacts")
                artifactsSection(runs: runs)
            }
        }
    }

    private func artifactsSection(runs: [RunArtifactSummary]) -> some View {
        let latestRun = runs.first
        let files = artifactFiles(for: latestRun)

        return VStack(alignment: .leading, spacing: 10) {
            if let latestRun {
                Text("Latest run: \(latestRun.runType.rawValue)  |  \(latestRun.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .font(InazumaTypography.metric(size: 11, weight: .medium))
                    .foregroundStyle(InazumaPalette.textMuted)
            }

            if files.isEmpty {
                Text("No artifacts found")
                    .font(InazumaTypography.caption)
                    .foregroundStyle(InazumaPalette.textMuted)
            } else {
                ForEach(files, id: \.path) { fileURL in
                    HStack {
                        Text(icon(for: fileURL.pathExtension.lowercased()))
                        Text(fileURL.lastPathComponent)
                            .font(InazumaTypography.metric(size: 11, weight: .semibold))
                            .foregroundStyle(InazumaPalette.textPrimary)
                        Spacer()
                        Button("Preview") {
                            NSWorkspace.shared.open(fileURL)
                        }
                        .buttonStyle(.bordered)
                        .tint(InazumaPalette.cyan)

                        Button("Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .inazumaCard()
    }

    private func configLine(_ key: String, _ value: String) -> some View {
        HStack {
            Text("\(key):")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(InazumaPalette.textSecondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(InazumaTypography.metric(size: 12, weight: .semibold))
                .foregroundStyle(InazumaPalette.textPrimary)
            Spacer()
        }
    }

    private var filteredStrategies: [StrategySummary] {
        let filtered = viewModel.strategies.filter { strategy in
            searchText.isEmpty || strategy.name.localizedCaseInsensitiveContains(searchText)
        }

        switch sortOption {
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .sharpe:
            return filtered.sorted { ($0.pnl ?? -.infinity) > ($1.pnl ?? -.infinity) }
        case .status:
            return filtered.sorted { ($0.state ?? "").localizedCaseInsensitiveCompare($1.state ?? "") == .orderedAscending }
        case .lastRun:
            return filtered.sorted { lhs, rhs in
                (strategyRuns(for: lhs).first?.timestamp ?? .distantPast) > (strategyRuns(for: rhs).first?.timestamp ?? .distantPast)
            }
        }
    }

    private func strategyRuns(for strategy: StrategySummary) -> [RunArtifactSummary] {
        app.artifactRuns
            .filter { $0.strategyName.caseInsensitiveCompare(strategy.name) == .orderedSame }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func gateItems(for strategy: StrategySummary) -> [GateItem] {
        let sharpe = strategy.pnl ?? 0
        return [
            GateItem(name: "Baseline", symbol: sharpe > 0 ? "✓" : "-", detail: sharpe > 0 ? "S: \(String(format: "%.2f", sharpe))" : "Pending", color: sharpe > 0 ? InazumaPalette.green : InazumaPalette.textMuted),
            GateItem(name: "Slippage2x", symbol: "-", detail: "N/A", color: InazumaPalette.textMuted),
            GateItem(name: "WalkFwd", symbol: "-", detail: "N/A", color: InazumaPalette.textMuted),
            GateItem(name: "Shadow", symbol: "-", detail: "N/A", color: InazumaPalette.textMuted),
            GateItem(name: "Permutation", symbol: "-", detail: "Pending", color: InazumaPalette.textMuted),
        ]
    }

    private func artifactFiles(for run: RunArtifactSummary?) -> [URL] {
        guard let run else { return [] }
        return ArtifactFileKind.allCases
            .map { run.directory.appendingPathComponent($0.rawValue) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func stateSeverity(_ state: String?) -> InazumaSeverity {
        guard let state else { return .muted }
        let normalized = state.lowercased()
        if normalized.contains("live") || normalized.contains("active") { return .safe }
        if normalized.contains("shadow") { return .info }
        if normalized.contains("paper") { return .warning }
        return .muted
    }

    private func stateColor(_ state: String?) -> Color {
        stateSeverity(state).color
    }

    private func sharpeText(_ strategy: StrategySummary) -> String {
        if let value = strategy.pnl {
            return String(format: "%.2f", value)
        }
        return "N/A"
    }

    private func verdictColor(_ verdict: RunVerdict) -> Color {
        switch verdict {
        case .go:
            InazumaPalette.green
        case .noGo:
            InazumaPalette.red
        case .unknown:
            InazumaPalette.amber
        }
    }

    private func runSummary(_ run: RunArtifactSummary) -> String {
        if let sharpe = run.sharpe {
            return "Sharpe \(String(format: "%.2f", sharpe))"
        }
        if let drawdown = run.maxDrawdown {
            return "MaxDD \(String(format: "%.2f", drawdown))"
        }
        return "Metrics unavailable"
    }

    private func icon(for fileExtension: String) -> String {
        switch fileExtension {
        case "json":
            return "📊"
        case "csv":
            return "📋"
        case "png":
            return "📈"
        default:
            return "📄"
        }
    }
}

private enum StrategySortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case sharpe = "Sharpe"
    case status = "Status"
    case lastRun = "Last Run"

    var id: String { rawValue }
}

private struct GateItem {
    let name: String
    let symbol: String
    let detail: String
    let color: Color
}
