import Foundation
import Testing
@testable import Satori

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

struct RESTClientTests {
    @Test
    func fetchRiskParsesPayload() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"drawdown_pct":1.0,"daily_pnl_pct":0.5,"kill_switch_active":false,"vix":18.0}
            """.data(using: .utf8)!
            return (response, body)
        }

        let client = RESTClient(session: session)
        let risk = try await client.fetchRisk(baseURL: URL(string: "http://localhost:8780")!)

        #expect(risk.vix == 18.0)
        #expect(risk.killSwitchActive == false)
    }

    @Test
    func fetchTradesEncodesQueryParameters() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        var capturedURL: URL?

        MockURLProtocol.handler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let client = RESTClient(session: session)
        _ = try await client.fetchTrades(
            baseURL: URL(string: "http://localhost:8780")!,
            limit: 25,
            symbol: "BRK.B",
            strategy: "mean rev",
            date: "2026-02-26"
        )

        let components = URLComponents(url: try #require(capturedURL), resolvingAgainstBaseURL: false)
        let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(components?.path == "/api/trades")
        #expect(query["limit"] == "25")
        #expect(query["symbol"] == "BRK.B")
        #expect(query["strategy"] == "mean rev")
        #expect(query["date"] == "2026-02-26")
    }

    @Test
    func fetchStatusMapsNon2xxToRESTClientError() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"error\":\"missing\"}".utf8)
            return (response, body)
        }

        let client = RESTClient(session: session)

        do {
            _ = try await client.fetchStatus(baseURL: URL(string: "http://localhost:8780")!)
            Issue.record("Expected non-2xx response to throw")
        } catch let error as RESTClientError {
            if case let .badServerResponse(statusCode, url, bodySnippet) = error {
                #expect(statusCode == 404)
                #expect(url.absoluteString.contains("/api/status"))
                #expect(bodySnippet.contains("missing"))
            } else {
                Issue.record("Expected badServerResponse for 404")
            }
        }
    }
}
