import Foundation

// MARK: - User Update (PATCH /v1/me)

/// Request body for `PATCH /v1/me`. All fields are optional;
/// only non-nil fields are sent to the server.
struct UserUpdate: Codable, Sendable {
    var name: String?
    var dailyGoalMinutes: Int?
    var newWordsPerDay: Int?
    var autoAdjustDifficulty: Bool?
    var timezone: String?
    var onboardingStep: Int?
    var onboardingCompleted: Bool?

    /// Returns true when every field is nil (nothing to send).
    var isEmpty: Bool {
        name == nil
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
