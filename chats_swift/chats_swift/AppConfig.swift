import Foundation

/// Central place for values that need to be shared across the SwiftUI app.
/// Update the placeholders with the actual values from your Supabase project and backend deployment.
enum AppConfig {
    /// e.g. https://xyzcompany.supabase.co
    static let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://wxpgfevsagyjndiunvfc.supabase.co"
    /// Public anon key from Supabase project settings.
    static let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4cGdmZXZzYWd5am5kaXVudmZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2MzY4MTcsImV4cCI6MjA3ODIxMjgxN30.ud4FdVFr2FDolFeY-4g0qWzZccrpA71hY8O3RkaCB5U"

    /// Base URL for the FastAPI backend that broadcasts push notifications, defaults to local dev.
    static let backendBaseURL = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ?? "http://127.0.0.1:8080"
}
