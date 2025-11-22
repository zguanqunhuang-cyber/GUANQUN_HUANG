import SwiftUI

struct MainTabView: View {
    let profile: UserProfile

    var body: some View {
        TabView {
            ChatsContainerView(profile: profile)
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }

            ContactsTabView(profile: profile)
                .tabItem {
                    Label("Contacts", systemImage: "person.2")
                }

            DiscoveryView(profile: profile)
                .tabItem {
                    Label("Discover", systemImage: "sparkles.tv")
                }

            MeView(profile: profile)
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle")
                }
        }
    }
}
