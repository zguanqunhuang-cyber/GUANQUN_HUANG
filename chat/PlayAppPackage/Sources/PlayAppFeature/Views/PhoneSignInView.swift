import SwiftUI

struct PhoneSignInView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var phoneNumber: String = ""

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Sign in with your phone")
                    .font(.title3.weight(.semibold))
                Text("We will send a one-time password to your WhatsApp/SMS.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Phone number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await appModel.startPhoneSignIn(phone: phoneNumber) }
            } label: {
                if appModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Send Code")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isProcessing)

            Spacer()
        }
        .padding()
    }
}
