import Foundation
import Testing
@testable import Satori

struct SatoriTests {
    @Test
    func defaultsHaveExpectedPaths() {
        let defaults = AppSettings.default
        #expect(defaults.cliPath.contains("satori"))
        #expect(!defaults.engineRootPath.isEmpty)
        #expect(defaults.runsRootPath.hasSuffix("/runs"))
        #expect(defaults.baseAPIURL?.absoluteString == "http://localhost:8780")
        #expect(defaults.wsURL?.absoluteString == "ws://localhost:8780/ws")
    }

    @Test
    func remoteServerURLsResolveFromSettings() {
        let settings = AppSettings(
            apiScheme: .https,
            wsScheme: .wss,
            host: "dashboard.example.com",
            port: 443,
            apiBasePath: "/api-gateway",
            wsPath: "/ws",
            cliPath: "/tmp/satori",
            engineRootPath: "/tmp",
            runsRootPath: "/tmp/runs",
            reconnectBaseSeconds: 1,
            reconnectMaxSeconds: 8
        )

        #expect(
            settings.baseAPIURL?.absoluteString == "https://dashboard.example.com/api-gateway"
                || settings.baseAPIURL?.absoluteString == "https://dashboard.example.com:443/api-gateway"
        )
        #expect(
            settings.wsURL?.absoluteString == "wss://dashboard.example.com/ws"
                || settings.wsURL?.absoluteString == "wss://dashboard.example.com:443/ws"
        )
    }

    @Test
    func hostFieldAcceptsFullRemoteURLInput() {
        let settings = AppSettings(
            apiScheme: .https,
            wsScheme: .wss,
            host: "https://remote.satori.dev:9443",
            port: 8780,
            apiBasePath: "/api",
            wsPath: "/ws",
            cliPath: "/tmp/satori",
            engineRootPath: "/tmp",
            runsRootPath: "/tmp/runs",
            reconnectBaseSeconds: 1,
            reconnectMaxSeconds: 8
        )

        #expect(settings.baseAPIURL?.absoluteString == "https://remote.satori.dev:9443/api")
        #expect(settings.wsURL?.absoluteString == "wss://remote.satori.dev:9443/ws")
    }
}
