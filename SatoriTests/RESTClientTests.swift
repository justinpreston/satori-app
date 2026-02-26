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
}
