import Foundation

// MARK: - User Service Errors

enum UserServiceError: Error, LocalizedError, Sendable {
    case languageMissing
    case levelMissing
    case syncFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .languageMissing:
            return "Please select a language before continuing."
        case .levelMissing:
            return "Please select a proficiency level before continuing."
        case .syncFailed(let underlying):
            return "Unable to save your progress: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - User Service

/// Wraps all user-related API calls through `APIClient`.
/// Uses actor isolation to ensure thread-safe access.
actor UserService {
    static let shared = UserService()

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Profile

    /// Fetches the current user profile.
    /// The backend auto-creates a user record on first call.
    ///
    /// `GET /v1/me`
    func getMe() async throws -> MeResponse {
        try await api.get("/me")
    }

    /// Updates the current user's mutable profile fields.
    /// Only non-nil fields in the update are applied.
    ///
    /// `PATCH /v1/me`
    func updateMe(_ update: UserUpdate) async throws -> UserResponse {
        try await api.patch("/me", body: update)
    }

    // MARK: - Languages

    /// Adds a new target language for the current user.
    /// Called during onboarding or when adding a second language later.
    ///
    /// `POST /v1/me/languages`
    func createLanguage(_ create: UserLanguageCreate) async throws -> UserLanguageResponse {
        try await api.post("/me/languages", body: create)
    }

    // MARK: - Home

    /// Fetches the aggregated home screen data.
    ///
    /// `GET /v1/home`
    func getHome() async throws -> HomeResponse {
        try await api.get("/home")
    }

    // MARK: - Settings

    /// Updates the current user's settings. Only non-nil fields are applied.
    ///
    /// `PATCH /v1/me/settings`
    func updateSettings(_ update: UserSettingsUpdate) async throws -> UserSettingsResponse {
        try await api.patch("/me/settings", body: update)
    }

    // MARK: - Language Updates

    /// Updates a specific language record for the current user.
    /// Can change CEFR level, interests, or set as active.
    ///
    /// `PATCH /v1/me/languages/:id`
    func updateLanguage(id: String, _ update: UserLanguageUpdate) async throws -> UserLanguageResponse {
        try await api.patch("/me/languages/\(id)", body: update)
    }

    /// Lists all target languages for the current user.
    ///
    /// `GET /v1/me/languages`
    func listLanguages() async throws -> [UserLanguageResponse] {
        try await api.get("/me/languages")
    }

    // MARK: - Onboarding Completion

    /// Marks onboarding as complete. Sends the daily goal and sets
    /// `onboarding_step = 8` and `onboarding_completed = true`.
    ///
    /// `PATCH /v1/me`
    func completeOnboarding(dailyGoalMinutes: Int) async throws -> UserResponse {
        let update = UserUpdate(
            dailyGoalMinutes: dailyGoalMinutes,
            onboardingStep: 8,
            onboardingCompleted: true
        )
        return try await updateMe(update)
    }

    /// Updates the onboarding step without completing onboarding.
    /// Called as the user progresses through each screen.
    ///
    /// `PATCH /v1/me`
    func updateOnboardingStep(_ step: Int) async throws -> UserResponse {
        let update = UserUpdate(onboardingStep: step)
        return try await updateMe(update)
    }

    // MARK: - Devices

    /// Registers an APNs device token for push notifications.
    ///
    /// `POST /v1/me/devices`
    func registerDevice(token: String) async throws {
        let body = DeviceTokenCreate(token: token)
        try await api.post("/me/devices", body: body)
    }
}
