import Combine
import Foundation

final class MessageRealtimeService {
    static let shared = MessageRealtimeService()

    private let decoder: JSONDecoder
    private var currentUserID: UUID?
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var reconnectTask: Task<Void, Never>?

    let messagePublisher = PassthroughSubject<MessageRecord, Never>()

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func start(for userID: UUID) {
        if currentUserID == userID, webSocketTask != nil {
            return
        }
        stop()
        currentUserID = userID
        connectWebSocket()
    }

    func stop() {
        currentUserID = nil
        #if DEBUG
        print("[Realtime] stop")
        #endif
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel()
        webSocketTask = nil
    }

    func updateChatIDs(_ ids: Set<UUID>) {}

    private func connectWebSocket() {
        guard let url = websocketURL() else { return }
        #if DEBUG
        print("[Realtime] connect", url.absoluteString)
        #endif
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        listen()
        startPing()
    }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                self.scheduleReconnect()
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.decodeMessage(data)
                    }
                case .data(let data):
                    self.decodeMessage(data)
                @unknown default:
                    break
                }
                self.listen()
            }
        }
    }

    private func decodeMessage(_ data: Data) {
        do {
            let record = try decoder.decode(MessageRecord.self, from: data)
            messagePublisher.send(record)
        } catch {
            #if DEBUG
            print("Realtime decode failed: \(error)")
            #endif
        }
    }

    private func startPing() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                webSocketTask?.sendPing { _ in }
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            guard let self, let userID = self.currentUserID else { return }
            self.webSocketTask?.cancel()
            self.webSocketTask = nil
            self.start(for: userID)
        }
    }

    private func websocketURL() -> URL? {
        guard let userID = currentUserID,
              var components = URLComponents(string: AppConfig.backendBaseURL) else {
            return nil
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/ws/messages"
        components.queryItems = [URLQueryItem(name: "user_id", value: userID.uuidString)]
        return components.url
    }
}
