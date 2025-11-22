import Foundation

public struct SupabaseConfiguration: Sendable {
    public let url: URL
    public let anonKey: String
    public let enableDebugLogging: Bool

    public init(url: URL, anonKey: String, enableDebugLogging: Bool = false) {
        self.url = url
        self.anonKey = anonKey
        self.enableDebugLogging = enableDebugLogging
    }
}

public extension SupabaseConfiguration {
    static let placeholder = SupabaseConfiguration(
        url: URL(string: "https://your-project-ref.supabase.co")!,
        anonKey: "SUPABASE_ANON_KEY"
    )
}
