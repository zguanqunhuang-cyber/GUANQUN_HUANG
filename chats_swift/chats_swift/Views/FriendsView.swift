import SwiftUI

struct FriendsView: View {
    @ObservedObject var viewModel: FriendsViewModel

    var body: some View {
        NavigationStack {
            List {
                if let info = viewModel.infoMessage {
                    Text(info)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if viewModel.incomingRequests.isEmpty == false {
                    Section("待处理请求") {
                        ForEach(viewModel.incomingRequests) { request in
                            FriendRequestRow(
                                title: request.requesterDisplayName,
                                request: request,
                                primaryActionTitle: "同意",
                                primaryAction: { Task { await viewModel.respond(to: request, accept: true) } },
                                secondaryActionTitle: "拒绝",
                                secondaryAction: { Task { await viewModel.respond(to: request, accept: false) } }
                            )
                        }
                    }
                }

                if viewModel.outgoingRequests.isEmpty == false {
                    Section("已发送请求") {
                        ForEach(viewModel.outgoingRequests) { request in
                            FriendRequestRow(
                                title: request.addresseeDisplayName,
                                request: request,
                                primaryActionTitle: nil,
                                primaryAction: nil,
                                secondaryActionTitle: nil,
                                secondaryAction: nil
                            )
                        }
                    }
                }

                Section("好友") {
                    ForEach(viewModel.friends) { friend in
                        HStack {
                            Circle()
                                .fill(Color.orange.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(Text(friend.avatarInitial))
                            VStack(alignment: .leading) {
                                Text(friend.preferredDisplayName)
                                if let status = friend.statusMessage {
                                    Text(status).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .refreshable {
                await viewModel.refreshAll()
            }
        }
        .task {
            await viewModel.refreshAll()
        }
    }
}

struct AddFriendSheet: View {
    @ObservedObject var viewModel: FriendsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("手机号") {
                    TextField("输入好友手机号", text: $viewModel.phoneToAdd)
                        .keyboardType(.phonePad)
                }
                Section {
                    Button("发送好友请求") {
                        Task { await viewModel.addFriend() }
                    }
                    .disabled(viewModel.phoneToAdd.isEmpty)
                }
                if let info = viewModel.infoMessage {
                    Section {
                        Text(info)
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Friend")
        }
    }
}

struct NewChatSheet: View {
    let profile: UserProfile
    @ObservedObject var friendsViewModel: FriendsViewModel
    @ObservedObject var chatsViewModel: ChatsViewModel
    var onChatCreated: (ChatSummary) -> Void

    @State private var isProcessing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                ForEach(friendsViewModel.friends) { friend in
                    Button {
                        Task { await createChat(with: friend) }
                    } label: {
                        HStack {
                            Text(friend.preferredDisplayName)
                            Spacer()
                            if isProcessing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isProcessing)
                }
            }
            .navigationTitle("New Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func createChat(with friend: UserProfile) async {
        guard isProcessing == false else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let chat = try await chatsViewModel.startChat(with: friend, currentUser: profile)
            errorMessage = nil
            onChatCreated(chat)
            dismiss()
        } catch {
            errorMessage = "创建会话失败: \(error.localizedDescription)"
        }
    }
}

private struct FriendRequestRow: View {
    let title: String
    let request: FriendRequest
    let primaryActionTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text("状态: \(localizedStatus)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let primaryActionTitle, let primaryAction {
                HStack {
                    Button(primaryActionTitle, action: primaryAction)
                    if let secondaryActionTitle, let secondaryAction {
                        Button(secondaryActionTitle, action: secondaryAction)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var localizedStatus: String {
        switch request.status {
        case .pending:
            return "待处理"
        case .accepted:
            return "已通过"
        case .rejected:
            return "已拒绝"
        }
    }
}
