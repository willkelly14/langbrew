import Foundation

// MARK: - User Update (PATCH /v1/me)

/// Request body for `PATCH /v1/me`. All fields are optional;
/// only non-nil fields are sent to the server.
struct UserUpdate: Codable, Sendable {
    var firstName: String?
    var dailyGoalMinutes: Int?
    var newWordsPerDay: Int?
    var autoAdjustDifficulty: Bool?
    var timezone: String?
    var onboardingStep: Int?
    var onboardingCompleted: Bool?

    /// Returns true when every field is nil (nothing to send).
    var isEmpty: Bool {
        firstName == nil
            && dailyGoalMinutes == nil
            && newWordsPerDay == nil
            && autoAdjustDifficulty == nil
            && timezone == nil
            && onboardingStep == nil
            && onboardingCompleted == nil
    }
}

// MARK: - User Language Create (POST /v1/me/languages)

/// Request body for `POST /v1/me/languages`.
struct UserLanguageCreate: Codable, Sendable {
    let targetLanguage: String
    let cefrLevel: String
    let interests: [String]
}

// MARK: - User Settings Update (PATCH /v1/me/settings)

/// Request body for `PATCH /v1/me/settings`. All fields are optional;
/// only non-nil fields are sent to the server.
struct UserSettingsUpdate: Codable, Sendable {
    // Reading
    var readingTheme: String?
    var readingFont: String?
    var fontSize: Int?
    var lineSpacing: String?
    var vocabularyHighlights: Bool?
    var autoPlayAudio: Bool?
    var highlightFollowing: Bool?
    var preferredVoiceId: String?
    var voiceSpeed: Double?

    // Talk
    var talkVoiceStyle: String?
    var talkCorrectionStyle: String?
    var showTranscript: Bool?
    var autoSaveWords: Bool?
    var sessionLengthMinutes: Int?

    // Flashcards
    var reviewsPerSession: Int?
    var showExampleSentence: Bool?
    var audioOnReveal: Bool?

    // Notifications
    var notificationsEnabled: Bool?
    var reminderTime: String?
    var streakAlerts: Bool?
    var reviewReminder: Bool?
}

// MARK: - User Language Update (PATCH /v1/me/languages/:id)

/// Request body for `PATCH /v1/me/languages/:id`. All fields are optional;
/// only non-nil fields are sent to the server.
struct UserLanguageUpdate: Codable, Sendable {
    var cefrLevel: String?
    var interests: [String]?
    var isActive: Bool?
    var readingLevel: String?
    var speakingLevel: String?
    var listeningLevel: String?
}

// MARK: - Delete Account (DELETE /v1/me/account)

/// Request body for `DELETE /v1/me/account`.
struct DeleteAccountRequest: Codable, Sendable {
    let confirmation: String
}

// MARK: - Device Token Create (POST /v1/me/devices)

/// Request body for `POST /v1/me/devices`.
struct DeviceTokenCreate: Codable, Sendable {
    let token: String
    let platform: String

    init(token: String, platform: String = "ios") {
        self.token = token
        self.platform = platform
    }
}
