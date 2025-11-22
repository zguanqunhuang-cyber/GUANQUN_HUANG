import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        Group {
            switch appModel.state {
            case .loading:
                ProgressView("Loading…")
            case .signedOut:
                PhoneSignInView()
            case .awaitingOTP(let phone):
                OTPVerificationView(phoneNumber: phone)
            case .authenticated:
                MainTabView()
            case .error(let message):
                VStack(spacing: 16) {
                    Text("Something went wrong")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await appModel.bootstrap() }
                    }
                }
                .padding()
            }
        }
        .animation(.easeInOut, value: appModel.state)
        .alert("Error", isPresented: Binding<Bool>(
            get: { appModel.activeError != nil },
            set: { newValue in
                if !newValue { appModel.activeError = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                appModel.activeError = nil
            }
        } message: {
            Text(appModel.activeError ?? "Unknown error")
        }
    }
}
