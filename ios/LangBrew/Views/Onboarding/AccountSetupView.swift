import SwiftUI
import UserNotifications

/// O6 -- Account setup. Step 5 of 5.
/// Back + "Later" nav, progress bar (100%), Apple/Google buttons, or divider,
/// email + password inputs, "Create Account" CTA, terms text.
struct AccountSetupView: View {
    let authManager: AuthManager
    let coordinator: AppCoordinator?
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav - "Later" instead of "Skip"
                OnboardingNav(
                    showBack: true,
                    rightLabel: "Later",
                    onBack: { dismiss() },
                    onRight: { onSuccess() }
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
                            Task { await handleAuth { authManager.mockSignIn() } }
                        }
                        .padding(.bottom, 10)

                        // Google button
                        AuthButton(style: .google) {
                            Task { await handleAuth { authManager.mockSignIn() } }
                        }

                        // Divider
                        AuthDivider()

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
            }
        }
    }

    // MARK: - Actions

    private func handleAuth(perform: @escaping () -> Void) async {
        isLoading = true
        errorMessage = nil

        try? await Task.sleep(for: .milliseconds(500))
        perform()

        // Fetch user profile from backend
        if let coordinator {
            await coordinator.handlePostAuthentication()
            if coordinator.phase == .main {
                isLoading = false
                return
            }
        }

        // Request notification permission
        await requestNotificationPermission()

        isLoading = false
        onSuccess()
    }

    private func handleEmailSignUp() async {
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

        await handleAuth { authManager.mockSignIn() }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }
}

#Preview {
    AccountSetupView(authManager: .shared, coordinator: nil) {}
}
