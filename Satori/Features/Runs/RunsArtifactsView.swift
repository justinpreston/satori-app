import AppKit
import SwiftUI

struct RunsArtifactsView: View {
    @ObservedObject var app: AppViewModel
    @StateObject private var viewModel: RunsArtifactsViewModel

    @AppStorage("runs.inspectorVisibleByDefault") private var inspectorVisibleByDefault = true

    @State private var selectedRunID: String?
    @State private var selectedKind: ArtifactFileKind = .metricsJSON
    @State private var artifactText: String = ""
    @State private var csvRows: [String] = []
    @State private var previewImage: NSImage?
    @State private var baselineRunID: String?
    @State private var metricDiffs: [MetricDiff] = []
    @State private var diffError: String?

    @State private var strategyFilter = ""
    @State private var typeFilter: RunType? = nil
    @State private var verdictFilter: RunVerdict? = nil

    @State private var runSortOrder: [KeyPathComparator<RunArtifactSummary>] = [
        KeyPathComparator(\.timestamp, order: .reverse)
    ]
    @State private var diffSortOrder: [KeyPathComparator<MetricDiff>] = [
        KeyPathComparator(\.metric, order: .forward)
    ]

    @State private var isInspectorPresented = true
    @State private var didApplyInspectorPreference = false

    init(app: AppViewModel) {
        self.app = app
        _viewModel = StateObject(wrappedValue: RunsArtifactsViewModel(app: app))
    }

    var body: some View {
        VStack(spacing: 12) {
            filterBar

            if filteredRuns.isEmpty {
                ContentUnavailableView("No runs", systemImage: "shippingbox", description: Text("No runs matched current filters."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredRuns, selection: $selectedRunID, sortOrder: $runSortOrder) {
                    TableColumn("Strategy", value: \.strategyName)
                        .width(min: 140, ideal: 180)

                    TableColumn("Type", value: \.runTypeLabel)
                        .width(min: 88, ideal: 100)

                    TableColumn("Verdict", value: \.verdictLabel) { run in
                        Text(run.verdict.rawValue)
                            .foregroundStyle(verdictColor(run.verdict))
                    }
                    .width(min: 90, ideal: 100)

                    TableColumn("Sharpe", value: \.sharpeSortValue) { run in
                        Text(metricText(run.sharpe))
                            .font(InazumaTypography.metric(size: 12, weight: .medium))
                    }
                    .width(min: 90, ideal: 100)

                    TableColumn("MaxDD", value: \.maxDrawdownSortValue) { run in
                        Text(metricText(run.maxDrawdown))
                            .font(InazumaTypography.metric(size: 12, weight: .medium))
                    }
                    .width(min: 90, ideal: 100)

                    TableColumn("Timestamp", value: \.timestamp) { run in
                        Text(run.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 170, ideal: 220)
                }
            }
        }
        .padding(14)
        .onAppear {
            if !didApplyInspectorPreference {
                isInspectorPresented = inspectorVisibleByDefault
                didApplyInspectorPreference = true
            }
            if selectedRunID == nil {
                selectedRunID = filteredRuns.first?.id
            }
        }
        .onChange(of: selectedRunID) { _, _ in
            syncBaselineSelection()
            loadSelectedArtifacts()
            loadDiffIfPossible()
        }
        .onChange(of: selectedKind) { _, _ in
            loadSelectedArtifacts()
        }
        .onChange(of: baselineRunID) { _, _ in
            loadDiffIfPossible()
        }
        .onChange(of: filteredRuns.map(\.id)) { _, ids in
            guard !ids.isEmpty else {
                selectedRunID = nil
                return
            }
            if let selectedRunID, ids.contains(selectedRunID) {
                return
            }
            selectedRunID = ids.first
        }
        .inspector(isPresented: $isInspectorPresented) {
            inspectorContent
                .inspectorColumnWidth(min: 320, ideal: 380, max: 520)
        }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    viewModel.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .disabled(selectedRun == nil)
            }
        }
        .animation(.easeOut(duration: 0.18), value: selectedRunID)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            TextField("Filter strategy", text: $strategyFilter)
                .inazumaInputField()
                .frame(minWidth: 220)

            Picker("Type", selection: $typeFilter) {
                Text("All Types").tag(RunType?.none)
                ForEach(RunType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(Optional(type))
                }
            }
            .pickerStyle(.menu)

            Picker("Status", selection: $verdictFilter) {
                Text("All Status").tag(RunVerdict?.none)
                Text("GO").tag(Optional(RunVerdict.go))
                Text("NO_GO").tag(Optional(RunVerdict.noGo))
                Text("Unknown").tag(Optional(RunVerdict.unknown))
            }
            .pickerStyle(.menu)

            Spacer()

            Text("\(filteredRuns.count) runs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let selectedRun {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    runSummarySection(selectedRun)
                    artifactSection(selectedRun)
                    compareSection(selectedRun)
                }
                .padding(12)
            }
        } else {
            ContentUnavailableView(
                "Select a run",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Select a row to inspect artifacts and metrics.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func runSummarySection(_ run: RunArtifactSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(run.strategyName)
                .font(.headline)

            Text("\(run.runTypeLabel) • \(run.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            GroupBox("Metrics") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    metricGridRow("Sharpe", metricText(run.sharpe), metricColor(run.sharpe))
                    metricGridRow("Max Drawdown", metricText(run.maxDrawdown), .primary)
                    metricGridRow("Walk-Forward", metricText(run.walkForwardRatio), .primary)
                    metricGridRow("Monte Carlo p", metricText(run.monteCarloPValue), .primary)
                    metricGridRow("Slippage", metricText(run.slippageSensitivity), .primary)
                    metricGridRow("Verdict", run.verdict.rawValue, verdictColor(run.verdict))
                }
                .padding(.top, 4)
            }
        }
        .inazumaCard()
    }

    private func metricGridRow(_ key: String, _ value: String, _ valueColor: Color) -> some View {
        GridRow {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(InazumaTypography.metric(size: 12, weight: .semibold))
                .foregroundStyle(valueColor)
        }
    }

    private func artifactSection(_ run: RunArtifactSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Artifacts")
                    .font(.headline)

                Spacer()

                Picker("Artifact", selection: $selectedKind) {
                    ForEach(ArtifactFileKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.menu)

                Button("Copy Path") {
                    let path = run.directory.appendingPathComponent(selectedKind.rawValue).path
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }

                Button("Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([run.directory])
                }
            }

            Group {
                if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                } else if !csvRows.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(csvRows.prefix(50).enumerated()), id: \.offset) { _, row in
                                Text(row)
                                    .font(InazumaTypography.metric(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                } else {
                    ScrollView {
                        Text(artifactText)
                            .font(InazumaTypography.metric(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 280)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .inazumaCard()
    }

    private func compareSection(_ run: RunArtifactSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Compare Metrics")
                    .font(.headline)

                Picker("Baseline", selection: $baselineRunID) {
                    Text("None").tag(String?.none)
                    ForEach(filteredRuns.filter { $0.id != run.id }) { candidate in
                        Text("\(candidate.strategyName) • \(candidate.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .tag(Optional(candidate.id))
                    }
                }
                .pickerStyle(.menu)
            }

            if let diffError {
                Text(diffError)
                    .font(.caption)
                    .foregroundStyle(InazumaPalette.red)
            }

            if metricDiffs.isEmpty {
                Text("Select a baseline run to compare metrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Table(metricDiffs, sortOrder: $diffSortOrder) {
                    TableColumn("Metric", value: \.metric)
                        .width(min: 120, ideal: 150)

                    TableColumn("Baseline", value: \.baselineValue) { diff in
                        Text(formatMetric(diff.baselineValue))
                            .font(InazumaTypography.metric(size: 11, weight: .medium))
                    }
                    .width(min: 72, ideal: 90)

                    TableColumn("Candidate", value: \.candidateValue) { diff in
                        Text(formatMetric(diff.candidateValue))
                            .font(InazumaTypography.metric(size: 11, weight: .medium))
                    }
                    .width(min: 72, ideal: 90)

                    TableColumn("Delta", value: \.delta) { diff in
                        Text(signedMetric(diff.delta))
                            .font(InazumaTypography.metric(size: 11, weight: .semibold))
                            .foregroundStyle(diff.delta >= 0 ? InazumaPalette.green : InazumaPalette.red)
                    }
                    .width(min: 72, ideal: 90)
                }
                .frame(minHeight: 180)
            }
        }
        .inazumaCard()
    }

    private var filteredRuns: [RunArtifactSummary] {
        app.artifactRuns
            .filter { run in
                let strategyMatch = strategyFilter.isEmpty || run.strategyName.localizedCaseInsensitiveContains(strategyFilter)
                let typeMatch = typeFilter == nil || run.runType == typeFilter
                let verdictMatch = verdictFilter == nil || run.verdict == verdictFilter
                return strategyMatch && typeMatch && verdictMatch
            }
            .sorted(using: runSortOrder)
    }

    private var selectedRun: RunArtifactSummary? {
        guard let selectedRunID else { return nil }
        return filteredRuns.first(where: { $0.id == selectedRunID }) ?? app.artifactRuns.first(where: { $0.id == selectedRunID })
    }

    private func syncBaselineSelection() {
        guard let selectedRunID else {
            baselineRunID = nil
            return
        }
        if baselineRunID == selectedRunID {
            baselineRunID = nil
        }
        if baselineRunID == nil {
            baselineRunID = filteredRuns.first(where: { $0.id != selectedRunID })?.id
        }
    }

    private func loadSelectedArtifacts() {
        guard let selectedRun else {
            previewImage = nil
            artifactText = ""
            csvRows = []
            return
        }
        loadArtifact(run: selectedRun)
    }

    private func loadArtifact(run: RunArtifactSummary) {
        Task {
            do {
                previewImage = nil
                artifactText = ""
                csvRows = []

                let artifact = try await app.artifactStore.loadArtifact(run: run, fileKind: selectedKind)
                switch artifact {
                case .json(let json):
                    artifactText = json
                case .csv(let rows):
                    csvRows = rows
                case .image(let url):
                    previewImage = NSImage(contentsOf: url)
                case .text(let text):
                    artifactText = text
                }
            } catch {
                artifactText = "Failed to load artifact: \(error.localizedDescription)"
            }
        }
    }

    private func loadDiffIfPossible() {
        guard let selectedRun, let baselineRunID,
              let baseline = filteredRuns.first(where: { $0.id == baselineRunID }) else {
            metricDiffs = []
            diffError = nil
            return
        }

        Task {
            do {
                metricDiffs = try await app.artifactStore.diffMetrics(run: selectedRun, baseline: baseline)
                diffError = nil
            } catch {
                metricDiffs = []
                diffError = "Metric diff failed: \(error.localizedDescription)"
            }
        }
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

    private func metricColor(_ value: Double?) -> Color {
        guard let value else { return InazumaPalette.textPrimary }
        return value >= 0 ? InazumaPalette.green : InazumaPalette.red
    }

    private func metricText(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.3f", value)
    }

    private func formatMetric(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func signedMetric(_ value: Double) -> String {
        String(format: "%+.3f", value)
    }
}
