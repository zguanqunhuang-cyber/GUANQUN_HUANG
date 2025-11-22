import Foundation

struct ChatSummary: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let lastMessagePreview: String
    let lastMessageAt: Date
    let unreadCount: Int
    let participantIDs: [UUID]

    var isPlaceholderTitle: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.caseInsensitiveCompare("user") == .orderedSame
    }

    func withTitle(_ newTitle: String) -> ChatSummary {
        ChatSummary(
            id: id,
            title: newTitle,
            lastMessagePreview: lastMessagePreview,
            lastMessageAt: lastMessageAt,
            unreadCount: unreadCount,
            participantIDs: participantIDs
        )
    }
}

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let chatID: UUID
    let senderID: UUID
    let senderName: String
    let content: String
    let createdAt: Date
    var isMine: Bool { senderID == currentUserID }

    private let currentUserID: UUID

    init(id: UUID, chatID: UUID, senderID: UUID, senderName: String, content: String, createdAt: Date, currentUserID: UUID) {
        self.id = id
        self.chatID = chatID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.createdAt = createdAt
        self.currentUserID = currentUserID
    }
}
