import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var phoneNumber: String?
    var displayName: String
    var avatarURL: URL?
    var statusMessage: String?

    init(id: UUID, phoneNumber: String?, displayName: String, avatarURL: URL? = nil, statusMessage: String? = nil) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.statusMessage = statusMessage
    }

    var preferredDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare("user") == .orderedSame {
            return phoneNumber ?? "用户"
        }
        return trimmed
    }

    var avatarInitial: String {
        let first = preferredDisplayName.first ?? "用"
        return String(first).uppercased()
    }
}

struct FriendRequest: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case pending
        case accepted
        case rejected
    }

    let id: UUID
    let requesterID: UUID
    let addresseeID: UUID
    let createdAt: Date
    var status: Status
    var requester: UserProfile?
    var addressee: UserProfile?

    var requesterDisplayName: String {
        requester?.preferredDisplayName ?? requesterID.uuidString
    }

    var addresseeDisplayName: String {
        addressee?.preferredDisplayName ?? addresseeID.uuidString
    }
}
