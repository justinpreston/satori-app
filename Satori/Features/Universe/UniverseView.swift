import SwiftUI

struct UniverseView: View {
    @ObservedObject var app: AppViewModel
    @StateObject private var viewModel: UniverseViewModel
    @State private var expandedStrategies = Set<String>()

    init(app: AppViewModel) {
        self.app = app
        _viewModel = StateObject(wrappedValue: UniverseViewModel(app: app))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let universe = viewModel.universe {
                    summaryBar(universe)
                    InazumaSectionHeader("Strategies")
                    strategyCards(universe)
                    InazumaSectionHeader("Ticker Overlap")
                    overlapPanel(universe)
                    InazumaSectionHeader("Tier Breakdown")
                    tierBreakdown(universe)
                } else {
                    ContentUnavailableView("No universe loaded", systemImage: "globe.americas", description: Text("Connect to engine and refresh."))
                        .foregroundStyle(InazumaPalette.textMuted)
                        .frame(maxWidth: .infinity)
                        .inazumaCard()
                }
            }
            .padding(16)
            .animation(.easeOut(duration: 0.2), value: expandedStrategies)
        }
    }

    private func summaryBar(_ universe: UniverseSnapshot) -> some View {
        let strategyCount = universe.strategies.count
        let unique = uniqueTickers(universe)
        let overlaps = overlapRows(universe).filter { $0.strategies.count > 1 }.count
        let lastScan = universe.lastScan?.formatted(date: .omitted, time: .shortened) ?? "N/A"

        return HStack(spacing: 10) {
            Text("\(strategyCount) strategies")
            Divider().frame(height: 14)
            Text("\(unique.count) unique tickers")
            Divider().frame(height: 14)
            Text("\(overlaps) shared across 2+ strategies")
            Divider().frame(height: 14)
            Text("Last scan: \(lastScan)")
            Spacer()
        }
        .font(InazumaTypography.metric(size: 12, weight: .semibold))
        .foregroundStyle(InazumaPalette.textSecondary)
        .padding(12)
        .inazumaCard(glow: true, borderColor: InazumaPalette.cyanBorder.opacity(0.65))
    }

    private func strategyCards(_ universe: UniverseSnapshot) -> some View {
        VStack(spacing: 10) {
            ForEach(universe.strategies.keys.sorted(), id: \.self) { strategy in
                let model = universe.strategies[strategy]
                let tier1 = model?.tier1 ?? []
                let tier2 = model?.tier2 ?? []

                DisclosureGroup(isExpanded: expandedBinding(for: strategy)) {
                    VStack(alignment: .leading, spacing: 8) {
                        tickerTagFlow(symbols: tier1 + tier2)
                        Text("Promotions queued: N/A")
                            .font(InazumaTypography.metric(size: 10, weight: .medium))
                            .foregroundStyle(InazumaPalette.textMuted)
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Text(strategy)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(InazumaPalette.textPrimary)
                        Spacer()
                        InazumaPill(text: "T1: \(tier1.count)", severity: .info, monospaced: true)
                        InazumaPill(text: "T2: \(tier2.count)", severity: .muted, monospaced: true)
                    }
                }
                .padding(12)
                .inazumaHoverCard()
            }
        }
    }

    private func tickerTagFlow(symbols: [String]) -> some View {
        let sortedSymbols = symbols.sorted()

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 6)], spacing: 6) {
            ForEach(sortedSymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(InazumaTypography.metric(size: 10, weight: .semibold))
                    .foregroundStyle(InazumaPalette.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(InazumaPalette.cyan.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(InazumaPalette.cyanBorder.opacity(0.8), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private func overlapPanel(_ universe: UniverseSnapshot) -> some View {
        let rows = overlapRows(universe)

        return VStack(alignment: .leading, spacing: 6) {
            if rows.isEmpty {
                Text("No overlap")
                    .font(InazumaTypography.caption)
                    .foregroundStyle(InazumaPalette.textMuted)
            } else {
                ForEach(rows.prefix(20), id: \.ticker) { row in
                    HStack {
                        Text(row.ticker)
                            .font(InazumaTypography.metric(size: 12, weight: .bold))
                            .foregroundStyle(InazumaPalette.textPrimary)
                            .frame(width: 80, alignment: .leading)
                        Text(row.strategies.joined(separator: ", "))
                            .font(InazumaTypography.metric(size: 11, weight: .medium))
                            .foregroundStyle(InazumaPalette.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text("(\(row.strategies.count))")
                            .font(InazumaTypography.metric(size: 11, weight: .semibold))
                            .foregroundStyle(row.strategies.count > 2 ? InazumaPalette.red : InazumaPalette.amber)
                    }
                }
            }
        }
        .inazumaCard()
    }

    private func tierBreakdown(_ universe: UniverseSnapshot) -> some View {
        let tier1Count = universe.strategies.values.reduce(0) { $0 + $1.tier1.count }
        let tier2Count = universe.strategies.values.reduce(0) { $0 + ($1.tier2?.count ?? 0) }
        let total = max(tier1Count + tier2Count, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Tier 1: \(tier1Count)  |  Tier 2: \(tier2Count)")
                .font(InazumaTypography.metric(size: 12, weight: .semibold))
                .foregroundStyle(InazumaPalette.textSecondary)

            InazumaProgressBar(value: Double(tier1Count), maxValue: Double(total))
                .frame(height: 8)

            InazumaProgressBar(value: Double(tier2Count), maxValue: Double(total), severityStops: (warning: Double(total) * 0.8, danger: Double(total) * 0.95))
                .frame(height: 8)
                .colorMultiply(InazumaPalette.textMuted)
        }
        .inazumaCard()
    }

    private func uniqueTickers(_ universe: UniverseSnapshot) -> Set<String> {
        var all = Set<String>()
        for strategy in universe.strategies.values {
            all.formUnion(strategy.tier1)
            all.formUnion(strategy.tier2 ?? [])
        }
        return all
    }

    private func overlapRows(_ universe: UniverseSnapshot) -> [TickerOverlap] {
        var map: [String: Set<String>] = [:]

        for (strategyName, strategyUniverse) in universe.strategies {
            for ticker in strategyUniverse.tier1 {
                map[ticker, default: []].insert(strategyName)
            }
            for ticker in strategyUniverse.tier2 ?? [] {
                map[ticker, default: []].insert(strategyName)
            }
        }

        return map.map { key, value in
            TickerOverlap(ticker: key, strategies: value.sorted())
        }
        .sorted {
            if $0.strategies.count == $1.strategies.count {
                return $0.ticker < $1.ticker
            }
            return $0.strategies.count > $1.strategies.count
        }
    }

    private func expandedBinding(for strategy: String) -> Binding<Bool> {
        Binding(
            get: { expandedStrategies.contains(strategy) },
            set: { expanded in
                if expanded {
                    expandedStrategies.insert(strategy)
                } else {
                    expandedStrategies.remove(strategy)
                }
            }
        )
    }
}

private struct TickerOverlap {
    let ticker: String
    let strategies: [String]
}
