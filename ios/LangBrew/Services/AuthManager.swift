import AuthenticationServices
import Auth
import Foundation
import SwiftUI
import UIKit

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case signInFailed(underlying: Error)
    case signOutFailed(underlying: Error)
    case tokenRefreshFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in."
        case .signInFailed(let underlying):
            return "Sign in failed: \(underlying.localizedDescription)"
        case .signOutFailed(let underlying):
            return "Sign out failed: \(underlying.localizedDescription)"
        case .tokenRefreshFailed:
            return "Unable to refresh your session. Please sign in again."
        }
    }
}

// MARK: - Auth Manager

/// Manages authentication state and token lifecycle via Supabase Auth.
@MainActor
@Observable
final class AuthManager: Sendable {
    static let shared = AuthManager()

    // MARK: - State

    /// Whether the user is currently authenticated.
    private(set) var isAuthenticated: Bool = false

    /// The authenticated user's Supabase UUID, or nil.
    private(set) var currentUserId: String?

    /// The current JWT access token for API calls.
    private(set) var accessToken: String?

    // MARK: - Private

    private let authClient: AuthClient

    private init() {
        self.authClient = AuthClient(
            url: SupabaseConfig.projectURL.appendingPathComponent("/auth/v1"),
            headers: ["apikey": SupabaseConfig.anonKey],
            localStorage: AuthTokenStore()
        )

        // Restore persisted session on launch
        Task { await restoreSession() }
    }

    // MARK: - Session Restoration

    /// Attempts to restore a previous session from stored tokens.
    private func restoreSession() async {
        do {
            let session = try await authClient.session
            applySession(session)
        } catch {
            // No stored session or it's expired
            clearState()
        }
    }

    // MARK: - Sign In with Apple

    /// Sign in with Apple via Supabase Auth.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func signInWithApple() async throws -> String {
        do {
            let session = try await authClient.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: try await getAppleIdToken()
                )
            )
            applySession(session)
            return session.user.id.uuidString
        } catch {
            throw AuthError.signInFailed(underlying: error)
        }
    }

    /// Sign in with Google via Supabase Auth using OAuth flow.
    /// Presents an ASWebAuthenticationSession for the user to authenticate.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func signInWithGoogle() async throws -> String {
        do {
            let redirectURL = URL(string: "com.langbrew.app://auth-callback")!
            let session = try await authClient.signInWithOAuth(
                provider: .google,
                redirectTo: redirectURL
            ) { @MainActor url in
                try await withCheckedThrowingContinuation { continuation in
                    let authSession = ASWebAuthenticationSession(
                        url: url,
                        callback: .customScheme("com.langbrew.app")
                    ) { callbackURL, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let callbackURL {
                            continuation.resume(returning: callbackURL)
                        } else {
                            continuation.resume(throwing: AuthError.signInFailed(
                                underlying: NSError(
                                    domain: "AuthManager",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Google sign in was cancelled."]
                                )
                            ))
                        }
                    }
                    authSession.prefersEphemeralWebBrowserSession = false
                    authSession.presentationContextProvider = OAuthPresentationContext.shared
                    authSession.start()
                }
            }
            applySession(session)
            return session.user.id.uuidString
        } catch {
            throw AuthError.signInFailed(underlying: error)
        }
    }

    /// Handles the OAuth callback URL from a deep link.
    /// Call this from your scene delegate or onOpenURL handler.
    func handleOAuthCallback(url: URL) async throws {
        let session = try await authClient.session(from: url)
        applySession(session)
    }

    /// Sign in with email and password via Supabase Auth.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func signInWithEmail(email: String, password: String) async throws -> String {
        do {
            let session = try await authClient.signIn(
                email: email,
                password: password
            )
            applySession(session)
            return session.user.id.uuidString
        } catch {
            throw AuthError.signInFailed(underlying: error)
        }
    }

    /// Whether the most recent sign-up requires email confirmation.
    /// When true, the UI should show a verification prompt instead of proceeding.
    private(set) var pendingEmailConfirmation: Bool = false

    /// The email address awaiting confirmation, if any.
    private(set) var pendingEmail: String?

    /// Create a new account with email and password via Supabase Auth.
    /// If email confirmation is required, sets `pendingEmailConfirmation = true`
    /// and returns the user ID without establishing a full session.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func signUpWithEmail(email: String, password: String) async throws -> String {
        pendingEmailConfirmation = false
        pendingEmail = nil

        do {
            let response = try await authClient.signUp(
                email: email,
                password: password
            )

            // Supabase returns an empty identities array when the email already exists
            // (to prevent email enumeration). Detect this and show a clear error.
            let user = response.user
            if let identities = user.identities, identities.isEmpty {
                throw AuthError.signInFailed(underlying: NSError(
                    domain: "AuthManager",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "An account with this email already exists. Please sign in instead."]
                ))
            }

            if let session = response.session {
                applySession(session)
                return session.user.id.uuidString
            }
            // Email confirmation required — flag it so the UI can show a verification screen
            pendingEmailConfirmation = true
            pendingEmail = email
            return user.id.uuidString
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.signInFailed(underlying: error)
        }
    }

    /// Verifies a 6-digit OTP code sent to the user's email during signup.
    /// - Parameters:
    ///   - email: The email address the code was sent to.
    ///   - code: The 6-digit verification code.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func verifySignUpCode(email: String, code: String) async throws -> String {
        do {
            let response = try await authClient.verifyOTP(
                email: email,
                token: code,
                type: .signup
            )
            if let session = response.session {
                applySession(session)
                pendingEmailConfirmation = false
                pendingEmail = nil
                return session.user.id.uuidString
            }
            return response.user.id.uuidString
        } catch {
            throw AuthError.signInFailed(underlying: error)
        }
    }

    /// Resends the signup verification code to the given email.
    func resendSignUpCode(email: String) async throws {
        try await authClient.resend(email: email, type: .signup)
    }

    /// Clears the pending email confirmation state.
    func clearPendingConfirmation() {
        pendingEmailConfirmation = false
        pendingEmail = nil
    }

    // MARK: - Password Reset

    /// Sends a password reset OTP code to the given email.
    func sendPasswordReset(email: String) async throws {
        try await authClient.resetPasswordForEmail(email)
    }

    /// Verifies a password reset OTP code and establishes a session.
    func verifyPasswordResetCode(email: String, code: String) async throws {
        let response = try await authClient.verifyOTP(
            email: email,
            token: code,
            type: .recovery
        )
        if let session = response.session {
            applySession(session)
        }
    }

    /// Updates the user's password. Must be called after verifying the reset code.
    func updatePassword(_ newPassword: String) async throws {
        _ = try await authClient.update(user: UserAttributes(password: newPassword))
    }

    // MARK: - Sign Out

    /// Signs the user out and clears all stored credentials.
    func signOut() async throws {
        do {
            try await authClient.signOut()
        } catch {
            // Clear local state even if server-side sign out fails
        }
        clearState()
    }

    // MARK: - Token Refresh

    /// Refreshes the JWT access token using the stored refresh token.
    func refreshToken() async throws {
        do {
            let session = try await authClient.refreshSession()
            applySession(session)
        } catch {
            clearState()
            throw AuthError.tokenRefreshFailed
        }
    }

    // MARK: - Private Helpers

    private func applySession(_ session: Session) {
        self.currentUserId = session.user.id.uuidString
        self.accessToken = session.accessToken
        self.isAuthenticated = true
    }

    private func clearState() {
        self.currentUserId = nil
        self.accessToken = nil
        self.isAuthenticated = false
    }

    /// Performs Apple Sign In via ASAuthorizationController and returns the ID token.
    private func getAppleIdToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInDelegate(continuation: continuation)
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate

            // Keep delegate alive until the callback completes
            AppleSignInDelegate.current = delegate

            controller.performRequests()
        }
    }
}

// MARK: - Apple Sign In Delegate

/// Handles the ASAuthorizationController callback for Apple Sign In.
private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, @unchecked Sendable {
    static var current: AppleSignInDelegate?

    private let continuation: CheckedContinuation<String, Error>

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { AppleSignInDelegate.current = nil }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8)
        else {
            continuation.resume(throwing: NSError(
                domain: "AppleSignIn",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get Apple ID token."]
            ))
            return
        }

        continuation.resume(returning: idToken)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { AppleSignInDelegate.current = nil }
        continuation.resume(throwing: error)
    }
}

// MARK: - OAuth Presentation Context

/// Provides the presentation anchor for ASWebAuthenticationSession.
private final class OAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    static let shared = OAuthPresentationContext()

    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Auth Token Store

/// Persists Supabase auth tokens to UserDefaults.
/// TODO: Migrate to Keychain for production security.
private struct AuthTokenStore: AuthLocalStorage, Sendable {
    private let prefix = "com.langbrew.supabase."

    func retrieve(key: String) throws -> Data? {
        UserDefaults.standard.data(forKey: prefix + key)
    }

    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: prefix + key)
    }

    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: prefix + key)
    }
}
