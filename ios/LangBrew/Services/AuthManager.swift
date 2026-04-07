import Foundation
import SwiftUI

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

/// Manages authentication state and token lifecycle.
/// Wraps Supabase Auth for Apple/Google/email sign-in.
///
/// Note: Actual Supabase integration is wired in Milestone 1.
/// For now, methods are placeholders that store tokens in UserDefaults.
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

    private let tokenKey = "com.langbrew.accessToken"
    private let userIdKey = "com.langbrew.userId"

    // TODO: Migrate token storage to Keychain for production security.
    // UserDefaults is used here for MVP simplicity only.

    private init() {
        // Restore persisted session on launch
        self.accessToken = UserDefaults.standard.string(forKey: tokenKey)
        self.currentUserId = UserDefaults.standard.string(forKey: userIdKey)
        self.isAuthenticated = accessToken != nil
    }

    // MARK: - Sign In

    /// Sign in with Apple. Delegates to Supabase Auth.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func signInWithApple() async throws -> String {
        // TODO: Integrate supabase-swift Apple Sign In (Milestone 1)
        // let session = try await supabase.auth.signInWithApple()
        // persistSession(session)
        throw AuthError.signInFailed(underlying: NSError(
            domain: "AuthManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Apple Sign In not yet implemented."]
        ))
    }

    /// Sign in with Google. Delegates to Supabase Auth.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func signInWithGoogle() async throws -> String {
        // TODO: Integrate supabase-swift Google Sign In (Milestone 1)
        throw AuthError.signInFailed(underlying: NSError(
            domain: "AuthManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Google Sign In not yet implemented."]
        ))
    }

    /// Sign in with email and password. Delegates to Supabase Auth.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func signInWithEmail(email: String, password: String) async throws -> String {
        // TODO: Integrate supabase-swift email/password auth (Milestone 1)
        throw AuthError.signInFailed(underlying: NSError(
            domain: "AuthManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Email Sign In not yet implemented."]
        ))
    }

    /// Create a new account with email and password. Delegates to Supabase Auth.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Returns: The user's UUID on success.
    @discardableResult
    func signUpWithEmail(email: String, password: String) async throws -> String {
        // TODO: Integrate supabase-swift email/password signup (Milestone 1)
        throw AuthError.signInFailed(underlying: NSError(
            domain: "AuthManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Email Sign Up not yet implemented."]
        ))
    }

    // MARK: - Sign Out

    /// Signs the user out and clears all stored credentials.
    func signOut() async throws {
        // TODO: Call supabase.auth.signOut() (Milestone 1)
        clearSession()
    }

    // MARK: - Token Refresh

    /// Refreshes the JWT access token using the stored refresh token.
    func refreshToken() async throws {
        // TODO: Integrate supabase-swift token refresh (Milestone 1)
        // let session = try await supabase.auth.refreshSession()
        // persistSession(session)
        throw AuthError.tokenRefreshFailed
    }

    // MARK: - Session Persistence

    private func persistSession(userId: String, token: String) {
        self.currentUserId = userId
        self.accessToken = token
        self.isAuthenticated = true
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(userId, forKey: userIdKey)
    }

    private func clearSession() {
        self.currentUserId = nil
        self.accessToken = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
    }
}
