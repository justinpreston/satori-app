import Foundation

struct CLIRequest {
    let executablePath: String
    let arguments: [String]
    let workingDirectory: URL
    let environment: [String: String]
    let timeoutSeconds: TimeInterval

    init(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL,
        environment: [String: String] = [:],
        timeoutSeconds: TimeInterval = 300
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.timeoutSeconds = timeoutSeconds
    }
}

enum CLIOutputEvent {
    case stdout(String)
    case stderr(String)
    case timeout(elapsed: TimeInterval)
    case didExit(Int32)
}

struct MonitorLaunchRequest {
    let executablePath: String
    let wsURL: URL
    let workingDirectory: URL
}

struct BacktestLaunchInput {
    var strategy: String = "surge"
    var startDate: String = "2025-01-02"
    var endDate: String = "2025-12-31"
    var configPath: String = "configs/paper.toml"
}

struct ValidateLaunchInput {
    var resultPath: String = ""
    var folds: Int = 3
    var permutations: Int = 1000
}

struct PromoteLaunchInput {
    var strategy: String = "surge"
    var returnsCSV: String = ""
    var equityCSV: String = ""
    var configPath: String = "configs/paper.toml"
    var override: Bool = false
}
