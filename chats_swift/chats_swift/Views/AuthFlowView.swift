import SwiftUI

struct AuthFlowView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer(minLength: 40)
                    headerSection
                        .frame(maxWidth: 520)
                        .padding(.horizontal, 16)
                    stepContent
                        .frame(maxWidth: 520)
                        .padding(.horizontal, 16)
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.pink.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.vertical, 32)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Z")
                .font(.system(size: 56, weight: .black, design: .rounded))
            Text("login by phone number")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .enterPhone:
            phoneEntryView
        case .enterOTP:
            otpEntryView
        case .success:
            ProgressView()
                .tint(.white)
                .padding(.vertical, 24)
        }
    }

    private var phoneEntryView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                GlassField {
                    TextField("+1", text: $viewModel.countryCode)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .frame(width: 90)

                GlassField {
                    TextField("手机号", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }

            Button(
                action: { Task { await viewModel.sendOTP() } },
                label: {
                    HStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("获取验证码")
                    }
                    .frame(maxWidth: .infinity)
                }
            )
            .buttonStyle(GlassButtonStyle())
            .disabled(viewModel.isLoading)
        }
    }

    private var otpEntryView: some View {
        VStack(spacing: 20) {
            GlassField {
                TextField("短信验证码", text: $viewModel.otpCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .textContentType(.oneTimeCode)
            }

            Button(
                action: {
                    Task {
                        do {
                            let profile = try await viewModel.verifyOTP()
                            appViewModel.updateProfile(profile)
                        } catch {}
                    }
                },
                label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal")
                        Text("登录")
                    }
                    .frame(maxWidth: .infinity)
                }
            )
            .buttonStyle(
                GlassButtonStyle(
                    gradient: LinearGradient(
                        colors: [
                            Color(red: 0.32, green: 0.91, blue: 0.84),
                            Color(red: 0.21, green: 0.61, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

private struct LiquidGlassBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.11, blue: 0.28),
                Color(red: 0.05, green: 0.02, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            ZStack {
                Circle()
                    .fill(Color(red: 0.22, green: 0.56, blue: 0.96).opacity(0.55))
                    .frame(width: 260, height: 260)
                    .blur(radius: 90)
                    .offset(x: -150, y: -220)
                Circle()
                    .fill(Color(red: 0.92, green: 0.32, blue: 0.48).opacity(0.45))
                    .frame(width: 220, height: 220)
                    .blur(radius: 100)
                    .offset(x: 140, y: -120)
                Circle()
                    .fill(Color(red: 0.24, green: 0.84, blue: 0.72).opacity(0.4))
                    .frame(width: 300, height: 300)
                    .blur(radius: 120)
                    .offset(x: 120, y: 260)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.softLight)
            }
        )
    }
}

private struct GlassField<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack {
            content
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .tint(.white)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .glassSurface(cornerRadius: 20, fillOpacity: 0.12, strokeOpacity: 0.22, shadowOpacity: 0.18, shadowRadius: 18, shadowY: 10)
    }
}

private struct GlassButtonStyle: ButtonStyle {
    var gradient: LinearGradient = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.58, blue: 1.0),
            Color(red: 0.02, green: 0.75, blue: 0.87)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private extension View {
    func glassSurface(
        cornerRadius: CGFloat,
        fillOpacity: Double,
        strokeOpacity: Double = 0.28,
        shadowOpacity: Double,
        shadowRadius: CGFloat,
        shadowY: CGFloat
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.white.opacity(fillOpacity))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowY)
    }
}
