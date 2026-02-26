import Foundation
import Testing
@testable import Satori

struct DashboardContractAdapterTests {
    @Test
    func decodesSnapshotMessage() throws {
        let json = """
        {
          "timestamp": "2026-02-26T18:10:00Z",
          "engine_state": "ACTIVE",
          "portfolio": {
            "equity": 100000.0,
            "num_positions": 2,
            "unrealized_pnl": 120.5,
            "positions": []
          },
          "risk_metrics": {
            "drawdown_pct": 1.2,
            "daily_pnl_pct": 0.4,
            "kill_switch_active": false,
            "vix": 18.2
          }
        }
        """
        let message = try DashboardContractAdapter.decodeMessage(from: Data(json.utf8))
        switch message {
        case .snapshot(let snapshot):
            #expect(snapshot.engineState == "ACTIVE")
            #expect(snapshot.portfolio?.numPositions == 2)
        case .correlationAlert:
            Issue.record("Expected snapshot")
        }
    }

    @Test
    func decodesCorrelationAlertMessage() throws {
        let json = """
        {
          "type": "correlation_alert",
          "threshold": 0.7,
          "alerts": [
            {"strategy_a":"lightning","strategy_b":"surge","correlation":0.82}
          ]
        }
        """
        let message = try DashboardContractAdapter.decodeMessage(from: Data(json.utf8))
        switch message {
        case .snapshot:
            Issue.record("Expected correlation alert")
        case .correlationAlert(let payload):
            #expect(payload.alerts.count == 1)
            #expect(payload.alerts[0].strategyA == "lightning")
        }
    }

    @Test
    func decodesNaiveISODateWithoutTimezone() throws {
        let json = """
        {
          "timestamp": "2026-02-25T23:22:50.460757",
          "engine_state": "INIT"
        }
        """
        let message = try DashboardContractAdapter.decodeMessage(from: Data(json.utf8))
        switch message {
        case .snapshot(let snapshot):
            #expect(snapshot.timestamp != nil)
        case .correlationAlert:
            Issue.record("Expected snapshot")
        }
    }
}
