import SwiftUI

struct ContactsTabView: View {
    let profile: UserProfile
    @StateObject private var viewModel = FriendsViewModel()

    var body: some View {
        FriendsView(viewModel: viewModel)
            .task {
                viewModel.bind(user: profile)
            }
    }
}
