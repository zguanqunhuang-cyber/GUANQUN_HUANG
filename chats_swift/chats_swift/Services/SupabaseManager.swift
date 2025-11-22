import Foundation
import Supabase

enum SupabaseError: Error {
    case invalidConfiguration(String)
}

/// Lazily builds a single Supabase client instance that can be reused by the entire app.
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        guard let url = URL(string: AppConfig.supabaseURL),
              AppConfig.supabaseURL.hasPrefix("http")
        else {
            fatalError("Supabase URL is not configured. Update AppConfig or set SUPABASE_URL env var.")
        }

        guard AppConfig.supabaseAnonKey.isEmpty == false else {
            fatalError("Supabase anon key missing. Update AppConfig or set SUPABASE_ANON_KEY env var.")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(autoRefreshToken: true, emitLocalSessionAsInitialSession: true),
                realtime: .init(heartbeatInterval: 15)
            )
        )
    }
}
