import Combine
import Foundation
import Supabase

@MainActor
final class AppViewModel: ObservableObject {
    enum AuthState {
        case loading
        case signedOut
        case signedIn(UserProfile)
    }

    @Published private(set) var authState: AuthState = .loading
    private let authService = AuthService()
    private let authClient = SupabaseManager.shared.client.auth

    init() {
        Task { await loadInitialSession() }
    }

    func loadInitialSession() async {
        do {
            if let session = try? await authClient.session {
                let profile = try await authService.fetchProfile(for: session.user.id)
                MessageRealtimeService.shared.start(for: profile.id)
                authState = .signedIn(profile)
                return
            }

            if let cachedSession = authClient.currentSession {
                let profile = try await authService.fetchProfile(for: cachedSession.user.id)
                MessageRealtimeService.shared.start(for: profile.id)
                authState = .signedIn(profile)
                return
            }

            authState = .signedOut
        } catch {
            authState = .signedOut
        }
    }

    func signOut() async {
        do {
            try await authClient.signOut()
            MessageRealtimeService.shared.stop()
            authState = .signedOut
        } catch {
            #if DEBUG
            print("Sign out failed: \(error)")
            #endif
        }
    }

    func updateProfile(_ profile: UserProfile) {
        MessageRealtimeService.shared.start(for: profile.id)
        authState = .signedIn(profile)
    }
}
