import Foundation

// MARK: - Composite Response (GET /v1/me)

/// Matches the backend `MeResponse` schema returned by `GET /v1/me`.
/// Contains the user profile, active language (if any), and settings.
struct MeResponse: Codable, Sendable {
    let user: UserResponse
    let activeLanguage: UserLanguageResponse?
    let settings: UserSettingsResponse?
}

// MARK: - User

/// Matches the backend `UserResponse` Pydantic schema.
struct UserResponse: Codable, Sendable {
    let id: String
    let supabaseUid: String
    let email: String
    let name: String
    let avatarUrl: String?
    let nativeLanguage: String
    let subscriptionTier: String
    let dailyGoalMinutes: Int
    let newWordsPerDay: Int
    let autoAdjustDifficulty: Bool
    let timezone: String
    let currentStreak: Int
    let onboardingCompleted: Bool
    let onboardingStep: Int
    let createdAt: String
    let updatedAt: String
}

// MARK: - User Language

/// Matches the backend `UserLanguageResponse` Pydantic schema.
struct UserLanguageResponse: Codable, Sendable {
    let id: String
    let userId: String
    let targetLanguage: String
    let cefrLevel: String
    let readingLevel: String?
    let speakingLevel: String?
    let listeningLevel: String?
    let interests: [String]
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
}

// MARK: - User Settings

/// Matches the backend `UserSettingsResponse` Pydantic schema.
/// Contains all 22 user preference fields plus metadata.
struct UserSettingsResponse: Codable, Sendable {
    let id: String
    let userId: String

    // Reading
    let readingTheme: String
    let readingFont: String
    let fontSize: Int
    let lineSpacing: String
    let vocabularyHighlights: Bool
    let autoPlayAudio: Bool
    let highlightFollowing: Bool
    let preferredVoiceId: String?
    let voiceSpeed: Double

    // Talk
    let talkVoiceStyle: String
    let talkCorrectionStyle: String
    let showTranscript: Bool
    let autoSaveWords: Bool
    let sessionLengthMinutes: Int

    // Flashcards
    let reviewsPerSession: Int
    let showExampleSentence: Bool
    let audioOnReveal: Bool

    // Notifications
    let notificationsEnabled: Bool
    let reminderTime: String?
    let streakAlerts: Bool
    let reviewReminder: Bool

    let createdAt: String
    let updatedAt: String
}
