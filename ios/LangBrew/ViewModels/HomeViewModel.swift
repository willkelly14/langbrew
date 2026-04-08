import Foundation
import SwiftUI

// MARK: - Home Language Item

/// A language item for the home screen language switcher.
struct HomeLanguageItem: Identifiable, Sendable {
    let id: String
    let language: String
    let flag: String
}

// MARK: - Home View Model

/// View model for the Home screen. Fetches data from `GET /v1/home`
/// and populates the dashboard. Falls back to defaults on error.
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - User Info

    var userName: String = ""
    var avatarUrl: String? = nil

    // MARK: - Streak

    var currentStreak: Int = 0
    var streakWeek: [Bool] = [false, false, false, false, false, false, false]

    // MARK: - Quick Actions

    var cardsDue: Int = 0

    // MARK: - Content (empty states for now)

    var todaysPassage: String? = nil
    var currentBook: String? = nil
    var recentBooks: [String] = []

    // MARK: - Word Stats

    var wordStatsTotal: Int = 0
    var wordStatsLearning: Int = 0
    var wordStatsMastered: Int = 0

    // MARK: - Language

    var activeLanguage: String = ""
    var activeLanguageLevel: String = ""
    var languages: [HomeLanguageItem] = []

    // MARK: - UI State

    var isLoading: Bool = false
    var showLanguagePicker: Bool = false
    var errorMessage: String? = nil

    // MARK: - Dependencies

    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        // Populate the language list from the coordinator's cached user data.
        populateLanguagesFromCoordinator()
    }

    // MARK: - Computed

    /// Returns a greeting based on the current hour.
    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    /// The flag emoji for the active language.
    var activeFlag: String {
        FlagMapper.flag(for: activeLanguage)
    }

    // MARK: - Actions

    /// Loads home screen data from the backend.
    /// Falls back to coordinator's cached user data on error.
    func loadHome() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await UserService.shared.getHome()
            applyHomeResponse(response)
        } catch {
            // Log but don't crash. Use whatever data we already have.
            errorMessage = error.localizedDescription
            print("[HomeViewModel] Failed to load home: \(error)")

            // Fall back to coordinator's cached user data if we have no data yet.
            if userName.isEmpty {
                populateFromCoordinator()
            }
        }

        isLoading = false
    }

    /// Switches the active language by calling the backend,
    /// then reloads home data to reflect the change.
    func switchLanguage(id: String) {
        guard let item = languages.first(where: { $0.id == id }) else { return }
        showLanguagePicker = false

        // Optimistically update the UI
        activeLanguage = item.language

        Task {
            do {
                let update = UserLanguageUpdate(isActive: true)
                _ = try await UserService.shared.updateLanguage(id: id, update)
                // Reload home data to get the updated state
                await loadHome()
                // Also refresh the coordinator's cached user
                await refreshCoordinatorUser()
            } catch {
                print("[HomeViewModel] Failed to switch language: \(error)")
                // Reload to restore the correct state
                await loadHome()
            }
        }
    }

    // MARK: - Private Helpers

    /// Maps a `HomeResponse` into view model properties.
    private func applyHomeResponse(_ response: HomeResponse) {
        userName = response.user.name
        avatarUrl = response.user.avatarUrl
        currentStreak = response.user.currentStreak
        streakWeek = response.user.streakWeek
        cardsDue = response.cardsDue
        wordStatsTotal = response.wordStats.total
        wordStatsLearning = response.wordStats.learning
        wordStatsMastered = response.wordStats.mastered

        if let lang = response.activeLanguage {
            activeLanguage = lang.targetLanguage
            activeLanguageLevel = lang.cefrLevel
        }

        // Update languages list from the coordinator if available
        populateLanguagesFromCoordinator()
    }

    /// Populates basic fields from the coordinator's cached `MeResponse`
    /// when the home endpoint is unavailable.
    private func populateFromCoordinator() {
        guard let me = coordinator.currentUser else { return }
        userName = me.user.name
        avatarUrl = me.user.avatarUrl
        currentStreak = me.user.currentStreak

        if let lang = me.activeLanguage {
            activeLanguage = lang.targetLanguage
            activeLanguageLevel = lang.cefrLevel
        }

        populateLanguagesFromCoordinator()
    }

    /// Builds the language picker list from the coordinator's user languages.
    private func populateLanguagesFromCoordinator() {
        // Try to get languages from a separate API call or coordinator cache.
        // For now, use coordinator's active language as a starting point
        // and fetch the full list in the background.
        if languages.isEmpty {
            Task {
                await fetchLanguagesList()
            }
        }
    }

    /// Fetches the user's language list from the backend.
    private func fetchLanguagesList() async {
        do {
            let userLanguages = try await UserService.shared.listLanguages()
            languages = userLanguages.map { lang in
                HomeLanguageItem(
                    id: lang.id,
                    language: lang.targetLanguage,
                    flag: FlagMapper.flag(for: lang.targetLanguage)
                )
            }
        } catch {
            print("[HomeViewModel] Failed to fetch languages: \(error)")
            // If we have an active language from the coordinator, use that as fallback
            if let lang = coordinator.currentUser?.activeLanguage, languages.isEmpty {
                languages = [
                    HomeLanguageItem(
                        id: lang.id,
                        language: lang.targetLanguage,
                        flag: FlagMapper.flag(for: lang.targetLanguage)
                    )
                ]
            }
        }
    }

    /// Refreshes the coordinator's cached user data after a change.
    private func refreshCoordinatorUser() async {
        await coordinator.refreshUser()
    }
}
