import Combine
import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published var chats: [ChatSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let chatService = ChatService()
    private let backendNotifier = BackendNotifier()
    private var currentUser: UserProfile?
    private var cancellable: AnyCancellable?
    private var pollingTask: Task<Void, Never>?

    func bind(user: UserProfile) {
        guard currentUser?.id != user.id else { return }
        currentUser = user
        setupRealtime()
        Task { await refresh() }
        startPolling()
    }

    func refresh() async {
        guard let user = currentUser else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var fetched = try await chatService.chats(for: user.id)
            fetched = await resolveChatTitlesIfNeeded(fetched, currentUserID: user.id)
            chats = fetched
        } catch {
            errorMessage = "加载会话失败: \(error.localizedDescription)"
        }
    }

    func send(message text: String, in chat: ChatSummary) async {
        guard let user = currentUser, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }

        do {
            try await chatService.sendMessage(text, chatID: chat.id, senderID: user.id)
            let recipients = chat.participantIDs.filter { $0 != user.id }
            await backendNotifier.sendOfflineNotification(chatID: chat.id, recipientIDs: recipients, messagePreview: text)
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
        }
    }

    func startChat(with friend: UserProfile, currentUser: UserProfile) async throws -> ChatSummary {
        if let existing = chats.first(where: { Set($0.participantIDs) == Set([friend.id, currentUser.id]) }) {
            return existing
        }

        do {
            let newChat = try await chatService.createChat(with: friend, currentUser: currentUser)
            let resolved = await resolveChatTitlesIfNeeded([newChat], currentUserID: currentUser.id)
            let finalChat = resolved.first ?? newChat
            chats.insert(finalChat, at: 0)
            return finalChat
        } catch {
            throw error
        }
    }

    private func setupRealtime() {
        cancellable?.cancel()
        cancellable = MessageRealtimeService.shared.messagePublisher
            .sink { [weak self] record in
                Task { @MainActor in
                    guard let self else { return }
                    self.handleRealtimeMessage(record)
                }
            }
    }

    private func handleRealtimeMessage(_ record: MessageRecord) {
        guard let index = chats.firstIndex(where: { $0.id == record.chat_id }) else {
            Task { await refresh() }
            return
        }

        let existing = chats[index]
        let updated = ChatSummary(
            id: existing.id,
            title: existing.title,
            lastMessagePreview: record.content,
            lastMessageAt: record.created_at,
            unreadCount: existing.unreadCount,
            participantIDs: existing.participantIDs
        )

        chats.remove(at: index)
        chats.insert(updated, at: 0)
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                await refresh()
            }
        }
    }

    private func resolveChatTitlesIfNeeded(_ chats: [ChatSummary], currentUserID: UUID) async -> [ChatSummary] {
        guard chats.contains(where: { $0.isPlaceholderTitle }) else {
            return chats
        }

        var overrides: [UUID: String] = [:]
        await withTaskGroup(of: (UUID, String?).self) { group in
            for chat in chats where chat.isPlaceholderTitle {
                guard let partnerID = chat.participantIDs.first(where: { $0 != currentUserID }) else { continue }
                group.addTask { [self, chatID = chat.id, partnerID] in
                    let name = try? await self.chatService.preferredName(for: partnerID)
                    return (chatID, name)
                }
            }

            for await (chatID, name) in group {
                if let name, name.isEmpty == false {
                    overrides[chatID] = name
                }
            }
        }

        return chats.map { chat in
            if let newTitle = overrides[chat.id] {
                return chat.withTitle(newTitle)
            } else if chat.isPlaceholderTitle {
                return chat.withTitle("会话")
            }
            return chat
        }
    }
}
