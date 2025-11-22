import SwiftUI

struct ChatDetailView: View {
    let chat: ChatSummary
    let profile: UserProfile
    @ObservedObject var chatsViewModel: ChatsViewModel
    @StateObject private var viewModel: ChatDetailViewModel
    @State private var messageDraft = ""

    init(chat: ChatSummary, profile: UserProfile, chatsViewModel: ChatsViewModel) {
        self.chat = chat
        self.profile = profile
        self.chatsViewModel = chatsViewModel
        _viewModel = StateObject(wrappedValue: ChatDetailViewModel(chat: chat, currentUser: profile))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastID = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("输入消息", text: $messageDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)

                Button {
                    Task {
                        await viewModel.sendMessage(messageDraft, chat: chat, chatsViewModel: chatsViewModel)
                        messageDraft = ""
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                }
                .disabled(messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.teardown()
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isMine {
                Spacer()
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if message.isMine == false {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(message.content)
                    .padding(12)
                    .background(message.isMine ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundStyle(message.isMine ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.isMine == false {
                Spacer()
            }
        }
    }
}
