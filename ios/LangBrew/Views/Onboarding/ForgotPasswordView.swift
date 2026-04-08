import SwiftUI

/// L2/L3 -- Forgot password flow.
/// Step 1: Enter email to receive reset code.
/// Step 2: Enter 6-digit code.
/// Step 3: Set new password.
struct ForgotPasswordView: View {
    let authManager: AuthManager
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    enum Step {
        case email
        case code
        case newPassword
        case success
    }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            switch step {
            case .email:
                emailStepView
            case .code:
                VerifyCodeView(
                    email: email,
                    onVerify: { code in
                        try await handleCodeVerification(code: code)
                    },
                    onResend: {
                        try? await authManager.sendPasswordReset(email: email)
                    },
                    onBack: { step = .email }
                )
            case .newPassword:
                newPasswordView
            case .success:
                successView
            }
        }
    }

    // MARK: - Step 1: Email

    private var emailStepView: some View {
        VStack(spacing: 0) {
            OnboardingNav(
                showBack: true,
                onBack: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Forgot password?")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    Text("Enter your email and we'll send you a code to reset your password.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .padding(.bottom, LBTheme.Spacing.xl)

                    OnboardingInput(
                        placeholder: "Email address",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .padding(.top, LBTheme.Spacing.sm)
                    }

                    OnboardingCTA("Send Reset Code", isLoading: isLoading) {
                        Task { await handleSendCode() }
                    }
                    .padding(.top, LBTheme.Spacing.lg)
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.top, LBTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Step 3: New Password

    private var newPasswordView: some View {
        VStack(spacing: 0) {
            OnboardingNav(
                showBack: true,
                onBack: { step = .code }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Set new password")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    Text("Choose a strong password for your account.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .padding(.bottom, LBTheme.Spacing.xl)

                    OnboardingInput(
                        placeholder: "New password",
                        text: $password,
                        isSecure: true,
                        textContentType: .newPassword
                    )
                    .padding(.bottom, 10)

                    OnboardingInput(
                        placeholder: "Confirm password",
                        text: $confirmPassword,
                        isSecure: true,
                        textContentType: .newPassword
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .padding(.top, LBTheme.Spacing.sm)
                    }

                    OnboardingCTA("Reset Password", isLoading: isLoading) {
                        Task { await handleSetNewPassword() }
                    }
                    .padding(.top, LBTheme.Spacing.lg)
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.top, LBTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: LBTheme.Spacing.lg) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.lbBlack)

                Text("Password reset")
                    .font(LBTheme.Typography.title)
                    .foregroundStyle(Color.lbBlack)

                Text("Your password has been updated.\nYou can now sign in.")
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG500)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, LBTheme.Spacing.xl)

            Spacer()

            OnboardingCTA("Back to Sign In") {
                onComplete()
            }
            .padding(.horizontal, LBTheme.Spacing.xl)
            .padding(.bottom, LBTheme.Spacing.xxxl)
        }
    }

    // MARK: - Actions

    private func handleSendCode() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authManager.sendPasswordReset(email: email)
            isLoading = false
            step = .code
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleCodeVerification(code: String) async throws {
        try await authManager.verifyPasswordResetCode(email: email, code: code)
        step = .newPassword
    }

    private func handleSetNewPassword() async {
        guard !password.isEmpty else {
            errorMessage = "Please enter a new password."
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authManager.updatePassword(password)
            try? await authManager.signOut()
            isLoading = false
            step = .success
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    ForgotPasswordView(authManager: .shared) {}
}
