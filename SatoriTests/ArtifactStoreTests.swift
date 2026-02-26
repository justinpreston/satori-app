import Foundation
import Testing
@testable import Satori

struct ArtifactStoreTests {
    @Test
    func indexesRunsAndLoadsArtifacts() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let runDir = root
            .appendingPathComponent("2026-02-26")
            .appendingPathComponent("surge")
            .appendingPathComponent("run_001")

        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

        let metrics = "{\"sharpe\":1.5,\"max_drawdown\":-0.1,\"walk_forward_ratio\":0.85}"
        let metadata = "{\"timestamp\":\"2026-02-26T10:00:00Z\",\"run_type\":\"backtest\",\"verdict\":\"GO\"}"
        let csv = "timestamp,equity\n2026-02-26T10:00:00Z,100000\n"

        try metrics.write(to: runDir.appendingPathComponent("metrics.json"), atomically: true, encoding: .utf8)
        try metadata.write(to: runDir.appendingPathComponent("run_metadata.json"), atomically: true, encoding: .utf8)
        try csv.write(to: runDir.appendingPathComponent("trades.csv"), atomically: true, encoding: .utf8)

        let store = ArtifactStore()
        let runs = try await store.indexRuns(root: root)

        #expect(runs.count == 1)
        #expect(runs[0].strategyName == "surge")
        #expect(runs[0].verdict == .go)

        let content = try await store.loadArtifact(run: runs[0], fileKind: .tradesCSV)
        switch content {
        case .csv(let rows):
            #expect(rows.count == 2)
        default:
            Issue.record("Expected CSV content")
        }
    }
}
