import Foundation
import SwiftUI

// MARK: - Language Bank Tab

/// The three content types within the Language Bank.
enum LanguageBankTab: String, CaseIterable, Identifiable, Sendable {
    case words = "Words"
    case phrases = "Phrases"
    case sentences = "Sentences"

    var id: String { rawValue }

    /// Placeholder text for the search bar.
    var searchPlaceholder: String {
        switch self {
        case .words: "Search..."
        case .phrases: "Search phrases..."
        case .sentences: "Search sentences..."
        }
    }

    /// The API type parameter value for this tab.
    var apiType: String {
        switch self {
        case .words: "word"
        case .phrases: "phrase"
        case .sentences: "sentence"
        }
    }
}

// MARK: - Vocabulary Status

/// The learning status of a vocabulary item.
enum VocabStatus: String, CaseIterable, Identifiable, Sendable {
    case new = "new"
    case known = "known"
    case mastered = "mastered"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: "New"
        case .known: "Known"
        case .mastered: "Mastered"
        }
    }

    /// Background color for the status pill in the word list.
    var pillBackground: Color {
        switch self {
        case .new: Color(hex: "f2f0d1")
        case .known: Color(hex: "dde8dd")
        case .mastered: Color(hex: "dbdbe8")
        }
    }

    /// Border color for the active status button in the detail sheet.
    var activeBorderColor: Color {
        switch self {
        case .new: Color(hex: "d4c95a")
        case .known: Color(hex: "7aab7a")
        case .mastered: Color(hex: "8a8abd")
        }
    }

    /// Creates a VocabStatus from an API status string, mapping "learning" to "new".
    static func from(apiStatus: String) -> VocabStatus {
        switch apiStatus.lowercased() {
        case "new", "learning": return .new
        case "known": return .known
        case "mastered": return .mastered
        default: return .new
        }
    }
}

// MARK: - Status Filter

/// Filter options for the vocabulary list.
enum VocabFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case new = "New"
    case known = "Known"
    case mastered = "Mastered"

    var id: String { rawValue }

    /// The corresponding VocabStatus, if any (nil for "All").
    var vocabStatus: VocabStatus? {
        switch self {
        case .all: nil
        case .new: .new
        case .known: .known
        case .mastered: .mastered
        }
    }

    /// The API status parameter value for this filter (nil for "All").
    var apiStatus: String? {
        switch self {
        case .all: nil
        case .new: "new"
        case .known: "known"
        case .mastered: "mastered"
        }
    }
}

// MARK: - Language Bank Item

/// A vocabulary item displayed in the Language Bank list and detail sheet.
struct LanguageBankItem: Identifiable, Sendable {
    let id: String
    let text: String
    let translation: String
    let phonetic: String?
    let wordType: String?
    let definition: String?
    let exampleSentence: String?
    var status: VocabStatus
    let type: LanguageBankTab
    let timesReviewed: Int
    let accuracy: Int
    let passageCount: Int

    /// Display string for the word type and detail (e.g., "Noun . Plural").
    var posLabel: String? {
        wordType
    }

    /// Creates a LanguageBankItem from a VocabularyListItem API response.
    init(from vocab: VocabularyListItem) {
        self.id = vocab.id
        self.text = vocab.text
        self.translation = vocab.translation
        self.phonetic = vocab.phonetic
        self.wordType = vocab.wordType
        self.definition = nil
        self.exampleSentence = nil
        self.status = VocabStatus.from(apiStatus: vocab.status)
        switch vocab.type.lowercased() {
        case "phrase": self.type = .phrases
        case "sentence": self.type = .sentences
        default: self.type = .words
        }
        self.timesReviewed = vocab.timesReviewed
        let reviewed = vocab.timesReviewed
        let correct = vocab.timesCorrect
        self.accuracy = reviewed > 0 ? Int(Double(correct) / Double(reviewed) * 100) : 0
        self.passageCount = 0
    }

    /// Creates a LanguageBankItem from a VocabularyItem (full detail) API response.
    init(from vocab: VocabularyItem) {
        self.id = vocab.id
        self.text = vocab.text
        self.translation = vocab.translation
        self.phonetic = vocab.phonetic
        self.wordType = vocab.wordType
        self.definition = vocab.definitions?.first?.definition
        self.exampleSentence = vocab.exampleSentence
        self.status = VocabStatus.from(apiStatus: vocab.status)
        switch vocab.type.lowercased() {
        case "phrase": self.type = .phrases
        case "sentence": self.type = .sentences
        default: self.type = .words
        }
        self.timesReviewed = vocab.timesReviewed
        let reviewed = vocab.timesReviewed
        let correct = vocab.timesCorrect
        self.accuracy = reviewed > 0 ? Int(Double(correct) / Double(reviewed) * 100) : 0
        self.passageCount = 0
    }

    /// Internal initializer for mock data and direct construction.
    init(
        id: String,
        text: String,
        translation: String,
        phonetic: String?,
        wordType: String?,
        definition: String?,
        exampleSentence: String?,
        status: VocabStatus,
        type: LanguageBankTab,
        timesReviewed: Int,
        accuracy: Int,
        passageCount: Int
    ) {
        self.id = id
        self.text = text
        self.translation = translation
        self.phonetic = phonetic
        self.wordType = wordType
        self.definition = definition
        self.exampleSentence = exampleSentence
        self.status = status
        self.type = type
        self.timesReviewed = timesReviewed
        self.accuracy = accuracy
        self.passageCount = passageCount
    }
}

// MARK: - Language Bank Stats

/// Computed statistics for the current tab and items.
struct LanguageBankStats: Sendable {
    let total: Int
    let new: Int
    let known: Int
    let mastered: Int
}

// MARK: - Language Bank View Model

@MainActor
@Observable
final class LanguageBankViewModel {

    // MARK: - State

    var selectedTab: LanguageBankTab = .words
    var selectedFilter: VocabFilter = .all
    var searchText: String = ""
    var selectedItem: LanguageBankItem?
    var activeFlag: String = FlagMapper.flag(for: "es")

    // MARK: - Loading State

    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Data

    private(set) var allItems: [LanguageBankItem] = []
    private(set) var vocabStats: VocabularyStatsResponse?

    // MARK: - Pagination

    private var nextCursor: String?
    private var hasMorePages: Bool = true

    // MARK: - Dependencies

    private let flashcardService: FlashcardService
    private let passageService: PassageService

    init(
        flashcardService: FlashcardService = .shared,
        passageService: PassageService = .shared
    ) {
        self.flashcardService = flashcardService
        self.passageService = passageService
    }

    // MARK: - Computed Properties

    /// Items for the currently selected tab, filtered by status and search text.
    var filteredItems: [LanguageBankItem] {
        var items = allItems.filter { $0.type == selectedTab }

        // Apply status filter
        if let status = selectedFilter.vocabStatus {
            items = items.filter { $0.status == status }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter {
                $0.text.lowercased().contains(query)
                || $0.translation.lowercased().contains(query)
            }
        }

        return items
    }

    /// Stats for the currently selected tab.
    /// Uses API stats when available, falls back to local count.
    var stats: LanguageBankStats {
        if let apiStats = vocabStats {
            return LanguageBankStats(
                total: apiStats.total,
                new: apiStats.new + apiStats.learning,
                known: apiStats.known,
                mastered: apiStats.mastered
            )
        }
        let tabItems = allItems.filter { $0.type == selectedTab }
        return LanguageBankStats(
            total: tabItems.count,
            new: tabItems.filter { $0.status == .new }.count,
            known: tabItems.filter { $0.status == .known }.count,
            mastered: tabItems.filter { $0.status == .mastered }.count
        )
    }

    // MARK: - Actions

    /// Loads vocabulary items from the API.
    func loadItems() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await flashcardService.listVocabulary(
                type: selectedTab.apiType,
                status: selectedFilter.apiStatus,
                limit: 50
            )
            allItems = response.items.map { LanguageBankItem(from: $0) }
            nextCursor = response.nextCursor
            hasMorePages = response.nextCursor != nil
        } catch {
            errorMessage = error.localizedDescription
            print("[LanguageBankVM] Failed to load items: \(error)")
        }

        isLoading = false
    }

    /// Loads vocabulary stats from the API.
    func loadStats() async {
        do {
            vocabStats = try await flashcardService.getVocabularyStats()
        } catch {
            print("[LanguageBankVM] Failed to load stats: \(error)")
        }
    }

    /// Loads more items when scrolling (pagination).
    func loadMoreIfNeeded() async {
        guard hasMorePages, let cursor = nextCursor, !isLoading else { return }

        do {
            let response = try await flashcardService.listVocabulary(
                type: selectedTab.apiType,
                status: selectedFilter.apiStatus,
                cursor: cursor,
                limit: 50
            )
            let newItems = response.items.map { LanguageBankItem(from: $0) }
            allItems.append(contentsOf: newItems)
            nextCursor = response.nextCursor
            hasMorePages = response.nextCursor != nil
        } catch {
            print("[LanguageBankVM] Failed to load more: \(error)")
        }
    }

    /// Reloads data when tab or filter changes.
    func reloadForCurrentTab() async {
        nextCursor = nil
        hasMorePages = true
        await loadItems()
        await loadStats()
    }

    /// Update the status of the selected item via the API.
    func updateStatus(_ newStatus: VocabStatus) {
        guard let item = selectedItem else { return }

        // Optimistic UI update
        if let index = allItems.firstIndex(where: { $0.id == item.id }) {
            allItems[index].status = newStatus
            selectedItem = allItems[index]
        }

        Task {
            do {
                _ = try await flashcardService.updateVocabulary(
                    id: item.id,
                    status: newStatus.rawValue
                )
                // Refresh stats after status change
                await loadStats()
            } catch {
                print("[LanguageBankVM] Failed to update status: \(error)")
                // Revert on failure
                if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                    allItems[index].status = item.status
                    selectedItem = allItems[index]
                }
            }
        }
    }

    /// Remove the selected item from the bank via the API.
    func removeSelectedItem() {
        guard let item = selectedItem else { return }

        // Optimistic UI update
        allItems.removeAll { $0.id == item.id }
        selectedItem = nil

        Task {
            do {
                try await passageService.removeVocabularyItem(item.id)
                // Refresh stats after removal
                await loadStats()
            } catch {
                print("[LanguageBankVM] Failed to remove item: \(error)")
                // Reload to restore correct state
                await loadItems()
            }
        }
    }

    // MARK: - Mock Data for Previews

    #if DEBUG
    static func preview() -> LanguageBankViewModel {
        let vm = LanguageBankViewModel()
        vm.allItems = LanguageBankViewModel.generateMockData()
        return vm
    }

    static func generateMockData() -> [LanguageBankItem] {
        var items: [LanguageBankItem] = []

        let words: [(String, String, String?, String?, String?, String?, VocabStatus, Int, Int, Int)] = [
            ("vendedores", "sellers, vendors", "/ben.de.do.\u{027E}es/", "Noun \u{00B7} Plural",
             "Sellers, vendors \u{2014} people who sell goods at a market or shop",
             "Los vendedores gritan los precios de sus frutas.", .new, 5, 80, 2),
            ("mercado", "market", "/me\u{027E}.\u{02C8}ka.do/", "Noun \u{00B7} Masculine",
             "A public place where goods are bought and sold.",
             "El mercado est\u{00E1} lleno de colores y sonidos.", .known, 12, 92, 4),
        ]

        for (i, w) in words.enumerated() {
            items.append(LanguageBankItem(
                id: "word-\(i)", text: w.0, translation: w.1, phonetic: w.2,
                wordType: w.3, definition: w.4, exampleSentence: w.5,
                status: w.6, type: .words, timesReviewed: w.7,
                accuracy: w.8, passageCount: w.9
            ))
        }

        return items
    }
    #endif
}
