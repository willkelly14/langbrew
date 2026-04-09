import Foundation
import SwiftUI

// MARK: - Home Language Item

/// A language item for the home screen language switcher.
struct HomeLanguageItem: Identifiable, Sendable {
    let id: String
    let language: String
    let flag: String
    let cefrLevel: String
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
        // Immediately populate active language from coordinator cache
        // so the flag shows correctly before the API responds.
        if let lang = coordinator.currentUser?.activeLanguage {
            activeLanguage = lang.targetLanguage
            activeLanguageLevel = lang.cefrLevel
        } else if let lang = coordinator.onboardingState.selectedLanguage {
            // Fall back to the language selected during onboarding (UserDefaults)
            activeLanguage = lang
            activeLanguageLevel = coordinator.onboardingState.selectedLevel ?? "A1"
        }
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

        // If activeLanguage is still empty after the API call,
        // refresh coordinator and try to populate from cache.
        if activeLanguage.isEmpty {
            await refreshCoordinatorUser()
            populateFromCoordinator()
        }

        // Ensure languages list is populated for the picker.
        if languages.isEmpty {
            await fetchLanguagesList()
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
        userName = response.user.firstName
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
        } else if activeLanguage.isEmpty, let lang = coordinator.currentUser?.activeLanguage {
            // API didn't return activeLanguage — use coordinator cache
            activeLanguage = lang.targetLanguage
            activeLanguageLevel = lang.cefrLevel
        }

    }

    /// Populates basic fields from the coordinator's cached `MeResponse`
    /// when the home endpoint is unavailable.
    private func populateFromCoordinator() {
        guard let me = coordinator.currentUser else { return }
        userName = me.user.firstName
        avatarUrl = me.user.avatarUrl
        currentStreak = me.user.currentStreak

        if let lang = me.activeLanguage {
            activeLanguage = lang.targetLanguage
            activeLanguageLevel = lang.cefrLevel
        }
    }

    /// Builds the language picker list from the coordinator's cached active language,
    /// falling back to the onboarding UserDefaults if the API hasn't loaded yet.
    private func populateLanguagesFromCoordinator() {
        guard languages.isEmpty else { return }

        if let lang = coordinator.currentUser?.activeLanguage {
            languages = [
                HomeLanguageItem(
                    id: lang.id,
                    language: lang.targetLanguage,
                    flag: FlagMapper.flag(for: lang.targetLanguage),
                    cefrLevel: lang.cefrLevel
                )
            ]
        } else if let code = coordinator.onboardingState.selectedLanguage {
            languages = [
                HomeLanguageItem(
                    id: "local",
                    language: code,
                    flag: FlagMapper.flag(for: code),
                    cefrLevel: coordinator.onboardingState.selectedLevel ?? "A1"
                )
            ]
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
                    flag: FlagMapper.flag(for: lang.targetLanguage),
                    cefrLevel: lang.cefrLevel
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
                        flag: FlagMapper.flag(for: lang.targetLanguage),
                        cefrLevel: lang.cefrLevel
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
