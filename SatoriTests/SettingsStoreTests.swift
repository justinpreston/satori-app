import Foundation
import Testing
@testable import Satori

struct SettingsStoreTests {
    @Test
    func loadReturnsDefaultsWhenNoSavedData() async {
        let suite = "satori.tests.settings.empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)

        let loaded = await store.load()
        #expect(loaded.host == AppSettings.default.host)
        #expect(loaded.port == AppSettings.default.port)
    }

    @Test
    func saveAndLoadRoundTrip() async throws {
        let suite = "satori.tests.settings.roundtrip.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)

        let expected = AppSettings(
            apiScheme: .https,
            wsScheme: .wss,
            host: "dashboard.example.com",
            port: 9443,
            apiBasePath: "/api",
            wsPath: "/ws",
            cliPath: "/tmp/satori",
            engineRootPath: "/tmp/engine",
            runsRootPath: "/tmp/runs",
            reconnectBaseSeconds: 1.2,
            reconnectMaxSeconds: 9.0
        )

        try await store.save(expected)
        let loaded = await store.load()
        #expect(loaded == expected)
    }

    @Test
    func loadFallsBackWhenStoredPayloadIsCorrupted() async {
        let suite = "satori.tests.settings.corrupt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(Data("{invalid json".utf8), forKey: "cockpit.settings.v1")

        let store = SettingsStore(defaults: defaults)
        let loaded = await store.load()
        #expect(loaded == AppSettings.default)
    }
}
