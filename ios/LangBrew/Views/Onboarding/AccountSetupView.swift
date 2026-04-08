import SwiftUI
import UIKit
import UserNotifications

/// O6 -- Account setup. Step 5 of 5.
/// Back + progress bar (100%), Apple/Google buttons, or divider,
/// email + password inputs, "Create Account" CTA, terms text,
/// bottom link to sign in.
struct AccountSetupView: View {
    let authManager: AuthManager
    let coordinator: AppCoordinator?
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showVerification = false
    @State private var showLogin = false

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            if showVerification {
                VerifyCodeView(
                    email: authManager.pendingEmail ?? email,
                    onVerify: { code in
                        try await handleCodeVerification(code: code)
                    },
                    onResend: {
                        await handleResendCode()
                    },
                    onBack: {
                        authManager.clearPendingConfirmation()
                        showVerification = false
                        errorMessage = nil
                    }
                )
            } else if showLogin {
                LoginView(authManager: authManager) {
                    Task {
                        await coordinator?.handlePostAuthentication()
                        if coordinator?.phase != .main {
                            onSuccess()
                        }
                    }
                }
            } else {
                signUpFormView
            }
        }
    }

    // MARK: - Sign Up Form

    private var signUpFormView: some View {
        VStack(spacing: 0) {
            OnboardingNav(
                showBack: true,
                onBack: { dismiss() }
            )

            // Progress bar (100%)
            OnboardingProgress(progress: 1.0)
                .padding(.bottom, LBTheme.Spacing.xl)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Step indicator
                    Text("Step 5 of 5 \u{00B7} Almost done")
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG400)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    // Title
                    Text("Create your\naccount.")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.bottom, LBTheme.Spacing.xs)

                    // Subtitle
                    Text("Save your progress and sync across devices.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .padding(.bottom, LBTheme.Spacing.xl)

                    // Apple button
                    AuthButton(style: .apple) {
                        Task { await handleAppleSignIn() }
                    }
                    .padding(.bottom, 10)

                    // Google button
                    AuthButton(style: .google) {
                        Task { await handleGoogleSignIn() }
                    }

                    // Divider
                    AuthDivider()

                    // Name input
                    OnboardingInput(
                        placeholder: "Full name",
                        text: $name,
                        textContentType: .name
                    )
                    .textInputAutocapitalization(.words)
                    .padding(.bottom, 10)

                    // Email input
                    OnboardingInput(
                        placeholder: "Email address",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .padding(.bottom, 10)

                    // Password input
                    OnboardingInput(
                        placeholder: "Password",
                        text: $password,
                        isSecure: true,
                        textContentType: .newPassword
                    )

                    // Error
                    if let errorMessage {
                        Text(errorMessage)
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .padding(.top, LBTheme.Spacing.sm)
                    }

                    // Create Account CTA
                    OnboardingCTA("Create Account", isLoading: isLoading) {
                        Task { await handleEmailSignUp() }
                    }
                    .padding(.top, LBTheme.Spacing.md)

                    // Terms
                    (Text("By continuing, you agree to langbrew's\n")
                        .font(.system(size: 12))
                        .foregroundColor(Color.lbG400)
                     + Text("Terms of Service")
                        .font(.system(size: 12))
                        .foregroundColor(Color.lbG400)
                     + Text(" and ")
                        .font(.system(size: 12))
                        .foregroundColor(Color.lbG400)
                     + Text("Privacy Policy")
                        .font(.system(size: 12))
                        .foregroundColor(Color.lbG400)
                     + Text(".")
                        .font(.system(size: 12))
                        .foregroundColor(Color.lbG400))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, LBTheme.Spacing.md)

                    Spacer(minLength: LBTheme.Spacing.md)
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
            }

            // Bottom link to sign in
            VStack {
                (Text("Already have an account? ")
                    .font(.system(size: 13))
                    .foregroundColor(Color.lbG400)
                 + Text("Sign in")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.lbNearBlack))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, LBTheme.Spacing.md)
            .onTapGesture { showLogin = true }
        }
    }

    // MARK: - Actions

    private func handleAppleSignIn() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signInWithApple()
            await postAuthFlow()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleGoogleSignIn() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signInWithGoogle()
            await postAuthFlow()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleEmailSignUp() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter a password."
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signUpWithEmail(email: email, password: password)

            if authManager.pendingEmailConfirmation {
                isLoading = false
                showVerification = true
            } else {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                if !trimmedName.isEmpty {
                    _ = try? await UserService.shared.updateMe(UserUpdate(name: trimmedName))
                }
                await postAuthFlow()
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleCodeVerification(code: String) async throws {
        try await authManager.verifySignUpCode(
            email: authManager.pendingEmail ?? email,
            code: code
        )

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            _ = try? await UserService.shared.updateMe(UserUpdate(name: trimmedName))
        }

        await postAuthFlow()
    }

    private func handleResendCode() async {
        do {
            try await authManager.signUpWithEmail(email: email, password: password)
        } catch {
            // Silently fail — the user can try again
        }
    }

    /// Common post-authentication flow: fetch profile, request notifications, proceed.
    private func postAuthFlow() async {
        if let coordinator {
            await coordinator.handlePostAuthentication()
            if coordinator.phase == .main {
                isLoading = false
                return
            }
        }

        await requestNotificationPermission()

        isLoading = false
        onSuccess()
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            await UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

// MARK: - Verify Code View (L3)

/// 8-digit code entry screen shown after email signup when verification is required.
struct VerifyCodeView: View {
    let email: String
    let onVerify: (String) async throws -> Void
    let onResend: () async -> Void
    let onBack: () -> Void

    private let codeLength = 8

    @State private var digits: [String] = Array(repeating: "", count: 8)
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendCooldown = 0
    @FocusState private var focusedIndex: Int?

    private var code: String { digits.joined() }
    private var isComplete: Bool { code.count == codeLength }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingNav(
                showBack: true,
                onBack: onBack
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.lbBlack)
                        .padding(.bottom, LBTheme.Spacing.xl)

                    Text("Enter verification code")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    Text("We sent a code to")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                    Text(email)
                        .font(LBTheme.Typography.bodyMedium)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.bottom, LBTheme.Spacing.xl)

                    // 6-digit code input
                    HStack(spacing: 8) {
                        ForEach(0..<codeLength, id: \.self) { index in
                            codeDigitField(index: index)
                        }
                    }
                    .padding(.bottom, LBTheme.Spacing.lg)

                    // Error
                    if let errorMessage {
                        Text(errorMessage)
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .padding(.bottom, LBTheme.Spacing.sm)
                    }

                    // Verify CTA
                    OnboardingCTA(
                        "Verify",
                        isLoading: isLoading,
                        isEnabled: isComplete
                    ) {
                        Task { await verify() }
                    }
                    .padding(.bottom, LBTheme.Spacing.lg)

                    // Resend
                    if resendCooldown > 0 {
                        Text("Resend code in \(resendCooldown)s")
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(Color.lbG400)
                    } else {
                        Button {
                            Task { await resend() }
                        } label: {
                            Text("Didn't get a code? Resend")
                                .font(LBTheme.Typography.caption)
                                .foregroundStyle(Color.lbBlack)
                        }
                    }
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.top, LBTheme.Spacing.xxxl)
            }
        }
        .onAppear { focusedIndex = 0 }
    }

    // MARK: - Digit Field

    private func codeDigitField(index: Int) -> some View {
        TextField("", text: $digits[index])
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.lbBlack)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focusedIndex, equals: index)
            .frame(width: 40, height: 48)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(
                        focusedIndex == index ? Color.lbBlack : Color.lbG200,
                        lineWidth: 1.5
                    )
            }
            .onChange(of: digits[index]) { _, newValue in
                handleDigitChange(index: index, value: newValue)
            }
    }

    private func handleDigitChange(index: Int, value: String) {
        // Only allow single digits
        if value.count > 1 {
            // Handle paste of full code
            let cleaned = value.filter(\.isNumber)
            if cleaned.count >= codeLength {
                for i in 0..<codeLength {
                    let charIndex = cleaned.index(cleaned.startIndex, offsetBy: i)
                    digits[i] = String(cleaned[charIndex])
                }
                focusedIndex = nil
                return
            }
            digits[index] = String(value.last ?? Character(""))
        }

        if value.isEmpty {
            // Deleted — move back to previous field
            if index > 0 {
                focusedIndex = index - 1
            }
        } else if index < codeLength - 1 {
            // Entered a digit — advance to next field
            focusedIndex = index + 1
        }
    }

    // MARK: - Actions

    private func verify() async {
        guard isComplete else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await onVerify(code)
        } catch {
            errorMessage = "Invalid code. Please try again."
            isLoading = false
        }
    }

    private func resend() async {
        resendCooldown = 60
        await onResend()

        // Countdown timer
        while resendCooldown > 0 {
            try? await Task.sleep(for: .seconds(1))
            resendCooldown -= 1
        }
    }
}

#Preview {
    AccountSetupView(authManager: .shared, coordinator: nil) {}
}
