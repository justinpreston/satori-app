import SwiftUI

struct HomeView: View {
    @ObservedObject var app: AppViewModel
    @StateObject private var viewModel: HomeViewModel

    @State private var backtestInput = BacktestLaunchInput()
    @State private var validateInput = ValidateLaunchInput()
    @State private var promoteInput = PromoteLaunchInput()

    @State private var showBacktestSheet = false
    @State private var showValidateSheet = false
    @State private var showPromoteSheet = false

    init(app: AppViewModel) {
        self.app = app
        _viewModel = StateObject(wrappedValue: HomeViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topStatusBar

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                    dailyPnlCard
                    drawdownCard
                    positionsCard
                    riskVetoCard
                    pdtCard
                    lastSnapshotCard
                }

                actionToolbar

                InazumaSectionHeader("Recent Runs") {
                    Text("View All")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(InazumaPalette.cyan)
                }

                recentRunsSection

                InazumaSectionHeader("Strategy Health")
                strategyHealthSection

                InazumaSectionHeader("Alert Feed")
                alertFeedSection
            }
            .padding(20)
            .animation(.easeOut(duration: 0.22), value: app.dashboardSnapshot?.timestamp)
            .animation(.easeOut(duration: 0.22), value: app.artifactRuns.count)
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showBacktestSheet) {
            NavigationStack {
                Form {
                    TextField("Strategy", text: $backtestInput.strategy)
                    TextField("Start (YYYY-MM-DD)", text: $backtestInput.startDate)
                    TextField("End (YYYY-MM-DD)", text: $backtestInput.endDate)
                    TextField("Config path", text: $backtestInput.configPath)
                }
                .navigationTitle("Start Backtest")
                .toolbar {
                    Button("Run") {
                        app.runBacktest(backtestInput)
                        showBacktestSheet = false
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 260)
        }
        .sheet(isPresented: $showValidateSheet) {
            NavigationStack {
                Form {
                    TextField("Result JSON path", text: $validateInput.resultPath)
                    Stepper("Folds: \(validateInput.folds)", value: $validateInput.folds, in: 0...10)
                    Stepper("Permutations: \(validateInput.permutations)", value: $validateInput.permutations, in: 100...20_000, step: 100)
                }
                .navigationTitle("Validate Tier 4")
                .toolbar {
                    Button("Run") {
                        app.runValidate(validateInput)
                        showValidateSheet = false
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 260)
        }
        .sheet(isPresented: $showPromoteSheet) {
            NavigationStack {
                Form {
                    TextField("Strategy", text: $promoteInput.strategy)
                    TextField("Returns CSV", text: $promoteInput.returnsCSV)
                    TextField("Equity CSV", text: $promoteInput.equityCSV)
                    TextField("Config path", text: $promoteInput.configPath)
                    Toggle("Override conditional", isOn: $promoteInput.override)
                }
                .navigationTitle("Promote Strategy")
                .toolbar {
                    Button("Run") {
                        app.runPromote(promoteInput)
                        showPromoteSheet = false
                    }
                }
            }
            .frame(minWidth: 560, minHeight: 320)
        }
    }

    private var topStatusBar: some View {
        HStack(spacing: 14) {
            statusCell(color: engineSeverityColor, text: "Engine \(engineState.label)")
            Divider().frame(height: 14)
            statusCell(color: marketStatusColor, text: "Market \(marketStatusText)")
            Divider().frame(height: 14)
            Text("WS: \(String(format: "%.1f", app.latencyMs))ms")
                .font(InazumaTypography.metric(size: 12, weight: .semibold))
                .foregroundStyle(wsLatencyColor)
            Divider().frame(height: 14)
            Text("Last tick: \(lastTickText)")
                .font(InazumaTypography.metric(size: 12, weight: .medium))
                .foregroundStyle(InazumaPalette.textSecondary)
            Spacer()
        }
        .padding(12)
        .inazumaCard(borderColor: InazumaPalette.cyanBorder.opacity(0.7))
    }

    private func statusCell(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            InazumaStatusDot(color: color)
            Text(text)
                .font(InazumaTypography.metric(size: 12, weight: .semibold))
                .foregroundStyle(InazumaPalette.textPrimary)
        }
    }

    private var dailyPnlCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily P&L")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)

            Text(dailyPnlDollarText)
                .font(InazumaTypography.heroMetric)
                .foregroundStyle(dailyPnlColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                InazumaStatusDot(color: dailyPnlColor, size: 7, filled: isDailyPnlPositive)
                InazumaDirectionBadge(
                    direction: dailyPnlDirection,
                    color: dailyPnlColor,
                    label: dailyPnlDirectionText
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inazumaCard(glow: true, borderColor: InazumaPalette.cyan.opacity(0.28))
    }

    private var drawdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drawdown")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)

            Text(viewModel.drawdownPctText)
                .font(InazumaTypography.metric(size: 24, weight: .bold))
                .foregroundStyle(InazumaPalette.textPrimary)

            InazumaProgressBar(
                value: abs(app.riskMetrics?.drawdownPct ?? 0),
                maxValue: 30,
                severityStops: (warning: 20, danger: 25)
            )
            .frame(height: 6)

            Text("\(viewModel.drawdownPctText) / 30% max")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inazumaCard()
    }

    private var positionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open Positions")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)

            Text("\(viewModel.openPositionsCount)")
                .font(InazumaTypography.metric(size: 24, weight: .bold))
                .foregroundStyle(InazumaPalette.textPrimary)

            Text(positionSymbolsText)
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inazumaCard()
    }

    private var riskVetoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Risk Veto")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)

            InazumaPill(
                text: viewModel.vetoCountProxy == 0 ? "CLEAR" : "ACTIVE",
                severity: viewModel.vetoCountProxy == 0 ? .safe : .danger,
                monospaced: true
            )

            Text("\(viewModel.vetoCountProxy) warning events")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inazumaCard(borderColor: viewModel.vetoCountProxy == 0 ? InazumaPalette.green.opacity(0.32) : InazumaPalette.red.opacity(0.32))
    }

    private var pdtCard: some View {
        let count = app.pdtStatus?.count ?? 0
        let limit = max(app.pdtStatus?.limit ?? 4, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("PDT")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)

            Text(viewModel.pdtText)
                .font(InazumaTypography.metric(size: 24, weight: .bold))
                .foregroundStyle(pdtColor)

            HStack(spacing: 6) {
                ForEach(0..<limit, id: \.self) { index in
                    Circle()
                        .fill(index < count ? pdtColor : InazumaPalette.amber.opacity(0.20))
                        .frame(width: 9, height: 9)
                        .shadow(color: index < count ? pdtColor.opacity(0.4) : .clear, radius: 4)
                }
            }

            Text("\(count)/\(limit) used")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inazumaCard()
    }

    private var lastSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Snapshot")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)

            Text(lastTickRelativeText)
                .font(InazumaTypography.metric(size: 20, weight: .bold))
                .foregroundStyle(InazumaPalette.textPrimary)
                .help(viewModel.lastBarText)

            Text(viewModel.lastBarText)
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inazumaCard()
    }

    private var actionToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    app.openMonitor()
                } label: {
                    Label("Launch TUI", systemImage: "terminal")
                }
                .buttonStyle(InazumaActionButtonStyle())

                Button {
                    showBacktestSheet = true
                } label: {
                    Label("Backtest", systemImage: "play.fill")
                }
                .buttonStyle(InazumaActionButtonStyle())

                Button {
                    showValidateSheet = true
                } label: {
                    Label("Validate", systemImage: "checkmark.shield")
                }
                .buttonStyle(InazumaActionButtonStyle())

                Button {
                    showPromoteSheet = true
                } label: {
                    Label("Promote", systemImage: "arrow.up.circle")
                }
                .buttonStyle(InazumaActionButtonStyle())

                Button {
                } label: {
                    Label("Shadow", systemImage: "eye.fill")
                }
                .buttonStyle(InazumaActionButtonStyle())
                .disabled(true)
                .help("CLI action not available in current build")
            }
        }
    }

    private var recentRunsSection: some View {
        VStack(spacing: 0) {
            if recentRuns.isEmpty {
                Text("No runs indexed yet")
                    .font(InazumaTypography.caption)
                    .foregroundStyle(InazumaPalette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                ForEach(Array(recentRuns.enumerated()), id: \.element.id) { index, run in
                    Button {
                    } label: {
                        HStack(spacing: 10) {
                            InazumaStatusDot(color: verdictColor(run.verdict), size: 6)
                            Text(run.strategyName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(InazumaPalette.textPrimary)
                                .frame(width: 120, alignment: .leading)
                            InazumaRunTypePill(runType: run.runType)
                            Text(runSummaryText(run))
                                .font(InazumaTypography.metric(size: 12, weight: .medium))
                                .foregroundStyle(InazumaPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(run.timestamp.relativeTimeString())
                                .font(InazumaTypography.metric(size: 11, weight: .medium))
                                .foregroundStyle(InazumaPalette.textMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if index < recentRuns.count - 1 {
                        Divider().overlay(InazumaPalette.cyanBorder.opacity(0.35))
                    }
                }
            }
        }
        .inazumaCard()
    }

    private var strategyHealthSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 12) {
            ForEach(strategyHealthItems) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        InazumaStatusDot(color: strategyStatusColor(item.state), size: 6)
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(InazumaPalette.textPrimary)
                        Text(StrategyState(rawValue: item.state).label)
                            .font(InazumaTypography.metric(size: 10, weight: .semibold))
                            .foregroundStyle(InazumaPalette.textMuted)
                        Spacer()
                        Text(item.sharpeText)
                            .font(InazumaTypography.metric(size: 16, weight: .bold))
                            .foregroundStyle(InazumaPalette.cyan)
                    }

                    SparklineView(values: item.sparkline)
                        .frame(height: 34)

                    Text(item.gatesText)
                        .font(InazumaTypography.metric(size: 10, weight: .medium))
                        .foregroundStyle(InazumaPalette.textMuted)
                }
                .inazumaCard()
            }
        }
    }

    private var alertFeedSection: some View {
        VStack(spacing: 0) {
            if recentAlerts.isEmpty {
                Text("No alerts")
                    .font(InazumaTypography.caption)
                    .foregroundStyle(InazumaPalette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                ForEach(Array(recentAlerts.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(item.color)
                        Text(item.message)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(InazumaPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.relativeTime)
                            .font(InazumaTypography.metric(size: 11, weight: .medium))
                            .foregroundStyle(InazumaPalette.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    if index < recentAlerts.count - 1 {
                        Divider().overlay(InazumaPalette.cyanBorder.opacity(0.35))
                    }
                }
            }
        }
        .inazumaCard()
    }

    private var recentRuns: [RunArtifactSummary] {
        Array(app.artifactRuns.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5))
    }

    private var strategyHealthItems: [StrategyHealthItem] {
        Array(app.strategies.prefix(6)).map { strategy in
            StrategyHealthItem(
                id: strategy.id,
                name: strategy.name,
                state: strategy.state ?? "candidate",
                sharpeText: strategy.pnl.map { String(format: "%.2f", $0) } ?? "N/A",
                gatesText: "Gates: N/A",
                sparkline: strategy.pnlHistory ?? syntheticSparkline(seed: strategy.name)
            )
        }
    }

    private var recentAlerts: [HomeAlertItem] {
        if let alerts = app.dashboardSnapshot?.alerts, !alerts.isEmpty {
            return Array(alerts.prefix(3)).map { alert in
                let severity = AlertSeverity(rawValue: alert.severity)
                return HomeAlertItem(
                    id: alert.id,
                    message: alert.message,
                    symbol: symbol(forSeverity: severity),
                    color: color(forSeverity: severity),
                    relativeTime: alert.timestamp?.relativeTimeString() ?? "now"
                )
            }
        }

        if !app.correlationAlerts.isEmpty {
            return Array(app.correlationAlerts.prefix(3)).enumerated().map { index, alert in
                HomeAlertItem(
                    id: "corr-\(index)-\(alert.id)",
                    message: "Correlation \(alert.strategyA) / \(alert.strategyB): \(String(format: "%.2f", alert.correlation))",
                    symbol: "exclamationmark.triangle.fill",
                    color: InazumaPalette.amber,
                    relativeTime: "recent"
                )
            }
        }

        return []
    }

    private var wsLatencyColor: Color {
        if app.latencyMs < 10 { return InazumaPalette.green }
        if app.latencyMs < 100 { return InazumaPalette.amber }
        return InazumaPalette.red
    }

    private var marketStatusText: String {
        switch engineState {
        case .active, .live:
            return "Open"
        case .warmup, .cooling:
            return "Transition"
        default:
            return "Closed"
        }
    }

    private var marketStatusColor: Color {
        switch marketStatusText {
        case "Open":
            InazumaPalette.green
        case "Transition":
            InazumaPalette.amber
        default:
            InazumaPalette.red
        }
    }

    private var dailyPnlColor: Color {
        guard let value = app.riskMetrics?.dailyPnlPct else { return InazumaPalette.textPrimary }
        return value >= 0 ? InazumaPalette.green : InazumaPalette.red
    }

    private var dailyPnlDirection: InazumaDirection {
        guard let value = app.riskMetrics?.dailyPnlPct else { return .flat }
        if value > 0 { return .up }
        if value < 0 { return .down }
        return .flat
    }

    private var dailyPnlDirectionText: String {
        guard let value = app.riskMetrics?.dailyPnlPct else { return "0.00%" }
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.2f", abs(value)))%"
    }

    private var isDailyPnlPositive: Bool {
        (app.riskMetrics?.dailyPnlPct ?? 0) >= 0
    }

    private var dailyPnlDollarText: String {
        guard let pct = app.riskMetrics?.dailyPnlPct,
              let equity = app.dashboardSnapshot?.portfolio?.equity else {
            return "N/A"
        }
        let value = equity * (pct / 100)
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", abs(value)))"
    }

    private var pdtColor: Color {
        guard let pdt = app.pdtStatus else { return InazumaPalette.textPrimary }
        if pdt.count >= pdt.limit { return InazumaPalette.red }
        if pdt.count >= max(pdt.limit - 1, 1) { return InazumaPalette.amber }
        return InazumaPalette.green
    }

    private var positionSymbolsText: String {
        let symbols = app.positions.prefix(4).map(\.symbol)
        return symbols.isEmpty ? "None" : symbols.joined(separator: "  ·  ")
    }

    private var lastTickText: String {
        guard let lastMessageAt = app.lastMessageAt else { return "N/A" }
        return lastMessageAt.formatted(date: .omitted, time: .standard)
    }

    private var lastTickRelativeText: String {
        guard let ts = app.dashboardSnapshot?.timestamp else { return "N/A" }
        return ts.relativeTimeString()
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

    private func runSummaryText(_ run: RunArtifactSummary) -> String {
        if let sharpe = run.sharpe {
            return "Sharpe: \(String(format: "%.2f", sharpe))"
        }
        if let drawdown = run.maxDrawdown {
            return "MaxDD: \(String(format: "%.2f", drawdown))"
        }
        return "No metrics"
    }

    private func strategyStatusColor(_ value: String?) -> Color {
        switch StrategyState(rawValue: value) {
        case .active, .live:
            return InazumaPalette.green
        case .shadow:
            return InazumaPalette.blue
        case .paper, .warmup, .cooling:
            return InazumaPalette.amber
        case .paused, .stopped:
            return InazumaPalette.red
        case .unknown:
            return InazumaPalette.textMuted
        }
    }

    private func syntheticSparkline(seed: String) -> [Double] {
        var generator = SeededGenerator(seed: seed)
        var current = Double.random(in: 90...110, using: &generator)
        var output: [Double] = []
        for _ in 0..<7 {
            current += Double.random(in: -4...5, using: &generator)
            output.append(current)
        }
        return output
    }

    private func symbol(forSeverity severity: AlertSeverity) -> String {
        switch severity {
        case .critical:
            "exclamationmark.octagon.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .info:
            "checkmark.circle.fill"
        case .unknown:
            "questionmark.circle.fill"
        }
    }

    private func color(forSeverity severity: AlertSeverity) -> Color {
        switch severity {
        case .critical:
            InazumaPalette.red
        case .warning:
            InazumaPalette.amber
        case .info:
            InazumaPalette.green
        case .unknown:
            InazumaPalette.textMuted
        }
    }

    private var engineState: StrategyState {
        StrategyState(rawValue: app.dashboardSnapshot?.engineState ?? app.statusResponse?.engineState)
    }

    private var engineSeverityColor: Color {
        switch EngineSeverity(engineState: app.dashboardSnapshot?.engineState ?? app.statusResponse?.engineState) {
        case .safe:
            return InazumaPalette.green
        case .warning:
            return InazumaPalette.amber
        case .critical:
            return InazumaPalette.red
        case .unknown:
            return InazumaPalette.textMuted
        }
    }
}

private struct StrategyHealthItem: Identifiable {
    let id: String
    let name: String
    let state: String
    let sharpeText: String
    let gatesText: String
    let sparkline: [Double]
}

private struct HomeAlertItem: Identifiable {
    let id: String
    let message: String
    let symbol: String
    let color: Color
    let relativeTime: String
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        state = UInt64(abs(seed.hashValue))
        if state == 0 {
            state = 0xA341_316C
        }
    }

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1
        return state
    }
}
