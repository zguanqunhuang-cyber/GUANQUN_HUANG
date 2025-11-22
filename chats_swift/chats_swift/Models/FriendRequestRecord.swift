import Foundation

struct FriendRequestRecord: Decodable {
    let id: UUID
    let requesterID: UUID
    let addresseeID: UUID
    let status: FriendRequest.Status
    let createdAt: Date
    let requesterProfile: ProfilePreview?
    let addresseeProfile: ProfilePreview?

    private enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
        case createdAt = "created_at"
        case requesterProfile = "requester"
        case addresseeProfile = "addressee"
    }

    func toDomain() -> FriendRequest {
        FriendRequest(
            id: id,
            requesterID: requesterID,
            addresseeID: addresseeID,
            createdAt: createdAt,
            status: status,
            requester: requesterProfile?.toDomain(),
            addressee: addresseeProfile?.toDomain()
        )
    }
}

struct ProfilePreview: Decodable {
    let id: UUID
    let displayName: String
    let phone: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case phone
    }

    func toDomain() -> UserProfile {
        UserProfile(
            id: id,
            phoneNumber: phone,
            displayName: resolvedDisplayName()
        )
    }

    private func resolvedDisplayName() -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare("user") == .orderedSame {
            return phone ?? "用户"
        }
        return trimmed
    }
}
