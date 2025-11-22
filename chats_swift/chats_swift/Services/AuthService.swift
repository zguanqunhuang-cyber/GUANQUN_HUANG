import Foundation
import Supabase

struct AuthService {
    private let client = SupabaseManager.shared.client

    func sendOTP(to phoneNumber: String) async throws {
        try await client.auth.signInWithOTP(phone: phoneNumber)
    }

    func verifyOTP(phoneNumber: String, token: String) async throws -> UserProfile {
        let response = try await client.auth.verifyOTP(
            phone: phoneNumber,
            token: token,
            type: .sms
        )
        return try await fetchProfile(for: response.user.id)
    }

    func fetchProfile(for userID: UUID) async throws -> UserProfile {
        let rows: [ProfileRecord] = try await client
            .from(ProfileRecord.table)
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value

        if let profileRecord = rows.first {
            return profileRecord.toDomain()
        }

        let phone = phoneNumberFromAuth()
        let fallbackProfile = UserProfile(
            id: userID,
            phoneNumber: phone,
            displayName: phone ?? "用户"
        )
        try await upsertProfile(fallbackProfile)
        return fallbackProfile
    }

    func upsertProfile(_ profile: UserProfile) async throws {
        let dto = ProfileRecord(profile: profile)
        try await client
            .from(ProfileRecord.table)
            .upsert(dto)
            .select()
            .execute()
    }

    private func phoneNumberFromAuth() -> String? {
        SupabaseManager.shared.client.auth.currentSession?.user.phone
    }
}
