import SwiftUI

struct ChatsContainerView: View {
    let profile: UserProfile
    @StateObject private var viewModel = ChatsViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()
    @State private var showingAddFriendSheet = false
    @State private var showingNewChatSheet = false

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading && viewModel.chats.isEmpty {
                    ProgressView()
                } else if viewModel.chats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("暂无会话")
                        Button("开始新的聊天") {
                            showingNewChatSheet = true
                        }
                    }
                } else {
                    List(viewModel.chats) { chat in
                        NavigationLink(value: chat) {
                            ChatRow(chat: chat)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("New Chat", systemImage: "ellipsis.bubble") {
                            showingNewChatSheet = true
                        }
                        Button("Add Friend", systemImage: "person.badge.plus") {
                            showingAddFriendSheet = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: ChatSummary.self) { chat in
                ChatDetailView(chat: chat, profile: profile, chatsViewModel: viewModel)
            }
            .task {
                viewModel.bind(user: profile)
                friendsViewModel.bind(user: profile)
            }
            .sheet(isPresented: $showingAddFriendSheet) {
                AddFriendSheet(viewModel: friendsViewModel)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingNewChatSheet) {
                NewChatSheet(
                    profile: profile,
                    friendsViewModel: friendsViewModel,
                    chatsViewModel: viewModel
                ) { chat in
                    showingNewChatSheet = false
                    navigationPath.append(chat)
                }
            }
        }
    }
}

private struct ChatRow: View {
    let chat: ChatSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(Text(String(chat.title.prefix(1))).font(.headline))

            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(.headline)
                Text(chat.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(chat.lastMessageAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if chat.unreadCount > 0 {
                    Text("\(chat.unreadCount)")
                        .font(.caption2)
                        .padding(6)
                        .background(Capsule().fill(Color.red))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
