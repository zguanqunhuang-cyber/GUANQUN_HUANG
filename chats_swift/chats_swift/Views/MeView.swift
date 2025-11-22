import SwiftUI

struct MeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var isSigningOut = false
    let profile: UserProfile

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Circle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(Text(profile.avatarInitial).font(.title2))
                        VStack(alignment: .leading) {
                            Text(profile.preferredDisplayName).font(.headline)
                            if let phone = profile.phoneNumber {
                                Text(phone).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("状态") {
                    Text(profile.statusMessage ?? "这个人很神秘")
                }

                Section {
                    Button(role: .destructive) {
                        isSigningOut = true
                        Task { await appViewModel.signOut() }
                    } label: {
                        Text("退出登录")
                    }
                }
            }
            .navigationTitle("Me")
        }
    }
}
