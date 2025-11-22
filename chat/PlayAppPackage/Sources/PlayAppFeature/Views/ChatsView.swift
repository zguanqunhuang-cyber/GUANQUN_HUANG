import SwiftUI

struct ChatsView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var path = NavigationPath()
    @State private var isShowingSearch = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if appModel.conversations.isEmpty {
                    ContentUnavailableView(
                        "No conversations",
                        systemImage: "message.badge",
                        description: Text("Tap + to find friends and start chatting.")
                    )
                } else {
                    List(appModel.conversations) { conversation in
                        NavigationLink(value: conversation) {
                            ConversationRowView(conversation: conversation)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationDestination(for: ConversationSummary.self) { conversation in
                ChatDetailView(conversation: conversation)
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSearch.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .task {
                try? await appModel.loadConversations()
            }
            .refreshable {
                try? await appModel.loadConversations()
            }
            .sheet(isPresented: $isShowingSearch) {
                NavigationStack {
                    SearchPeopleView { profile in
                        Task {
                            if let newConversation = await appModel.createConversation(with: profile) {
                                path.append(newConversation)
                            }
                            isShowingSearch = false
                        }
                    }
                }
            }
        }
    }
}

private struct ConversationRowView: View {
    let conversation: ConversationSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(conversation.title.prefix(2).uppercased())
                        .font(.headline)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)
                if let message = conversation.lastMessage {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            let date = conversation.lastMessage?.createdAt ?? conversation.createdAt
            Text(date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
