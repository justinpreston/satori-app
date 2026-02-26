import Foundation

actor ArtifactStore: ArtifactStoreProtocol {
    private var indexedRuns: [RunArtifactSummary] = []

    func indexRuns(root: URL) async throws -> [RunArtifactSummary] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: root.path) else {
            indexedRuns = []
            return []
        }

        var runs: [RunArtifactSummary] = []
        let dayDirectories = try manager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for dayURL in dayDirectories {
            guard try dayURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { continue }
            let strategyDirectories = try manager.contentsOfDirectory(
                at: dayURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for strategyURL in strategyDirectories {
                guard try strategyURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { continue }
                let runDirectories = try manager.contentsOfDirectory(
                    at: strategyURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                for runDirectory in runDirectories {
                    guard try runDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { continue }
                    if let summary = try parseRun(directory: runDirectory, strategyName: strategyURL.lastPathComponent) {
                        runs.append(summary)
                    }
                }
            }
        }

        runs.sort { $0.timestamp > $1.timestamp }
        indexedRuns = runs
        return runs
    }

    func listRuns(filter: ArtifactFilter) async -> [RunArtifactSummary] {
        indexedRuns.filter { run in
            let strategyMatch = filter.strategy.isEmpty || run.strategyName.localizedCaseInsensitiveContains(filter.strategy)
            let typeMatch = filter.runType == nil || run.runType == filter.runType
            return strategyMatch && typeMatch
        }
    }

    func loadArtifact(run: RunArtifactSummary, fileKind: ArtifactFileKind) async throws -> ArtifactContent {
        let fileURL = run.directory.appendingPathComponent(fileKind.rawValue)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "ArtifactStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Artifact missing: \(fileKind.rawValue)"])
        }

        switch fileKind {
        case .metricsJSON, .runMetadataJSON, .vetoSummaryJSON:
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            return .json(text)
        case .tradesCSV:
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let rows = text.split(separator: "\n").map(String.init)
            return .csv(rows)
        case .equityPNG:
            return .image(fileURL)
        }
    }

    func diffMetrics(run: RunArtifactSummary, baseline: RunArtifactSummary) async throws -> [MetricDiff] {
        let runMetrics = try await readMetrics(for: run)
        let baselineMetrics = try await readMetrics(for: baseline)

        var diffs: [MetricDiff] = []
        for (key, candidate) in runMetrics {
            guard let base = baselineMetrics[key] else { continue }
            diffs.append(MetricDiff(metric: key, baselineValue: base, candidateValue: candidate, delta: candidate - base))
        }
        return diffs.sorted { $0.metric < $1.metric }
    }

    private func parseRun(directory: URL, strategyName: String) throws -> RunArtifactSummary? {
        let metadataURL = directory.appendingPathComponent(ArtifactFileKind.runMetadataJSON.rawValue)
        let metricsURL = directory.appendingPathComponent(ArtifactFileKind.metricsJSON.rawValue)

        let metrics = try readNumericJSON(url: metricsURL)
        let metadata = try readAnyJSON(url: metadataURL)

        let timestamp = parseTimestamp(directoryName: directory.lastPathComponent, metadata: metadata)
        let type = parseRunType(metadata: metadata)

        return RunArtifactSummary(
            id: directory.path,
            runType: type,
            strategyName: strategyName,
            timestamp: timestamp,
            directory: directory,
            sharpe: numericValue(metrics, keys: ["sharpe", "sharpe_ratio"]),
            maxDrawdown: numericValue(metrics, keys: ["max_drawdown", "maxDrawdown"]),
            walkForwardRatio: numericValue(metrics, keys: ["walk_forward_ratio", "walkForwardRatio"]),
            monteCarloPValue: numericValue(metrics, keys: ["monte_carlo_p_value", "monteCarloPValue"]),
            slippageSensitivity: numericValue(metrics, keys: ["slippage_sensitivity", "slippageSensitivity"]),
            verdict: parseVerdict(metadata: metadata)
        )
    }

    private func readMetrics(for run: RunArtifactSummary) async throws -> [String: Double] {
        let url = run.directory.appendingPathComponent(ArtifactFileKind.metricsJSON.rawValue)
        return try readNumericJSON(url: url)
    }

    private func parseTimestamp(directoryName: String, metadata: [String: Any]) -> Date {
        if let value = metadata["timestamp"] as? String,
           let date = ISO8601DateFormatter.withFractional.date(from: value) ?? ISO8601DateFormatter.basic.date(from: value) {
            return date
        }
        if let value = metadata["created_at"] as? String,
           let date = ISO8601DateFormatter.withFractional.date(from: value) ?? ISO8601DateFormatter.basic.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        if let date = formatter.date(from: directoryName.filter { $0.isNumber }) {
            return date
        }
        return .distantPast
    }

    private func parseRunType(metadata: [String: Any]) -> RunType {
        if let value = metadata["run_type"] as? String {
            return RunType(rawValue: value.lowercased()) ?? .backtest
        }
        return .backtest
    }

    private func parseVerdict(metadata: [String: Any]) -> RunVerdict {
        if let value = metadata["verdict"] as? String {
            return RunVerdict(rawValue: value.uppercased()) ?? .unknown
        }
        return .unknown
    }

    private func readNumericJSON(url: URL) throws -> [String: Double] {
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var output: [String: Double] = [:]
        for (key, value) in object {
            if let number = value as? NSNumber {
                output[key] = number.doubleValue
            }
        }
        return output
    }

    private func readAnyJSON(url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private func numericValue(_ map: [String: Double], keys: [String]) -> Double? {
        for key in keys {
            if let value = map[key] {
                return value
            }
        }
        return nil
    }
}
