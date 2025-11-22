import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum Step {
        case enterPhone
        case enterOTP
        case success
    }

    @Published var countryCode = "+1"
    @Published var phoneNumber = ""
    @Published var otpCode = ""
    @Published var step: Step = .enterPhone
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService = AuthService()
    private var lastPhoneNumber: String?

    func sendOTP() async {
        guard let formattedPhone = normalizedPhoneNumber() else {
            errorMessage = "请输入合法手机号"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.sendOTP(to: formattedPhone)
            lastPhoneNumber = formattedPhone
            step = .enterOTP
        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
        }
    }

    func verifyOTP() async throws -> UserProfile {
        let targetPhone = lastPhoneNumber ?? normalizedPhoneNumber()
        guard let phone = targetPhone, !otpCode.isEmpty else {
            throw SupabaseError.invalidConfiguration("验证码或手机号为空")
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await authService.verifyOTP(phoneNumber: phone, token: otpCode)
            step = .success
            return profile
        } catch {
            errorMessage = "验证失败: \(error.localizedDescription)"
            throw error
        }
    }

    private func normalizedPhoneNumber() -> String? {
        let trimmedCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.hasPrefix("+"), trimmedCode.count > 1 else { return nil }

        let filtered = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard filtered.isEmpty == false else { return nil }
        return trimmedCode + filtered
    }
}
