import Foundation

enum RESTClientError: LocalizedError {
    case badURL
    case cancelled
    case badServerResponse(statusCode: Int, url: URL, bodySnippet: String)
    case decoding(url: URL, underlying: Error, bodySnippet: String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            "Bad URL"
        case .cancelled:
            "Request cancelled"
        case .badServerResponse(let statusCode, let url, let bodySnippet):
            "HTTP \(statusCode) at \(url.absoluteString). \(bodySnippet)"
        case .decoding(let url, let underlying, let bodySnippet):
            "Decode failed at \(url.absoluteString): \(underlying.localizedDescription). \(bodySnippet)"
        }
    }
}

actor RESTClient: RESTClientProtocol {
    private let session: URLSession
    private let maxRetries: Int
    private let backoffBase: TimeInterval
    private let timeoutInterval: TimeInterval

    init(
        session: URLSession = .shared,
        maxRetries: Int = 2,
        backoffBase: TimeInterval = 1.0,
        timeoutInterval: TimeInterval = 10.0
    ) {
        self.session = session
        self.maxRetries = max(0, maxRetries)
        self.backoffBase = max(0.1, backoffBase)
        self.timeoutInterval = max(1.0, timeoutInterval)
    }

    func fetchStatus(baseURL: URL) async throws -> StatusResponse {
        try await get(baseURL: baseURL, path: "/api/status")
    }

    func fetchPositions(baseURL: URL) async throws -> [PositionRecord] {
        try await get(baseURL: baseURL, path: "/api/positions")
    }

    func fetchTrades(baseURL: URL, limit: Int?, symbol: String?, strategy: String?, date: String?) async throws -> [TradeRecord] {
        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let symbol, !symbol.isEmpty { query.append(URLQueryItem(name: "symbol", value: symbol)) }
        if let strategy, !strategy.isEmpty { query.append(URLQueryItem(name: "strategy", value: strategy)) }
        if let date, !date.isEmpty { query.append(URLQueryItem(name: "date", value: date)) }
        return try await get(baseURL: baseURL, path: "/api/trades", query: query)
    }

    func fetchRisk(baseURL: URL) async throws -> RiskMetrics {
        try await get(baseURL: baseURL, path: "/api/risk")
    }

    func fetchPdt(baseURL: URL) async throws -> PdtStatus {
        try await get(baseURL: baseURL, path: "/api/risk/pdt")
    }

    func fetchStrategies(baseURL: URL) async throws -> [StrategySummary] {
        try await get(baseURL: baseURL, path: "/api/strategies")
    }

    func fetchStrategiesDetail(baseURL: URL) async throws -> [String: StrategyDetail] {
        try await get(baseURL: baseURL, path: "/api/strategies/detail")
    }

    func fetchUniverse(baseURL: URL) async throws -> UniverseSnapshot {
        try await get(baseURL: baseURL, path: "/api/universe")
    }

    private func get<T: Decodable>(baseURL: URL, path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else {
            throw RESTClientError.badURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval

        var attempt = 0
        while true {
            do {
                try Task.checkCancellation()
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw RESTClientError.badServerResponse(
                        statusCode: -1,
                        url: url,
                        bodySnippet: "Non-HTTP response"
                    )
                }

                if (500...599).contains(http.statusCode), attempt < maxRetries {
                    attempt += 1
                    try await backoffSleep(for: attempt)
                    continue
                }

                guard (200...299).contains(http.statusCode) else {
                    throw RESTClientError.badServerResponse(
                        statusCode: http.statusCode,
                        url: url,
                        bodySnippet: bodyPreview(from: data)
                    )
                }

                do {
                    return try JSONCoder.dashboardDecoder.decode(T.self, from: data)
                } catch {
                    if let sanitized = sanitizeNonFiniteNumbers(in: data),
                       let decoded = try? JSONCoder.dashboardDecoder.decode(T.self, from: sanitized) {
                        return decoded
                    }
                    throw RESTClientError.decoding(
                        url: url,
                        underlying: error,
                        bodySnippet: bodyPreview(from: data)
                    )
                }
            } catch is CancellationError {
                throw RESTClientError.cancelled
            } catch let error as URLError {
                if shouldRetry(error: error), attempt < maxRetries {
                    attempt += 1
                    try await backoffSleep(for: attempt)
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }
    }

    private func backoffSleep(for attempt: Int) async throws {
        let delaySeconds = backoffBase * pow(2, Double(max(0, attempt - 1)))
        let nanos = UInt64(delaySeconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanos)
    }

    private func shouldRetry(error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .resourceUnavailable,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }

    private func bodyPreview(from data: Data, maxLength: Int = 220) -> String {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            return "Body: <non-utf8 or empty>"
        }
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if flattened.count <= maxLength {
            return "Body: \(flattened)"
        }
        return "Body: \(flattened.prefix(maxLength))..."
    }

    private func sanitizeNonFiniteNumbers(in data: Data) -> Data? {
        guard var text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let patterns = [
            (#"([:\[, ]\s*)-Infinity(\s*[,}\]])"#, "$1null$2"),
            (#"([:\[, ]\s*)Infinity(\s*[,}\]])"#, "$1null$2"),
            (#"([:\[, ]\s*)NaN(\s*[,}\]])"#, "$1null$2"),
        ]

        for (pattern, replacement) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(location: 0, length: text.utf16.count)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
        }

        return text.data(using: .utf8)
    }
}
