import Foundation

public struct UserProfile: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var displayName: String
    public var email: String?
    public var phone: String?
    public var avatarURL: URL?
    public var about: String?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case phone
        case avatarURL = "avatar_url"
        case about
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: UUID,
        displayName: String,
        email: String? = nil,
        phone: String? = nil,
        avatarURL: URL? = nil,
        about: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.phone = phone
        self.avatarURL = avatarURL
        self.about = about
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        if let urlString = try container.decodeIfPresent(String.self, forKey: .avatarURL),
           let url = URL(string: urlString), !urlString.isEmpty {
            avatarURL = url
        } else {
            avatarURL = nil
        }
        about = try container.decodeIfPresent(String.self, forKey: .about)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(avatarURL?.absoluteString, forKey: .avatarURL)
        try container.encodeIfPresent(about, forKey: .about)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

public struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let senderID: UUID
    public var sender: UserProfile?
    public var content: String
    public var createdAt: Date

    public init(
        id: UUID,
        conversationID: UUID,
        senderID: UUID,
        sender: UserProfile? = nil,
        content: String,
        createdAt: Date
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.sender = sender
        self.content = content
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case sender
        case content
        case createdAt = "created_at"
    }
}

public struct ConversationSummary: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var participants: [UserProfile]
    public var lastMessage: ChatMessage?
    public var createdAt: Date

    public init(
        id: UUID,
        title: String,
        participants: [UserProfile],
        lastMessage: ChatMessage?,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.participants = participants
        self.lastMessage = lastMessage
        self.createdAt = createdAt
    }
}

struct ConversationParticipantRecord: Decodable {
    let conversation: ConversationRecord

    struct ConversationRecord: Decodable {
        let id: UUID
        let title: String?
        let createdAt: Date
        let messages: [MessageRecord]?
        let participants: [ParticipantRecord]?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case createdAt = "created_at"
            case messages
            case participants
        }
    }

    struct MessageRecord: Decodable {
        let id: UUID
        let content: String
        let senderID: UUID
        let conversationID: UUID
        let createdAt: Date
        let sender: UserProfile?

        enum CodingKeys: String, CodingKey {
            case id
            case content
            case senderID = "sender_id"
            case conversationID = "conversation_id"
            case createdAt = "created_at"
            case sender
        }
    }

    struct ParticipantRecord: Decodable {
        let profile: UserProfile
    }
}

struct ConversationRow: Decodable {
    let id: UUID
    let title: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
    }
}

struct ConversationInsert: Encodable {
    let createdBy: UUID
    let title: String?

    enum CodingKeys: String, CodingKey {
        case createdBy = "created_by"
        case title
    }
}

struct ConversationParticipantInsert: Encodable {
    let conversationID: UUID
    let profileID: UUID

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case profileID = "profile_id"
    }
}

struct MessageInsert: Encodable {
    let conversationID: UUID
    let senderID: UUID
    let content: String

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case content
    }
}

struct ProfileInsert: Encodable {
    let id: UUID
    let displayName: String
    let phone: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case phone
        case email
    }
}

struct ProfileUpdatePayload: Encodable {
    let displayName: String
    let email: String?
    let phone: String?
    let avatarURL: String?
    let about: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
        case phone
        case avatarURL = "avatar_url"
        case about
    }
}
