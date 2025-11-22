import Combine
import Foundation

@MainActor
final class ChatDetailViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false

    private let chatService = ChatService()
    private var chat: ChatSummary
    private var currentUser: UserProfile
    private var cancellable: AnyCancellable?
    private var pollingTask: Task<Void, Never>?

    init(chat: ChatSummary, currentUser: UserProfile) {
        self.chat = chat
        self.currentUser = currentUser
        Task { await loadMessages() }
        subscribeRealtime()
        startPolling()
    }

    func reload(with chat: ChatSummary) {
        self.chat = chat
        Task { await loadMessages() }
        subscribeRealtime()
        startPolling()
    }

    func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await chatService.messages(for: chat.id, currentUserID: currentUser.id)
        } catch {
            #if DEBUG
            print("Load messages failed: \(error)")
            #endif
        }
    }

    private func subscribeRealtime() {
        cancellable?.cancel()
        cancellable = MessageRealtimeService.shared.messagePublisher
            .filter { $0.chat_id == self.chat.id }
            .sink { [weak self] record in
                Task { @MainActor in
                    guard let self else { return }
                    var snapshot = self.messages
                    let message = record.toDomain(currentUserID: self.currentUser.id)
                    if snapshot.contains(where: { $0.id == message.id }) == false {
                        snapshot.append(message)
                        snapshot.sort { $0.createdAt < $1.createdAt }
                        self.messages = snapshot
                    }
                }
            }
    }

    func teardown() {
        cancellable?.cancel()
        pollingTask?.cancel()
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                await loadMessages()
            }
        }
    }

    func sendMessage(_ text: String, chat: ChatSummary, chatsViewModel: ChatsViewModel) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        let tempMessage = Message(
            id: UUID(),
            chatID: chat.id,
            senderID: currentUser.id,
            senderName: currentUser.preferredDisplayName,
            content: trimmed,
            createdAt: Date(),
            currentUserID: currentUser.id
        )

        await MainActor.run { messages.append(tempMessage) }

        do {
            try await chatsViewModel.send(message: trimmed, in: chat)
        } catch {
            await MainActor.run {
                messages.removeAll { $0.id == tempMessage.id }
            }
        }
    }
}
