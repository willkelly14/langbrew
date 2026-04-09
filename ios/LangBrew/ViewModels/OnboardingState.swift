import Foundation
import SwiftUI

// MARK: - Onboarding Step

/// Represents each step in the onboarding flow, used as NavigationStack path elements.
enum OnboardingStep: Int, Hashable, Codable, CaseIterable, Sendable {
    case splash = 0
    case welcome = 1
    case carousel = 2
    case languageSelection = 3
    case proficiency = 4
    case interests = 5
    case dailyGoal = 6
    case accountSetup = 7
    case choosePlan = 8
    case firstPassage = 9
    case login = 10
}

// MARK: - Onboarding State

/// Stores all onboarding selections and persists them to UserDefaults.
/// Acts as the single source of truth for the onboarding flow.
@MainActor
@Observable
final class OnboardingState {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let selectedLanguage = "lb_onboarding_selectedLanguage"
        static let selectedLevel = "lb_onboarding_selectedLevel"
        static let selectedInterests = "lb_onboarding_selectedInterests"
        static let dailyGoalMinutes = "lb_onboarding_dailyGoalMinutes"
        static let selectedPlan = "lb_onboarding_selectedPlan"
        static let onboardingStep = "lb_onboarding_step"
        static let onboardingCompleted = "lb_onboarding_completed"
        static let backendSynced = "lb_onboarding_backendSynced"
    }

    // MARK: - Stored Properties

    var selectedLanguage: String? {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: Keys.selectedLanguage) }
    }

    var selectedLevel: String? {
        didSet { UserDefaults.standard.set(selectedLevel, forKey: Keys.selectedLevel) }
    }

    var selectedInterests: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(selectedInterests), forKey: Keys.selectedInterests)
        }
    }

    var dailyGoalMinutes: Int {
        didSet { UserDefaults.standard.set(dailyGoalMinutes, forKey: Keys.dailyGoalMinutes) }
    }

    var selectedPlan: String {
        didSet { UserDefaults.standard.set(selectedPlan, forKey: Keys.selectedPlan) }
    }

    var currentStep: OnboardingStep {
        didSet { UserDefaults.standard.set(currentStep.rawValue, forKey: Keys.onboardingStep) }
    }

    var onboardingCompleted: Bool {
        didSet { UserDefaults.standard.set(onboardingCompleted, forKey: Keys.onboardingCompleted) }
    }

    /// Whether the onboarding data has been successfully synced to the backend.
    /// Used to retry sync on next launch if the initial attempt failed.
    var backendSynced: Bool {
        didSet { UserDefaults.standard.set(backendSynced, forKey: Keys.backendSynced) }
    }

    /// True while a backend sync is in progress.
    var isSyncing: Bool = false

    /// User-facing error from the most recent sync attempt, if any.
    var syncError: String?

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        self.selectedLanguage = defaults.string(forKey: Keys.selectedLanguage)
        self.selectedLevel = defaults.string(forKey: Keys.selectedLevel)

        if let interests = defaults.stringArray(forKey: Keys.selectedInterests) {
            self.selectedInterests = Set(interests)
        } else {
            self.selectedInterests = []
        }

        let goalMinutes = defaults.integer(forKey: Keys.dailyGoalMinutes)
        self.dailyGoalMinutes = goalMinutes > 0 ? goalMinutes : 10

        self.selectedPlan = defaults.string(forKey: Keys.selectedPlan) ?? "free"

        let stepRaw = defaults.integer(forKey: Keys.onboardingStep)
        self.currentStep = OnboardingStep(rawValue: stepRaw) ?? .splash

        self.onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
        self.backendSynced = defaults.bool(forKey: Keys.backendSynced)
    }

    // MARK: - Actions

    /// Marks onboarding as complete and persists the flag.
    func completeOnboarding() {
        onboardingCompleted = true
        currentStep = .firstPassage
    }

    /// Resets all onboarding data. Useful for testing or account deletion.
    func reset() {
        selectedLanguage = nil
        selectedLevel = nil
        selectedInterests = []
        dailyGoalMinutes = 10
        selectedPlan = "free"
        currentStep = .splash
        onboardingCompleted = false
        backendSynced = false
        syncError = nil
    }

    // MARK: - Backend Sync

    /// Syncs the onboarding selections to the backend.
    ///
    /// 1. Creates the user's target language via `POST /v1/me/languages`.
    /// 2. Marks onboarding complete via `PATCH /v1/me`.
    ///
    /// If the backend call fails, local state is still marked complete
    /// so the user can proceed. The `backendSynced` flag stays false and
    /// `AppCoordinator` will retry on next launch.
    func syncToBackend() async {
        guard let language = selectedLanguage else {
            syncError = UserServiceError.languageMissing.localizedDescription
            return
        }
        guard let level = selectedLevel else {
            syncError = UserServiceError.levelMissing.localizedDescription
            return
        }

        isSyncing = true
        syncError = nil

        let userService = UserService.shared

        do {
            // Step 1: Create the target language
            let languageCreate = UserLanguageCreate(
                targetLanguage: language,
                cefrLevel: level,
                interests: Array(selectedInterests)
            )
            _ = try await userService.createLanguage(languageCreate)

            // Step 2: Mark onboarding complete with daily goal
            _ = try await userService.completeOnboarding(dailyGoalMinutes: dailyGoalMinutes)

            backendSynced = true
        } catch {
            // Store the error for display but don't block the user.
            // Local state is already saved; we'll retry on next launch.
            syncError = UserServiceError.syncFailed(underlying: error).localizedDescription
        }

        isSyncing = false

        // Always mark local state as complete so the user can proceed.
        completeOnboarding()
    }

    /// Retries a previously failed backend sync.
    /// Called by `AppCoordinator` on launch if `backendSynced` is false
    /// but `onboardingCompleted` is true.
    func retrySyncIfNeeded() async {
        guard onboardingCompleted, !backendSynced else { return }

        guard selectedLanguage != nil, selectedLevel != nil else { return }

        let userService = UserService.shared

        do {
            let languageCreate = UserLanguageCreate(
                targetLanguage: selectedLanguage ?? "",
                cefrLevel: selectedLevel ?? "",
                interests: Array(selectedInterests)
            )
            _ = try await userService.createLanguage(languageCreate)
            _ = try await userService.completeOnboarding(dailyGoalMinutes: dailyGoalMinutes)
            backendSynced = true
            syncError = nil
        } catch {
            // Silent retry failure. Will try again on next launch.
        }
    }
}
