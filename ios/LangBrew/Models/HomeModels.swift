import Foundation

// MARK: - Home Response (GET /v1/home)

/// Aggregated response returned by `GET /v1/home`.
/// Contains all data needed to render the home dashboard.
struct HomeResponse: Codable, Sendable {
    let user: HomeUser
    let activeLanguage: UserLanguageResponse?
    let cardsDue: Int
    let todaysPassage: [String: String]?
    let currentBook: [String: String]?
    let recentBooks: [[String: String]]
    let wordStats: WordStats
}

// MARK: - Home User

/// Subset of user data surfaced on the home screen.
struct HomeUser: Codable, Sendable {
    let name: String
    let avatarUrl: String?
    let currentStreak: Int
    let streakWeek: [Bool]
}

// MARK: - Word Stats

/// Vocabulary progress statistics for the home screen.
struct WordStats: Codable, Sendable {
    let total: Int
    let learning: Int
    let mastered: Int
}
