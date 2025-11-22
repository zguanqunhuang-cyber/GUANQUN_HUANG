import Combine
import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friends: [UserProfile] = []
    @Published var isAddingFriend = false
    @Published var phoneToAdd = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []

    private let friendService = FriendService()
    private var currentUserID: UUID?

    func bind(user: UserProfile) {
        guard currentUserID != user.id else { return }
        currentUserID = user.id
        Task { await refreshAll() }
    }

    func refreshAll() async {
        await loadFriends()
        await loadFriendRequests()
    }

    func loadFriends() async {
        guard let userID = currentUserID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            friends = try await friendService.fetchFriends(for: userID)
            errorMessage = nil
        } catch {
            errorMessage = "好友加载失败: \(error.localizedDescription)"
        }
    }

    func loadFriendRequests() async {
        guard let userID = currentUserID else { return }
        do {
            incomingRequests = try await friendService.fetchFriendRequests(for: userID, role: .incoming)
            outgoingRequests = try await friendService.fetchFriendRequests(for: userID, role: .outgoing)
            errorMessage = nil
        } catch {
            errorMessage = "好友请求加载失败: \(error.localizedDescription)"
        }
    }

    func addFriend() async {
        guard let userID = currentUserID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await friendService.sendFriendRequest(byPhone: phoneToAdd, requesterID: userID)
            isAddingFriend = false
            phoneToAdd = ""
            infoMessage = "好友请求已发送"
            errorMessage = nil
            await loadFriendRequests()
        } catch {
            errorMessage = "添加好友失败: \(error.localizedDescription)"
        }
    }

    func respond(to request: FriendRequest, accept: Bool) async {
        guard let userID = currentUserID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await friendService.respondToFriendRequest(request.id, accept: accept, responderID: userID)
            infoMessage = accept ? "已同意好友请求" : "已拒绝好友请求"
            errorMessage = nil
            await refreshAll()
        } catch {
            errorMessage = "操作失败: \(error.localizedDescription)"
        }
    }
}
