import SwiftUI
import PlayAppFeature

@main
struct PlayAppApp: App {
    private let configuration = SupabaseConfiguration(
        url: SupabaseSecrets.projectURL,
        anonKey: SupabaseSecrets.anonKey
    )

    var body: some Scene {
        WindowGroup {
            ContentView(configuration: configuration)
        }
    }
}
