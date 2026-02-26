import SwiftUI

struct RiskView: View {
    @ObservedObject var app: AppViewModel
    @StateObject private var viewModel: RiskViewModel

    init(app: AppViewModel) {
        self.app = app
        _viewModel = StateObject(wrappedValue: RiskViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                killSwitchCard

                InazumaSectionHeader("Limits")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    drawdownCard
                    dailyLossCard
                    concentrationCard
                }

                InazumaSectionHeader("Thresholds")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    vixCard
                    correlationCard
                }

                InazumaSectionHeader("Compliance")
                pdtCard
            }
            .padding(16)
        }
    }

    private var killSwitchCard: some View {
        let active = viewModel.riskMetrics?.killSwitchActive ?? false

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("KILL SWITCH", systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(InazumaPalette.textPrimary)
                Spacer()
                Text(active ? "ACTIVE" : "INACTIVE")
                    .font(InazumaTypography.metric(size: 18, weight: .bold))
                    .foregroundStyle(active ? InazumaPalette.red : InazumaPalette.green)
            }

            Rectangle()
                .fill((active ? InazumaPalette.red : InazumaPalette.green).opacity(0.18))
                .frame(height: 8)
                .clipShape(Capsule())

            HStack {
                Text("Last triggered: N/A")
                Spacer()
                Text("Armed: Yes")
            }
            .font(InazumaTypography.metric(size: 11, weight: .medium))
            .foregroundStyle(InazumaPalette.textMuted)
        }
        .inazumaCard(glow: active, borderColor: active ? InazumaPalette.red.opacity(0.45) : InazumaPalette.green.opacity(0.35))
    }

    private var drawdownCard: some View {
        let drawdown = abs(viewModel.riskMetrics?.drawdownPct ?? 0)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Drawdown")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)
            Text(percent(drawdown))
                .font(InazumaTypography.metric(size: 24, weight: .bold))
                .foregroundStyle(InazumaPalette.textPrimary)
            InazumaProgressBar(value: drawdown, maxValue: 30, severityStops: (warning: 20, danger: 25))
                .frame(height: 7)
            Text("\(percent(drawdown)) / 30% max")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
        }
        .inazumaCard()
    }

    private var dailyLossCard: some View {
        let loss = abs(viewModel.riskMetrics?.dailyPnlPct ?? 0)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Daily Loss")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)
            Text(percent(loss))
                .font(InazumaTypography.metric(size: 24, weight: .bold))
                .foregroundStyle(InazumaPalette.textPrimary)
            InazumaProgressBar(value: loss, maxValue: 2, severityStops: (warning: 1.4, danger: 1.8))
                .frame(height: 7)
            Text("\(percent(loss)) / 2% limit")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
        }
        .inazumaCard()
    }

    private var concentrationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Concentration")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)
            Text("N/A")
                .font(InazumaTypography.metric(size: 24, weight: .bold))
                .foregroundStyle(InazumaPalette.textPrimary)
            Text("No positions exceed limit")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
            Spacer(minLength: 0)
        }
        .inazumaCard()
    }

    private var vixCard: some View {
        let vix = viewModel.riskMetrics?.vix

        return VStack(alignment: .leading, spacing: 8) {
            Text("VIX Level")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)
            Text(vix.map { String(format: "%.2f", $0) } ?? "N/A")
                .font(InazumaTypography.metric(size: 24, weight: .bold))
                .foregroundStyle(vixColor)
            InazumaProgressBar(value: vix ?? 0, maxValue: 35, severityStops: (warning: 25, danger: 35))
                .frame(height: 7)
            Text("State: \(vixStateLabel)")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(vixColor)
        }
        .inazumaCard()
    }

    private var correlationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Correlation")
                .font(InazumaTypography.label)
                .foregroundStyle(InazumaPalette.textSecondary)
            Text("\(app.correlationAlerts.count)")
                .font(InazumaTypography.metric(size: 24, weight: .bold))
                .foregroundStyle(app.correlationAlerts.isEmpty ? InazumaPalette.green : InazumaPalette.amber)
            Text(app.correlationAlerts.isEmpty ? "No strategy pairs exceed threshold" : "Warnings above configured threshold")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)
            Spacer(minLength: 0)
        }
        .inazumaCard()
    }

    private var pdtCard: some View {
        let count = viewModel.pdtStatus?.count ?? 0
        let limit = max(viewModel.pdtStatus?.limit ?? 4, 1)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Pattern Day Trades (5-day rolling)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(InazumaPalette.textPrimary)

            HStack(spacing: 6) {
                ForEach(0..<limit, id: \.self) { index in
                    Circle()
                        .fill(index < count ? pdtColor : InazumaPalette.amber.opacity(0.2))
                        .frame(width: 11, height: 11)
                        .shadow(color: index < count ? pdtColor.opacity(0.45) : .clear, radius: 5)
                }
                Text("\(count) of \(limit) allowed")
                    .font(InazumaTypography.metric(size: 12, weight: .semibold))
                    .foregroundStyle(InazumaPalette.textSecondary)
            }

            Text("Next reset: N/A")
                .font(InazumaTypography.metric(size: 11, weight: .medium))
                .foregroundStyle(InazumaPalette.textMuted)

            if count >= max(limit - 1, 1) {
                Text("One remaining - next same-day round-trip triggers PDT flag")
                    .font(InazumaTypography.metric(size: 11, weight: .semibold))
                    .foregroundStyle(InazumaPalette.amber)
            }

            if let trades = viewModel.pdtStatus?.trades, !trades.isEmpty {
                Divider().overlay(InazumaPalette.cyanBorder.opacity(0.4))
                ForEach(trades.prefix(5)) { trade in
                    HStack {
                        Text("\(trade.tradeDate) \(trade.symbol)")
                        Spacer()
                        Text(trade.strategy)
                    }
                    .font(InazumaTypography.metric(size: 10, weight: .medium))
                    .foregroundStyle(InazumaPalette.textMuted)
                }
            }
        }
        .inazumaCard(borderColor: pdtColor.opacity(0.35))
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }

    private var pdtColor: Color {
        guard let pdt = viewModel.pdtStatus else { return InazumaPalette.textPrimary }
        if pdt.count >= pdt.limit { return InazumaPalette.red }
        if pdt.count >= max(pdt.limit - 1, 1) { return InazumaPalette.amber }
        return InazumaPalette.green
    }

    private var vixColor: Color {
        guard let vix = viewModel.riskMetrics?.vix else { return InazumaPalette.textPrimary }
        if vix > 35 { return InazumaPalette.red }
        if vix >= 25 { return InazumaPalette.amber }
        return InazumaPalette.green
    }

    private var vixStateLabel: String {
        guard let vix = viewModel.riskMetrics?.vix else { return "N/A" }
        if vix > 35 { return "Red (above threshold)" }
        if vix >= 25 { return "Amber (approaching)" }
        return "Green (below threshold)"
    }
}
