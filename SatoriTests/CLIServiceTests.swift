import Foundation
import Testing
@testable import Satori

struct CLIServiceTests {
    @Test
    func runStreamsOutputAndExitCode() async throws {
        let service = CLIService()
        let request = CLIRequest(
            executablePath: "/bin/echo",
            arguments: ["hello-cockpit"],
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )

        var receivedText = ""
        var exit: Int32 = -1

        for try await event in service.run(request) {
            switch event {
            case .stdout(let text):
                receivedText += text
            case .stderr:
                break
            case .didExit(let code):
                exit = code
            }
        }

        #expect(receivedText.contains("hello-cockpit"))
        #expect(exit == 0)
    }

    @Test
    func runCapturesStderr() async throws {
        let service = CLIService()
        let request = CLIRequest(
            executablePath: "/bin/sh",
            arguments: ["-c", "echo warning >&2"],
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )

        var stderrText = ""

        for try await event in service.run(request) {
            if case let .stderr(text) = event {
                stderrText += text
            }
        }

        #expect(stderrText.contains("warning"))
    }
}
