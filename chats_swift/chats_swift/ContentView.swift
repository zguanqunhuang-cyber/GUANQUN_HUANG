import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        Group {
            switch appViewModel.authState {
            case .loading:
                ProgressView("正在检查会话...")
            case .signedOut:
                AuthFlowView()
            case .signedIn(let profile):
                MainTabView(profile: profile)
            }
        }
        .task {
            await appViewModel.loadInitialSession()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
