import Foundation
import Supabase

@MainActor
public final class AppViewModel: ObservableObject {
    public enum State: Equatable {
        case loading
        case signedOut
        case awaitingOTP(phone: String)
        case authenticated(UserSession)
        case error(message: String)
    }

    public struct UserSession: Equatable {
        public let session: Session
        public var profile: UserProfile

        public init(session: Session, profile: UserProfile) {
            self.session = session
            self.profile = profile
        }
    }

    @Published public private(set) var state: State = .loading
    @Published public private(set) var conversations: [ConversationSummary] = []
    @Published public private(set) var latestMessages: [UUID: [ChatMessage]] = [:]
    @Published public private(set) var isProcessing: Bool = false
    @Published public var activeError: String?

    private let supabase: SupabaseService
    private var pendingPhoneNumber: String?

    public init(configuration: SupabaseConfiguration) {
        self.supabase = SupabaseService(configuration: configuration)
        Task {
            await bootstrap()
        }
    }

    public func bootstrap() async {
        state = .loading
        do {
            if let session = try await supabase.currentSession() {
                let profile = try await supabase.getOrCreateProfile(for: session.user)
                let userSession = UserSession(session: session, profile: profile)
                state = .authenticated(userSession)
                try await loadConversations()
            } else {
                state = .signedOut
            }
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    public func startPhoneSignIn(phone: String) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await supabase.signIn(withPhone: phone)
            pendingPhoneNumber = phone
            state = .awaitingOTP(phone: phone)
        } catch {
            activeError = error.localizedDescription
        }
    }

    public func verifyOTP(code: String) async {
        guard let phone = pendingPhoneNumber else {
            activeError = "Missing phone number context"
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let session = try await supabase.verify(phone: phone, otp: code)
            let profile = try await supabase.getOrCreateProfile(for: session.user)
            pendingPhoneNumber = nil
            let userSession = UserSession(session: session, profile: profile)
            state = .authenticated(userSession)
            try await loadConversations()
        } catch {
            activeError = error.localizedDescription
        }
    }

    public func refreshProfile() async {
        guard case .authenticated(let userSession) = state else { return }

        do {
            let profile = try await supabase.fetchProfile(id: userSession.profile.id)
            state = .authenticated(UserSession(session: userSession.session, profile: profile))
        } catch {
            activeError = error.localizedDescription
        }
    }

    public func updateProfile(displayName: String?, email: String?, about: String?) async {
        guard case .authenticated(var userSession) = state else { return }

        var updatedProfile = userSession.profile
        if let displayName, !displayName.isEmpty {
            updatedProfile.displayName = displayName
        }
        updatedProfile.email = email
        updatedProfile.about = about

        do {
            let savedProfile = try await supabase.updateProfile(updatedProfile)
            userSession.profile = savedProfile
            state = .authenticated(userSession)
        } catch {
            activeError = error.localizedDescription
        }
    }

    public func loadConversations() async throws {
        guard case .authenticated(let userSession) = state else { return }
        do {
            conversations = try await supabase.fetchConversations(for: userSession.profile.id)
        } catch {
            activeError = error.localizedDescription
            throw error
        }
    }

    public func reloadMessages(for conversationID: UUID) async {
        do {
            let messages = try await supabase.fetchMessages(conversationID: conversationID)
            latestMessages[conversationID] = messages
        } catch {
            activeError = error.localizedDescription
        }
    }

    public func sendMessage(_ text: String, in conversationID: UUID) async {
        guard case .authenticated(let userSession) = state else { return }

        do {
            let message = try await supabase.sendMessage(
                conversationID: conversationID,
                senderID: userSession.profile.id,
                content: text
            )

            var existing = latestMessages[conversationID] ?? []
            existing.append(message)
            latestMessages[conversationID] = existing
            try await loadConversations()
        } catch {
            activeError = error.localizedDescription
        }
    }

    public func searchProfiles(matching query: String) async -> [UserProfile] {
        guard case .authenticated(let userSession) = state else { return [] }
        do {
            return try await supabase.searchProfiles(query: query, excluding: userSession.profile.id)
        } catch {
            activeError = error.localizedDescription
            return []
        }
    }

    public func createConversation(with profile: UserProfile) async -> ConversationSummary? {
        guard case .authenticated(let userSession) = state else { return nil }

        do {
            let summary = try await supabase.createConversation(
                with: profile.id,
                currentUserID: userSession.profile.id,
                title: nil
            )
            try await loadConversations()
            return summary
        } catch {
            activeError = error.localizedDescription
            return nil
        }
    }

    public func signOut() async {
        do {
            try await supabase.signOut()
        } catch {
            activeError = error.localizedDescription
        }
        state = .signedOut
        conversations.removeAll()
        latestMessages.removeAll()
    }
}
