import Foundation
import SwiftUI

// MARK: - Settings View Model

/// View model for the Settings screen. Loads data from `MeResponse` and
/// persists changes to the backend via `UserService`.
@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Profile

    var userName: String = ""
    var email: String = ""
    var avatarUrl: String? = nil
    var subscriptionTier: String = "free"

    // MARK: - Learning

    var dailyGoalMinutes: Int = 10
    var newWordsPerDay: Int = 5
    var autoAdjustDifficulty: Bool = true

    // MARK: - Active Language

    var activeLanguage: String = ""
    var activeLanguageLevel: String = ""
    var activeLanguageInterests: [String] = []
    var activeLanguageId: String? = nil

    // MARK: - Reading Settings

    var readingTheme: String = "light"
    var readingFont: String = "system"
    var fontSize: Int = 16
    var lineSpacing: String = "normal"
    var vocabularyHighlights: Bool = true
    var autoPlayAudio: Bool = false
    var highlightFollowing: Bool = true
    var preferredVoiceId: String? = nil
    var voiceSpeed: Double = 1.0

    // MARK: - Talk Settings

    var talkVoiceStyle: String = "Natural"
    var talkCorrectionStyle: String = "Gentle"
    var showTranscript: Bool = true
    var autoSaveWords: Bool = true
    var sessionLengthMinutes: Int = 10

    // MARK: - Flashcard Settings

    var reviewsPerSession: Int = 20
    var showExampleSentence: Bool = true
    var audioOnReveal: Bool = false

    // MARK: - Notification Settings

    var notificationsEnabled: Bool = true
    var reminderTime: String? = "09:00"
    var streakAlerts: Bool = true
    var reviewReminder: Bool = true

    // MARK: - UI State

    var isLoading: Bool = false
    var showSignOutConfirmation: Bool = false
    var shouldSignOut: Bool = false

    // MARK: - Dependencies

    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        loadFromCoordinator()
    }

    // MARK: - Computed

    /// The flag emoji for the active language.
    /// Falls back through: coordinator cache → onboarding UserDefaults.
    var activeFlag: String {
        let code: String
        if !activeLanguage.isEmpty {
            code = activeLanguage
        } else if let lang = coordinator.currentUser?.activeLanguage?.targetLanguage {
            code = lang
        } else if let lang = coordinator.onboardingState.selectedLanguage {
            code = lang
        } else {
            code = ""
        }
        return FlagMapper.flag(for: code)
    }

    /// The display name for the active language.
    var activeLanguageName: String {
        FlagMapper.languageName(for: activeLanguage)
    }

    /// Formatted subscription tier display string.
    var subscriptionDisplay: String {
        switch subscriptionTier {
        case "free": return "Free Plan"
        case "pro": return "Pro Plan"
        case "premium": return "Premium Plan"
        default: return subscriptionTier.capitalized
        }
    }

    /// Formatted reminder time for display.
    var reminderTimeDisplay: String {
        guard let time = reminderTime else { return "Not set" }
        // Convert "09:00" format to "9:00 AM" display
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return time
        }
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    // MARK: - Load from Coordinator

    /// Populates all fields from the coordinator's cached `MeResponse`,
    /// falling back to onboarding UserDefaults for the active language.
    func loadFromCoordinator() {
        if let me = coordinator.currentUser {
            let user = me.user
            userName = user.firstName
            email = user.email
            avatarUrl = user.avatarUrl
            subscriptionTier = user.subscriptionTier
            dailyGoalMinutes = user.dailyGoalMinutes
            newWordsPerDay = user.newWordsPerDay
            autoAdjustDifficulty = user.autoAdjustDifficulty

            if let lang = me.activeLanguage {
                activeLanguage = lang.targetLanguage
                activeLanguageLevel = lang.cefrLevel
                activeLanguageInterests = lang.interests
                activeLanguageId = lang.id
            }

            if let settings = me.settings {
                readingTheme = settings.readingTheme
                readingFont = settings.readingFont
                fontSize = settings.fontSize
                lineSpacing = settings.lineSpacing
                vocabularyHighlights = settings.vocabularyHighlights
                autoPlayAudio = settings.autoPlayAudio
                highlightFollowing = settings.highlightFollowing
                preferredVoiceId = settings.preferredVoiceId
                voiceSpeed = settings.voiceSpeed

                talkVoiceStyle = settings.talkVoiceStyle
                talkCorrectionStyle = settings.talkCorrectionStyle
                showTranscript = settings.showTranscript
                autoSaveWords = settings.autoSaveWords
                sessionLengthMinutes = settings.sessionLengthMinutes

                reviewsPerSession = settings.reviewsPerSession
                showExampleSentence = settings.showExampleSentence
                audioOnReveal = settings.audioOnReveal

                notificationsEnabled = settings.notificationsEnabled
                reminderTime = settings.reminderTime
                streakAlerts = settings.streakAlerts
                reviewReminder = settings.reviewReminder
            }
        }

        // Fall back to onboarding state if activeLanguage is still empty
        if activeLanguage.isEmpty, let code = coordinator.onboardingState.selectedLanguage {
            activeLanguage = code
            activeLanguageLevel = coordinator.onboardingState.selectedLevel ?? "A1"
        }
    }

    // MARK: - Profile Actions

    /// Updates the user's display name on the backend.
    func updateProfile(name: String) {
        userName = name
        Task {
            do {
                _ = try await UserService.shared.updateMe(UserUpdate(firstName: name))
                await coordinator.refreshUser()
            } catch {
                print("[SettingsViewModel] Failed to update name: \(error)")
            }
        }
    }

    /// Updates the daily goal minutes on the backend.
    func updateDailyGoal(_ minutes: Int) {
        dailyGoalMinutes = minutes
        Task {
            do {
                _ = try await UserService.shared.updateMe(
                    UserUpdate(dailyGoalMinutes: minutes)
                )
                await coordinator.refreshUser()
            } catch {
                print("[SettingsViewModel] Failed to update daily goal: \(error)")
            }
        }
    }

    /// Updates the new words per day setting on the backend.
    func updateNewWordsPerDay(_ count: Int) {
        newWordsPerDay = count
        Task {
            do {
                _ = try await UserService.shared.updateMe(
                    UserUpdate(newWordsPerDay: count)
                )
                await coordinator.refreshUser()
            } catch {
                print("[SettingsViewModel] Failed to update new words per day: \(error)")
            }
        }
    }

    /// Updates the auto-adjust difficulty setting on the backend.
    func updateAutoAdjustDifficulty(_ enabled: Bool) {
        autoAdjustDifficulty = enabled
        Task {
            do {
                _ = try await UserService.shared.updateMe(
                    UserUpdate(autoAdjustDifficulty: enabled)
                )
                await coordinator.refreshUser()
            } catch {
                print("[SettingsViewModel] Failed to update auto-adjust: \(error)")
            }
        }
    }

    // MARK: - Settings Actions (Reading / Talk / Notifications)

    /// Updates vocabulary highlights setting on the backend.
    func updateVocabularyHighlights(_ enabled: Bool) {
        vocabularyHighlights = enabled
        persistSettingsUpdate(UserSettingsUpdate(vocabularyHighlights: enabled))
    }

    /// Updates auto-play audio setting on the backend.
    func updateAutoPlayAudio(_ enabled: Bool) {
        autoPlayAudio = enabled
        persistSettingsUpdate(UserSettingsUpdate(autoPlayAudio: enabled))
    }

    /// Updates highlight following setting on the backend.
    func updateHighlightFollowing(_ enabled: Bool) {
        highlightFollowing = enabled
        persistSettingsUpdate(UserSettingsUpdate(highlightFollowing: enabled))
    }

    /// Updates notifications enabled setting on the backend.
    func updateNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        persistSettingsUpdate(UserSettingsUpdate(notificationsEnabled: enabled))
    }

    /// Updates show example sentence setting on the backend.
    func updateShowExampleSentence(_ enabled: Bool) {
        showExampleSentence = enabled
        persistSettingsUpdate(UserSettingsUpdate(showExampleSentence: enabled))
    }

    /// Updates audio on reveal setting on the backend.
    func updateAudioOnReveal(_ enabled: Bool) {
        audioOnReveal = enabled
        persistSettingsUpdate(UserSettingsUpdate(audioOnReveal: enabled))
    }

    // MARK: - Language Actions

    /// Updates the CEFR level for the active language on the backend.
    func updateLanguageLevel(_ level: String) {
        guard let languageId = activeLanguageId else { return }
        activeLanguageLevel = level
        Task {
            do {
                _ = try await UserService.shared.updateLanguage(
                    id: languageId,
                    UserLanguageUpdate(cefrLevel: level)
                )
                await coordinator.refreshUser()
            } catch {
                print("[SettingsViewModel] Failed to update language level: \(error)")
            }
        }
    }

    // MARK: - Sign Out

    /// Triggers the sign-out flow through the coordinator.
    func signOut() {
        shouldSignOut = true
    }

    /// Performs the actual sign-out via AppCoordinator.
    func performSignOut() async {
        await coordinator.signOut()
    }

    // MARK: - Private Helpers

    /// Sends a settings update to the backend. Fire-and-forget.
    private func persistSettingsUpdate(_ update: UserSettingsUpdate) {
        Task {
            do {
                _ = try await UserService.shared.updateSettings(update)
                await coordinator.refreshUser()
            } catch {
                print("[SettingsViewModel] Failed to update settings: \(error)")
            }
        }
    }
}
