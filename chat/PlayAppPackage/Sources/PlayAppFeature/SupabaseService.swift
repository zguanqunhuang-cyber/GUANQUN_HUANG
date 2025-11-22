import Foundation
import Supabase

public struct SupabaseServiceError: LocalizedError {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public actor SupabaseService {
    private let client: SupabaseClient
    private let configuration: SupabaseConfiguration

    public init(configuration: SupabaseConfiguration) {
        self.configuration = configuration

#if canImport(OSLog)
        if configuration.enableDebugLogging {
            let logger = OSLogSupabaseLogger()
            let options = SupabaseClientOptions(global: .init(logger: logger))
            self.client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.anonKey, options: options)
            return
        }
#endif

        self.client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.anonKey)
    }

    // MARK: - Auth

    public func signIn(withPhone phone: String, channel: MessagingChannel = .sms) async throws {
        try await client.auth.signInWithOTP(phone: phone, channel: channel)
    }

    public func verify(phone: String, otp: String, channel: MessagingChannel = .sms) async throws -> Session {
        let response = try await client.auth.verifyOTP(
            phone: phone,
            token: otp,
            type: .sms
        )

        if let session = response.session {
            return session
        }

        // In rare cases GoTrue can return user only, request a fresh session.
        return try await client.auth.session
    }

    public func currentSession() async throws -> Session? {
        try? await client.auth.session
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Profiles

    public func getOrCreateProfile(for user: User) async throws -> UserProfile {
        do {
            return try await fetchProfile(id: user.id)
        } catch {
            if let postgrestError = error as? PostgrestError,
               postgrestError.code == "PGRST116" || postgrestError.message.contains("Results contain 0") {
                return try await createProfile(for: user)
            }
            throw error
        }
    }

    public func fetchProfile(id: UUID) async throws -> UserProfile {
        let response: PostgrestResponse<UserProfile> = try await client
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()

        return response.value
    }

    public func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let payload = ProfileUpdatePayload(
            displayName: profile.displayName,
            email: profile.email,
            phone: profile.phone,
            avatarURL: profile.avatarURL?.absoluteString,
            about: profile.about
        )

        let response: PostgrestResponse<UserProfile> = try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: profile.id.uuidString)
            .select()
            .single()
            .execute()

        return response.value
    }

    public func searchProfiles(query: String, excluding userID: UUID) async throws -> [UserProfile] {
        guard !query.isEmpty else { return [] }

        let pattern = "%\(query)%"
        let response: PostgrestResponse<[UserProfile]> = try await client
            .from("profiles")
            .select()
            .or("display_name.ilike.\(pattern),email.ilike.\(pattern)")
            .neq("id", value: userID.uuidString)
            .limit(25)
            .execute()

        return response.value
    }

    // MARK: - Conversations

    public func fetchConversations(for userID: UUID) async throws -> [ConversationSummary] {
        let response: PostgrestResponse<[ConversationParticipantRecord]> = try await client
            .from("conversation_participants")
            .select(
                """
                conversation:conversations(
                    id,
                    title,
                    created_at,
                    messages(order=created_at.desc,limit=1)(id,content,sender_id,conversation_id,created_at,sender:profiles(id,display_name,email,phone,avatar_url)),
                    participants:conversation_participants(profile:profiles(id,display_name,email,phone,avatar_url))
                )
                """
            )
            .eq("profile_id", value: userID.uuidString)
            .order("created_at", ascending: false, referencedTable: "conversation.messages")
            .execute()

        return response.value.compactMap { record in
            let conversation = record.conversation
            let participants = conversation.participants?.map { $0.profile } ?? []
            let lastMessage = conversation.messages?.first.map { message in
                ChatMessage(
                    id: message.id,
                    conversationID: message.conversationID,
                    senderID: message.senderID,
                    sender: message.sender,
                    content: message.content,
                    createdAt: message.createdAt
                )
            }

            let fallbackTitle: String
            if let explicitTitle = conversation.title, !explicitTitle.isEmpty {
                fallbackTitle = explicitTitle
            } else {
                fallbackTitle = participants
                    .filter { $0.id != userID }
                    .map(\.displayName)
                    .joined(separator: ", ")
            }

            return ConversationSummary(
                id: conversation.id,
                title: fallbackTitle.isEmpty ? "Conversation" : fallbackTitle,
                participants: participants,
                lastMessage: lastMessage,
                createdAt: conversation.createdAt
            )
        }
    }

    public func fetchMessages(conversationID: UUID) async throws -> [ChatMessage] {
        let response: PostgrestResponse<[ChatMessage]> = try await client
            .from("messages")
            .select("id, content, created_at, conversation_id, sender_id, sender:profiles!messages_sender_id_fkey(id,display_name,email,phone,avatar_url)")
            .eq("conversation_id", value: conversationID.uuidString)
            .order("created_at", ascending: true)
            .execute()

        return response.value
    }

    public func sendMessage(
        conversationID: UUID,
        senderID: UUID,
        content: String
    ) async throws -> ChatMessage {
        let payload = MessageInsert(conversationID: conversationID, senderID: senderID, content: content)
        let response: PostgrestResponse<[ChatMessage]> = try await client
            .from("messages")
            .insert(payload, returning: .representation)
            .select("id, content, created_at, conversation_id, sender_id")
            .execute()

        guard let message = response.value.first else {
            throw SupabaseServiceError("Failed to send message")
        }

        return message
    }

    public func createConversation(
        with otherUserID: UUID,
        currentUserID: UUID,
        title: String? = nil
    ) async throws -> ConversationSummary {
        let conversationResponse: PostgrestResponse<[ConversationRow]> = try await client
            .from("conversations")
            .insert(
                ConversationInsert(createdBy: currentUserID, title: title),
                returning: .representation
            )
            .select("id,title,created_at")
            .execute()

        guard let conversationRow = conversationResponse.value.first else {
            throw SupabaseServiceError("Failed to create conversation")
        }

        try await client
            .from("conversation_participants")
            .upsert(
                [
                    ConversationParticipantInsert(conversationID: conversationRow.id, profileID: currentUserID),
                    ConversationParticipantInsert(conversationID: conversationRow.id, profileID: otherUserID)
                ],
                onConflict: "conversation_id,profile_id",
                returning: .minimal
            )
            .execute()

        let summaries = try await fetchConversations(for: currentUserID)
        guard let summary = summaries.first(where: { $0.id == conversationRow.id }) else {
            throw SupabaseServiceError("New conversation not found after creation")
        }

        return summary
    }

    // MARK: - Private helpers

    private func createProfile(for user: User) async throws -> UserProfile {
        let insertPayload = ProfileInsert(
            id: user.id,
            displayName: user.userMetadata["display_name"]?.stringValue ?? (user.phone ?? "New User"),
            phone: user.phone,
            email: user.email
        )

        let response: PostgrestResponse<[UserProfile]> = try await client
            .from("profiles")
            .insert(insertPayload, returning: .representation)
            .execute()

        guard let profile = response.value.first else {
            throw SupabaseServiceError("Failed to create profile")
        }

        return profile
    }
}
