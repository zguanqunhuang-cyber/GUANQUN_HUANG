import SwiftUI

struct OTPVerificationView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let phoneNumber: String
    @State private var code: String = ""

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Enter verification code")
                    .font(.title3.weight(.semibold))
                Text("We sent a code to \(phoneNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await appModel.verifyOTP(code: code) }
            } label: {
                if appModel.isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isProcessing)

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}
