import Foundation
import SwiftUI

// MARK: - App Phase

/// Represents the top-level navigation state of the app.
enum AppPhase: Sendable, Equatable {
    /// Initial launch: checking auth and fetching user profile.
    case loading
    /// The user has not completed onboarding.
    case onboarding
    /// The user is authenticated and onboarding is complete.
    case main
}

// MARK: - App Coordinator

/// Determines which top-level view to show based on auth and onboarding state.
/// On launch, checks the stored token, fetches the user profile from the backend,
/// and routes to the correct screen (loading -> onboarding or main).
@MainActor
@Observable
final class AppCoordinator {
    let authManager: AuthManager
    let onboardingState: OnboardingState

    /// The current user profile fetched from the backend, if available.
    private(set) var currentUser: MeResponse?

    /// User-facing error from the most recent profile fetch, if any.
    private(set) var loadError: String?

    /// The resolved navigation phase. Starts as `.loading` until the
    /// initial check completes, then transitions to `.onboarding` or `.main`.
    private(set) var phase: AppPhase = .loading

    init(
        authManager: AuthManager = .shared,
        onboardingState: OnboardingState = OnboardingState()
    ) {
        self.authManager = authManager
        self.onboardingState = onboardingState
    }

    // MARK: - Launch Check

    /// Called once on app launch (from ContentView's `.task` modifier).
    /// Determines the correct phase based on stored auth and backend state.
    func checkInitialState() async {
        // No stored token: go straight to onboarding.
        guard authManager.isAuthenticated else {
            phase = .onboarding
            return
        }

        // We have a token. Try to fetch the user profile from the backend.
        do {
            let me = try await UserService.shared.getMe()
            currentUser = me

            if me.user.onboardingCompleted {
                // Onboarding was completed (possibly on another device).
                // Sync local state to match.
                onboardingState.onboardingCompleted = true
                onboardingState.backendSynced = true
                phase = .main
            } else {
                // Onboarding is in progress. Resume at the saved step.
                resumeOnboarding(from: me.user)
                phase = .onboarding
            }
        } catch {
            // Backend unreachable. Fall back to local state.
            loadError = error.localizedDescription
            resolvePhaseFromLocalState()
        }

        // If onboarding was completed locally but never synced, retry now.
        if onboardingState.onboardingCompleted && !onboardingState.backendSynced {
            await onboardingState.retrySyncIfNeeded()
        }
    }

    // MARK: - Post-Authentication

    /// Called after a successful sign-in (real or mock).
    /// Fetches the user profile and decides whether to continue
    /// onboarding or skip to the main app.
    func handlePostAuthentication() async {
        do {
            let me = try await UserService.shared.getMe()
            currentUser = me

            if me.user.onboardingCompleted {
                onboardingState.onboardingCompleted = true
                onboardingState.backendSynced = true
                phase = .main
            }
            // If onboarding is not complete, the user stays in the
            // onboarding flow. The caller handles navigation.
        } catch {
            // Backend unreachable after auth. Continue with local flow.
            // The user can still complete onboarding locally; sync later.
            loadError = error.localizedDescription
        }
    }

    // MARK: - Refresh User

    /// Re-fetches the current user profile from the backend and updates
    /// the cached `currentUser`. Called after mutations (e.g. language switch,
    /// profile update) so other screens can observe the change.
    func refreshUser() async {
        do {
            let me = try await UserService.shared.getMe()
            currentUser = me
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Transition to Main

    /// Called when the user finishes onboarding (taps "Start Learning").
    /// Transitions the app to the main phase.
    func transitionToMain() {
        phase = .main
    }

    // MARK: - Sign Out

    /// Signs out and resets to the onboarding phase.
    func signOut() async {
        try? await authManager.signOut()
        currentUser = nil
        onboardingState.reset()
        phase = .onboarding
    }

    // MARK: - Account Deletion

    /// Signs out, clears all local data, and resets to onboarding.
    /// Called after the backend has successfully deleted the account.
    func deleteAccountAndSignOut() async {
        try? await authManager.signOut()
        currentUser = nil
        onboardingState.reset()

        // Clear any cached data from UserDefaults
        let defaults = UserDefaults.standard
        let keysToRemove = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("com.langbrew.")
                || $0.hasPrefix("lb_")
        }
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }

        phase = .onboarding
    }

    // MARK: - Private Helpers

    /// Maps the backend `onboarding_step` to the local `OnboardingStep`
    /// and updates `OnboardingState` so the flow can resume.
    private func resumeOnboarding(from user: UserResponse) {
        // The backend stores onboarding_step as 0-8.
        // Map to our local OnboardingStep enum.
        if let step = OnboardingStep(rawValue: user.onboardingStep) {
            onboardingState.currentStep = step
        }
    }

    /// When the backend is unreachable, determine the phase from local state.
    private func resolvePhaseFromLocalState() {
        if authManager.isAuthenticated && onboardingState.onboardingCompleted {
            phase = .main
        } else {
            phase = .onboarding
        }
    }
}
