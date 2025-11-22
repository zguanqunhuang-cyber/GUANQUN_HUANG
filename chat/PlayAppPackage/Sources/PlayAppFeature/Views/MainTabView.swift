import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatsView()
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }
                .tag(0)

            NavigationStack {
                ProfileView()
            }
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle")
                }
                .tag(1)
        }
        .task {
            if case .authenticated = appModel.state {
                try? await appModel.loadConversations()
            }
        }
    }
}
