import Foundation

struct BackendNotifier {
    enum Endpoint {
        case offlineMessage

        var path: String {
            switch self {
            case .offlineMessage:
                return "/notify/offline-message"
            }
        }
    }

    func sendOfflineNotification(chatID: UUID, recipientIDs: [UUID], messagePreview: String) async {
        let payload = OfflineNotificationPayload(chat_id: chatID, recipient_ids: recipientIDs, preview: messagePreview)
        guard let url = URL(string: AppConfig.backendBaseURL + Endpoint.offlineMessage.path) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("Failed to notify backend: \(error)")
            #endif
        }
    }
}

private struct OfflineNotificationPayload: Codable {
    let chat_id: UUID
    let recipient_ids: [UUID]
    let preview: String
}
