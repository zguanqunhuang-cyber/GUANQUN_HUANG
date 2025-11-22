import SwiftUI

struct ChatDetailView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let conversation: ConversationSummary
    @State private var messageText: String = ""
    @State private var isLoadingMessages = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ForEach(appModel.latestMessages[conversation.id] ?? []) { message in
                            MessageBubble(message: message, isOwn: isOwn(message: message))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                                .id(message.id)
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if isLoadingMessages {
                        ProgressView()
                    } else if (appModel.latestMessages[conversation.id] ?? []).isEmpty {
                        ContentUnavailableView(
                            "Say hi",
                            systemImage: "ellipsis.bubble",
                            description: Text("Nobody has sent a message yet. Be the first!")
                        )
                    }
                }
                .task {
                    await loadMessages(scrollProxy: proxy)
                }
                .refreshable {
                    await loadMessages(scrollProxy: proxy, shouldScrollToBottom: false)
                }
                .onChange(of: appModel.latestMessages[conversation.id]?.count ?? 0) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isOwn(message: ChatMessage) -> Bool {
        guard case .authenticated(let session) = appModel.state else { return false }
        return message.senderID == session.profile.id
    }

    private func loadMessages(scrollProxy: ScrollViewProxy, shouldScrollToBottom: Bool = true) async {
        guard !isLoadingMessages else { return }
        isLoadingMessages = true
        await appModel.reloadMessages(for: conversation.id)
        isLoadingMessages = false
        if shouldScrollToBottom {
            scrollToBottom(proxy: scrollProxy)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = appModel.latestMessages[conversation.id]?.last else { return }
        withAnimation {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        Task {
            await appModel.sendMessage(text, in: conversation.id)
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isOwn: Bool

    var body: some View {
        HStack {
            if isOwn { Spacer(minLength: 32) }

            VStack(alignment: .leading, spacing: 4) {
                if !isOwn, let sender = message.sender {
                    Text(sender.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(message.content)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(isOwn ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(isOwn ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isOwn { Spacer(minLength: 32) }
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
    }
}
