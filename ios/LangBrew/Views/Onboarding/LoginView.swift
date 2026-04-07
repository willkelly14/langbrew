import SwiftUI

/// L1 -- Login screen for returning users.
/// Matches the mockup: back button, title, Apple/Google buttons, or divider,
/// email/password fields, Sign In CTA, forgot password, bottom link.
struct LoginView: View {
    let authManager: AuthManager
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
                // Nav bar (back only, no skip)
                OnboardingNav(
                    showBack: true,
                    onBack: { dismiss() }
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title
                        Text("Welcome back.")
                            .font(LBTheme.Typography.title)
                            .foregroundStyle(Color.lbBlack)
                            .padding(.bottom, LBTheme.Spacing.sm)

                        Text("Sign in to continue learning.")
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
                            textContentType: .password
                        )

                        // Error
                        if let errorMessage {
                            Text(errorMessage)
                                .font(LBTheme.Typography.caption)
                                .foregroundStyle(.red)
                                .padding(.top, LBTheme.Spacing.sm)
                        }

                        // Sign In CTA
                        OnboardingCTA("Sign In", isLoading: isLoading) {
                            Task { await handleEmailLogin() }
                        }
                        .padding(.top, LBTheme.Spacing.md)

                        // Forgot password
                        Button {
                            // TODO: Navigate to forgot password
                        } label: {
                            Text("Forgot password?")
                                .font(LBTheme.Typography.caption)
                                .foregroundStyle(Color.lbG400)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, LBTheme.Spacing.md)

                        Spacer(minLength: LBTheme.Spacing.xxxl)
                    }
                    .padding(.horizontal, LBTheme.Spacing.xl)
                    .padding(.top, LBTheme.Spacing.xl)
                }

                // Bottom link
                VStack {
                    (Text("Don't have an account? ")
                        .font(.system(size: 13))
                        .foregroundColor(Color.lbG400)
                     + Text("Get started")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.lbNearBlack))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, LBTheme.Spacing.md)
                .onTapGesture { dismiss() }
            }
        }
    }

    // MARK: - Actions

    private func handleAuth(perform: @escaping () -> Void) async {
        isLoading = true
        errorMessage = nil

        try? await Task.sleep(for: .milliseconds(500))
        perform()

        isLoading = false
        onSuccess()
    }

    private func handleEmailLogin() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }

        await handleAuth { authManager.mockSignIn() }
    }
}

#Preview {
    LoginView(authManager: .shared) {}
}
