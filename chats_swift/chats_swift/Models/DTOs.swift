import Foundation

struct ProfileRecord: Codable {
    static let table = "profiles"

    let id: UUID
    let phone: String?
    let display_name: String
    let avatar_url: String?
    let status_message: String?
    let friend_ids: [UUID]?

    init(profile: UserProfile) {
        self.id = profile.id
        self.phone = profile.phoneNumber
        self.display_name = profile.displayName
        self.avatar_url = profile.avatarURL?.absoluteString
        self.status_message = profile.statusMessage
        self.friend_ids = nil
    }

    func toDomain() -> UserProfile {
        UserProfile(
            id: id,
            phoneNumber: phone,
            displayName: Self.resolveDisplayName(display_name: display_name, phone: phone),
            avatarURL: avatar_url.flatMap(URL.init(string:)),
            statusMessage: status_message
        )
    }

    private static func resolveDisplayName(display_name: String, phone: String?) -> String {
        let trimmed = display_name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.caseInsensitiveCompare("user") == .orderedSame {
            return phone ?? "用户"
        }
        return trimmed
    }
}
