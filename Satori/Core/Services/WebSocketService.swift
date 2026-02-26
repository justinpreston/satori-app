import Combine
import Foundation

enum WebSocketDecodeError: LocalizedError {
    case malformedPayload(consecutiveCount: Int, snippet: String)
    case contractMismatch(consecutiveCount: Int, snippet: String)

    var errorDescription: String? {
        switch self {
        case .malformedPayload(let consecutiveCount, let snippet):
            "Malformed websocket payload (\(consecutiveCount) consecutive). \(snippet)"
        case .contractMismatch(let consecutiveCount, let snippet):
            "Dashboard contract mismatch (\(consecutiveCount) consecutive decode failures). \(snippet)"
        }
    }
}

final class WebSocketService: WebSocketServiceProtocol {
    private let statusSubject = CurrentValueSubject<WebSocketConnectionStatus, Never>(.disconnected)
    private let snapshotSubject = PassthroughSubject<DashboardSnapshot, Never>()
    private let correlationAlertSubject = PassthroughSubject<CorrelationAlertMessage, Never>()
    private let lastMessageAtSubject = CurrentValueSubject<Date?, Never>(nil)
    private let latencySubject = CurrentValueSubject<Double, Never>(0)
    private let decodeErrorSubject = PassthroughSubject<Error, Never>()

    private var reconnectBaseSeconds: Double = 1
    private var reconnectMaxSeconds: Double = 8
    private var reconnectAttempt: Int = 0
    private var consecutiveDecodeErrors = 0
    private let decodeFailureThreshold = 5

    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var currentURL: URL?
    private var shouldReconnect = false

    var statusPublisher: AnyPublisher<WebSocketConnectionStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    var snapshotPublisher: AnyPublisher<DashboardSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    var correlationAlertPublisher: AnyPublisher<CorrelationAlertMessage, Never> {
        correlationAlertSubject.eraseToAnyPublisher()
    }

    var lastMessageAtPublisher: AnyPublisher<Date?, Never> {
        lastMessageAtSubject.eraseToAnyPublisher()
    }

    var latencyPublisher: AnyPublisher<Double, Never> {
        latencySubject.eraseToAnyPublisher()
    }

    var decodeErrorPublisher: AnyPublisher<Error, Never> {
        decodeErrorSubject.eraseToAnyPublisher()
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func configure(baseReconnectSeconds: Double, maxReconnectSeconds: Double) {
        reconnectBaseSeconds = max(0.2, baseReconnectSeconds)
        reconnectMaxSeconds = max(reconnectBaseSeconds, maxReconnectSeconds)
    }

    func connect(url: URL) {
        disconnect()
        currentURL = url
        shouldReconnect = true
        reconnectAttempt = 0
        open(url: url, reconnecting: false)
    }

    func disconnect() {
        shouldReconnect = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        statusSubject.send(.disconnected)
    }

    private func open(url: URL, reconnecting: Bool) {
        statusSubject.send(reconnecting ? .reconnecting : .connecting)
        let wsTask = session.webSocketTask(with: url)
        task = wsTask
        wsTask.resume()
        statusSubject.send(.connected)
        receiveLoop(task: wsTask)
        pingLoop(task: wsTask)
    }

    private func receiveLoop(task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleText(text)
                case .data(let data):
                    self.handleData(data)
                @unknown default:
                    break
                }
                self.receiveLoop(task: task)
            case .failure:
                self.handleDisconnect()
            }
        }
    }

    private func pingLoop(task: URLSessionWebSocketTask) {
        task.sendPing { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.handleDisconnect()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self else { return }
                if self.task === task {
                    self.pingLoop(task: task)
                }
            }
        }
    }

    private func handleText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        handleData(data)
    }

    private func handleData(_ data: Data) {
        do {
            switch try DashboardContractAdapter.decodeMessage(from: data) {
            case .snapshot(let snapshot):
                consecutiveDecodeErrors = 0
                snapshotSubject.send(snapshot)
                let now = Date()
                lastMessageAtSubject.send(now)
                if let serverTimestamp = snapshot.timestamp {
                    latencySubject.send(max(0, now.timeIntervalSince(serverTimestamp) * 1000))
                }
            case .correlationAlert(let alert):
                consecutiveDecodeErrors = 0
                correlationAlertSubject.send(alert)
            }
        } catch {
            consecutiveDecodeErrors += 1
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? "<non-utf8 payload>"
            decodeErrorSubject.send(
                WebSocketDecodeError.malformedPayload(
                    consecutiveCount: consecutiveDecodeErrors,
                    snippet: snippet
                )
            )
            if consecutiveDecodeErrors >= decodeFailureThreshold {
                decodeErrorSubject.send(
                    WebSocketDecodeError.contractMismatch(
                        consecutiveCount: consecutiveDecodeErrors,
                        snippet: snippet
                    )
                )
            }
        }
    }

    private func handleDisconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        guard shouldReconnect, let url = currentURL else {
            statusSubject.send(.disconnected)
            return
        }
        statusSubject.send(.reconnecting)
        let delay = min(reconnectBaseSeconds * pow(2, Double(reconnectAttempt)), reconnectMaxSeconds)
        reconnectAttempt += 1
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.open(url: url, reconnecting: true)
        }
    }
}
