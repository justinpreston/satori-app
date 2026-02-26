import Foundation

final class CLIService: CLIServiceProtocol {
    func run(_ request: CLIRequest) -> AsyncThrowingStream<CLIOutputEvent, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: request.executablePath)
            process.arguments = request.arguments
            process.currentDirectoryURL = request.workingDirectory

            var env = ProcessInfo.processInfo.environment
            request.environment.forEach { env[$0.key] = $0.value }
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                continuation.yield(.stdout(text))
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                continuation.yield(.stderr(text))
            }

            let stateQueue = DispatchQueue(label: "CLIService.state")
            var didTimeout = false

            process.terminationHandler = { terminated in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let code = stateQueue.sync { didTimeout ? Int32(-1) : terminated.terminationStatus }
                continuation.yield(.didExit(code))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
                if request.timeoutSeconds > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + request.timeoutSeconds) {
                        let shouldTerminate = stateQueue.sync { () -> Bool in
                            guard process.isRunning else { return false }
                            didTimeout = true
                            return true
                        }
                        guard shouldTerminate else { return }
                        continuation.yield(.timeout(elapsed: request.timeoutSeconds))
                        process.terminate()
                    }
                }
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    func launchMonitor(_ request: MonitorLaunchRequest) throws {
        let command = "cd \"\(request.workingDirectory.path)\"; \"\(request.executablePath)\" monitor --url \"\(request.wsURL.absoluteString)\""
        let script = "tell application \"Terminal\" to do script \"\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try process.run()
    }
}
