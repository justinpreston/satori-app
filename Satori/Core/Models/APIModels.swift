import Foundation

struct DashboardSnapshot: Decodable {
    let timestamp: Date?
    let portfolio: PortfolioState?
    let strategies: [String: StrategySnapshot]?
    let recentTrades: [TradeRecord]?
    let riskMetrics: RiskMetrics?
    let performance: PerformanceSnapshot?
    let engineState: String?
    let alerts: [AlertRecord]?
    let execution: ExecutionSnapshot?
    let infrastructure: InfrastructureSnapshot?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case portfolio
        case strategies
        case recentTrades = "recent_trades"
        case riskMetrics = "risk_metrics"
        case performance
        case engineState = "engine_state"
        case alerts
        case execution
        case infrastructure
    }
}

struct CorrelationAlertMessage: Decodable {
    let type: String
    let alerts: [CorrelationAlert]
    let threshold: Double?
}

struct CorrelationAlert: Decodable, Identifiable {
    var id: String { "\(strategyA)-\(strategyB)" }
    let strategyA: String
    let strategyB: String
    let correlation: Double

    enum CodingKeys: String, CodingKey {
        case strategyA = "strategy_a"
        case strategyB = "strategy_b"
        case correlation
    }
}

struct PortfolioState: Decodable {
    let equity: Double
    let numPositions: Int
    let unrealizedPnL: Double
    let positions: [PositionRecord]

    enum CodingKeys: String, CodingKey {
        case equity
        case numPositions = "num_positions"
        case unrealizedPnL = "unrealized_pnl"
        case positions
    }
}

struct PositionRecord: Decodable, Identifiable, Hashable {
    var id: String { symbol }
    let symbol: String
    let qty: Int
    let avgPrice: Double
    let marketValue: Double?
    let unrealizedPnL: Double

    enum CodingKeys: String, CodingKey {
        case symbol
        case qty
        case avgPrice = "avg_price"
        case marketValue = "market_value"
        case unrealizedPnL = "unrealized_pnl"
    }
}

struct StrategySnapshot: Decodable {
    let name: String?
    let signals: Int?
    let positions: Int?
    let state: String?
    let pnl: Double?
    let universe: [String]?
    let pnlToday: Double?
    let tradesToday: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case signals
        case positions
        case state
        case pnl
        case universe
        case pnlToday = "pnl_today"
        case tradesToday = "trades_today"
    }
}

struct StrategySummary: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let state: String?
    let enabled: Bool?
    let intraday: Bool?
    let signals: Int?
    let openPositions: Int?
    let tradesToday: Int?
    let pnlToday: Double?
    let pnlTotal: Double?
    let pnl: Double?
    let winRatePct: Double?
    let pnlHistory: [Double]?

    enum CodingKeys: String, CodingKey {
        case name
        case state
        case enabled
        case intraday
        case signals
        case openPositions = "open_positions"
        case tradesToday = "trades_today"
        case pnlToday = "pnl_today"
        case pnlTotal = "pnl_total"
        case pnl
        case winRatePct = "win_rate_pct"
        case pnlHistory = "pnl_history"
    }
}

struct TradeRecord: Decodable, Identifiable, Hashable {
    var id: String { "\(orderID)-\(timestamp?.description ?? "na")" }
    let orderID: String
    let symbol: String
    let side: String
    let qty: Int
    let price: Double
    let strategy: String?
    let timestamp: Date?
    let slippageBps: Double?
    let latencyMs: Double?

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case symbol
        case side
        case qty
        case price
        case strategy
        case timestamp
        case slippageBps = "slippage_bps"
        case latencyMs = "latency_ms"
    }
}

struct RiskMetrics: Decodable {
    let drawdownPct: Double
    let dailyPnlPct: Double
    let killSwitchActive: Bool
    let vix: Double
    let equityPeak: Double?
    let dailyStartEquity: Double?
    let pdt: PdtSummary?

    enum CodingKeys: String, CodingKey {
        case drawdownPct = "drawdown_pct"
        case dailyPnlPct = "daily_pnl_pct"
        case killSwitchActive = "kill_switch_active"
        case vix
        case equityPeak = "equity_peak"
        case dailyStartEquity = "daily_start_equity"
        case pdt
    }
}

struct PdtSummary: Decodable {
    let count: Int
    let limit: Int
    let remaining: Int
    let exempt: Bool
}

struct PdtStatus: Decodable {
    let count: Int
    let limit: Int
    let remaining: Int
    let exempt: Bool
    let trades: [PdtTrade]
}

struct PdtTrade: Decodable, Identifiable {
    let id: Int
    let tradeDate: String
    let symbol: String
    let strategy: String

    enum CodingKeys: String, CodingKey {
        case id
        case tradeDate = "trade_date"
        case symbol
        case strategy
    }
}

struct PerformanceSnapshot: Decodable {
    let totalRealizedPnl: Double?
    let tradeCount: Int?
    let winRatePct: Double?

    enum CodingKeys: String, CodingKey {
        case totalRealizedPnl = "total_realized_pnl"
        case tradeCount = "trade_count"
        case winRatePct = "win_rate_pct"
    }
}

struct AlertRecord: Decodable, Identifiable {
    let id: String
    let timestamp: Date?
    let severity: String
    let message: String
    let source: String
    let dismissed: Bool
}

struct ExecutionSnapshot: Decodable {
    let avgSlippageBps: Double?
    let avgLatencyMs: Double?
    let fillRatePct: Double?
    let rejectionRatePct: Double?
    let totalFills: Int?
    let totalRejections: Int?

    enum CodingKeys: String, CodingKey {
        case avgSlippageBps = "avg_slippage_bps"
        case avgLatencyMs = "avg_latency_ms"
        case fillRatePct = "fill_rate_pct"
        case rejectionRatePct = "rejection_rate_pct"
        case totalFills = "total_fills"
        case totalRejections = "total_rejections"
    }
}

struct InfrastructureSnapshot: Decodable {
    let tasks: [TaskStatus]?
}

struct TaskStatus: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let status: String
    let lastRun: String?

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case lastRun = "last_run"
    }
}

struct StatusResponse: Decodable {
    let engineState: String
    let timestamp: Date?
    let numWsClients: Int?

    enum CodingKeys: String, CodingKey {
        case engineState = "engine_state"
        case timestamp
        case numWsClients = "num_ws_clients"
    }
}

struct UniverseSnapshot: Decodable {
    let strategies: [String: UniverseStrategy]
    let lastScan: Date?

    enum CodingKeys: String, CodingKey {
        case strategies
        case lastScan = "last_scan"
    }
}

struct UniverseStrategy: Decodable {
    let tier1: [String]
    let tier2: [String]?
}

struct StrategyDetail: Decodable {
    let name: String
    let state: String
    let universe: [String]?
    let intraday: Bool?
    let dynamicUniverse: Bool?
    let signalCount: Int?
    let openPositions: Int?
    let dailyPnl: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case state
        case universe
        case intraday
        case dynamicUniverse = "dynamic_universe"
        case signalCount = "signal_count"
        case openPositions = "open_positions"
        case dailyPnl = "daily_pnl"
    }
}

enum DashboardMessage {
    case snapshot(DashboardSnapshot)
    case correlationAlert(CorrelationAlertMessage)
}
