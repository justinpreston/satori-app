import Foundation

enum DashboardContractAdapter {
    static func decodeMessage(from data: Data, decoder: JSONDecoder = JSONCoder.dashboardDecoder) throws -> DashboardMessage {
        if let type = try? peekType(from: data), type == "correlation_alert" {
            return .correlationAlert(try decoder.decode(CorrelationAlertMessage.self, from: data))
        }
        return .snapshot(try decoder.decode(DashboardSnapshot.self, from: data))
    }

    private static func peekType(from data: Data) throws -> String? {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["type"] as? String
    }
}

enum JSONCoder {
    static let dashboardDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { rawDecoder in
            let container = try rawDecoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.withFractional.date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter.basic.date(from: value) {
                return date
            }
            if let date = DateFormatter.noTimezoneWithFractional.date(from: value) {
                return date
            }
            if let date = DateFormatter.noTimezoneBasic.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date: \(value)")
        }
        return decoder
    }()
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension DateFormatter {
    static let noTimezoneWithFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    static let noTimezoneBasic: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
