import Foundation
import Supabase

enum ChatServiceError: LocalizedError {
    case invalidURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "后台地址无效"
        case .server(let message):
            return message
        }
    }
}

final class ChatService {
    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private let session: URLSession
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        guard let url = URL(string: AppConfig.backendBaseURL) else {
            fatalError("BACKEND_BASE_URL 未配置")
        }
        baseURL = url
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func chats(for userID: UUID) async throws -> [ChatSummary] {
        let rows: [ChatSummaryRow] = try await client
            .from(ChatSummaryRow.table)
            .select()
            .contains("participant_ids", value: [userID])
            .order("last_message_at", ascending: false)
            .execute()
            .value

        return rows.map { $0.toDomain() }
    }

    func messages(for chatID: UUID, currentUserID: UUID) async throws -> [Message] {
        let url = baseURL.appendingPathComponent("/social/chats/\(chatID.uuidString)/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let data = try await perform(request)
        let response = try decoder.decode(MessagesResponse.self, from: data)
        return response.messages.map { $0.toDomain(currentUserID: currentUserID) }
    }

    func sendMessage(_ content: String, chatID: UUID, senderID: UUID) async throws {
        let url = baseURL.appendingPathComponent("/social/chats/\(chatID.uuidString)/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = SendMessageRequest(sender_id: senderID.uuidString, content: content)
        request.httpBody = try encoder.encode(payload)

        _ = try await perform(request)
    }

    func createChat(with friend: UserProfile, currentUser: UserProfile) async throws -> ChatSummary {
        let url = baseURL.appendingPathComponent("/social/chats")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ChatCreateRequest(initiator_id: currentUser.id.uuidString, participant_id: friend.id.uuidString)
        request.httpBody = try encoder.encode(payload)

        let data = try await perform(request)
        let response = try decoder.decode(ChatCreateResponse.self, from: data)
        return response.chat.toDomain()
    }

    func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
        let channel = realtimeChannel
        realtimeChannel = nil
        Task { await channel?.unsubscribe() }
    }

    func preferredName(for userID: UUID) async throws -> String? {
        let rows: [ProfileRecord] = try await client
            .from(ProfileRecord.table)
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value

        guard let record = rows.first else { return nil }
        return record.toDomain().preferredDisplayName
    }
}

fileprivate struct ChatSummaryRow: Decodable {
    static let table = "chat_summaries"
    let id: UUID
    let title: String
    let last_message_preview: String?
    let last_message_at: Date?
    let unread_count: Int?
    let participant_ids: [UUID]

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case last_message_preview
        case last_message_at
        case unread_count
        case participant_ids
    }

    fileprivate init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        last_message_preview = try container.decodeIfPresent(String.self, forKey: .last_message_preview)
        last_message_at = try container.decodeIfPresent(Date.self, forKey: .last_message_at)
        unread_count = try container.decodeIfPresent(Int.self, forKey: .unread_count)
        participant_ids = try container.decode([UUID].self, forKey: .participant_ids)
    }

    func toDomain() -> ChatSummary {
        ChatSummary(
            id: id,
            title: title,
            lastMessagePreview: last_message_preview ?? "",
            lastMessageAt: last_message_at ?? .distantPast,
            unreadCount: unread_count ?? 0,
            participantIDs: participant_ids
        )
    }
}

private struct ChatCreateRequest: Encodable {
    let initiator_id: String
    let participant_id: String
}

private struct ChatCreateResponse: Decodable {
    let chat: ChatSummaryRow
}

private struct SendMessageRequest: Encodable {
    let sender_id: String
    let content: String
}

private struct APIErrorResponse: Decodable {
    let detail: String
}

private struct MessagesResponse: Decodable {
    let messages: [MessageDTO]
}

private struct MessageDTO: Decodable {
    let id: String
    let chat_id: String
    let sender_id: String
    let sender_name: String?
    let content: String
    let created_at: Date

    func toDomain(currentUserID: UUID) -> Message {
        Message(
            id: UUID(uuidString: id) ?? UUID(),
            chatID: UUID(uuidString: chat_id) ?? UUID(),
            senderID: UUID(uuidString: sender_id) ?? UUID(),
            senderName: sender_name ?? "",
            content: content,
            createdAt: created_at,
            currentUserID: currentUserID
        )
    }
}

private extension ChatService {
    func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.server("无效的服务器响应")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw ChatServiceError.server(apiError.detail)
            }
            throw ChatServiceError.server("服务器错误：\(httpResponse.statusCode)")
        }
        return data
    }
}

struct MessageRecord: Codable {
    static let table = "messages"
    let id: UUID
    let chat_id: UUID
    let sender_id: UUID
    let sender_name: String?
    let content: String
    let created_at: Date

    func toDomain(currentUserID: UUID) -> Message {
        Message(
            id: id,
            chatID: chat_id,
            senderID: sender_id,
            senderName: sender_name ?? "",
            content: content,
            createdAt: created_at,
            currentUserID: currentUserID
        )
    }
}
