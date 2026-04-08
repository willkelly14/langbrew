import Foundation
import SwiftUI

// MARK: - Sort Option

/// Available sort options for the passages list.
enum PassageSortOption: String, Sendable, CaseIterable, Identifiable {
    case date = "Date"
    case difficulty = "Difficulty"
    case topic = "Topic"

    var id: String { rawValue }

    /// The query parameter value sent to the API.
    var apiValue: String {
        switch self {
        case .date: "date"
        case .difficulty: "difficulty"
        case .topic: "topic"
        }
    }
}

// MARK: - Library View Model

/// Manages state for the Library tab including passages list, filtering,
/// search, and the passage generation flow.
@MainActor
@Observable
final class LibraryViewModel {

    // MARK: - Passages State

    /// All passages available to the user.
    private(set) var passages: [PassageResponse] = []

    /// Whether passages are currently loading.
    private(set) var isLoading: Bool = false

    /// Error message to display, if any.
    private(set) var errorMessage: String?

    /// The ID of the most recently generated passage, used for navigation.
    private(set) var generatedPassageId: String?

    // MARK: - Search & Filter

    /// Current search query entered by the user.
    var searchQuery: String = ""

    /// The currently selected CEFR level filter. Nil means "All".
    var selectedLevel: CEFRLevel?

    /// The current sort option.
    var sortOption: PassageSortOption = .date

    // MARK: - Generate Sheet

    /// Whether the generate passage bottom sheet is presented.
    var isGenerateSheetPresented: Bool = false

    /// The selected generation mode (auto or custom).
    var generateMode: GenerateMode = .auto

    /// Selected topics for auto mode.
    var selectedAutoTopics: Set<String> = []

    /// Custom topic text for custom mode.
    var customTopic: String = ""

    /// Selected style for custom mode.
    var selectedStyle: PassageStyle = .story

    /// Selected length for custom mode.
    var selectedLength: PassageLength = .medium

    /// Selected difficulty for custom mode.
    var selectedDifficulty: CEFRLevel = .a2

    // MARK: - Loading State

    /// Whether the passage generation loading screen is shown.
    var isGenerating: Bool = false

    // MARK: - Upgrade Sheet

    /// Whether the upgrade prompt should be shown (402 from API).
    var showUpgradeSheet: Bool = false

    // MARK: - Pagination

    /// Cursor for the next page of results. Nil means no more pages.
    private var nextCursor: String?

    /// Whether more pages are available.
    var hasMorePages: Bool { nextCursor != nil }

    // MARK: - Private

    private let passageService: PassageService

    // MARK: - Init

    init(passageService: PassageService = .shared) {
        self.passageService = passageService
    }

    // MARK: - Computed Properties

    /// Passages filtered and sorted based on current search, level, and sort settings.
    var filteredPassages: [PassageResponse] {
        var result = passages

        // Apply search filter
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { passage in
                passage.title.lowercased().contains(query)
                    || passage.content.lowercased().contains(query)
                    || passage.topic.lowercased().contains(query)
            }
        }

        // Apply CEFR level filter
        if let level = selectedLevel {
            result = result.filter { $0.cefrLevel == level.rawValue }
        }

        // Apply sort
        switch sortOption {
        case .date:
            result.sort { $0.createdAt > $1.createdAt }
        case .difficulty:
            let order = CEFRLevel.allCases.map(\.rawValue)
            result.sort { a, b in
                let indexA = order.firstIndex(of: a.cefrLevel) ?? 0
                let indexB = order.firstIndex(of: b.cefrLevel) ?? 0
                return indexA < indexB
            }
        case .topic:
            result.sort { $0.topic < $1.topic }
        }

        return result
    }

    /// Whether there are no passages at all (not just filtered to empty).
    var hasNoPassages: Bool {
        passages.isEmpty
    }

    /// Whether the generate button should be enabled.
    var canGenerate: Bool {
        switch generateMode {
        case .auto:
            return !selectedAutoTopics.isEmpty
        case .custom:
            return !customTopic.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Actions

    /// Loads passages from the API with current filter settings.
    /// Falls back to mock data in DEBUG when the API is unavailable.
    func loadPassages() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await passageService.listPassages(
                search: searchQuery.isEmpty ? nil : searchQuery,
                cefrLevel: selectedLevel?.rawValue,
                sortBy: sortOption.apiValue
            )
            passages = response.items
            nextCursor = response.cursor
        } catch {
            #if DEBUG
            // Fall back to mock data when backend is unavailable during development.
            if passages.isEmpty {
                passages = MockPassageData.passages
            }
            #else
            errorMessage = error.localizedDescription
            #endif
        }

        isLoading = false
    }

    /// Loads the next page of passages (cursor-based pagination).
    func loadMorePassages() async {
        guard let cursor = nextCursor, !isLoading else { return }

        do {
            let response = try await passageService.listPassages(
                search: searchQuery.isEmpty ? nil : searchQuery,
                cefrLevel: selectedLevel?.rawValue,
                sortBy: sortOption.apiValue,
                cursor: cursor
            )
            passages.append(contentsOf: response.items)
            nextCursor = response.cursor
        } catch {
            // Silently fail pagination; the user still has existing passages.
        }
    }

    /// Refreshes the passages list from scratch (pull-to-refresh).
    func refreshPassages() async {
        nextCursor = nil
        await loadPassages()
    }

    /// Initiates passage generation with the current settings.
    /// Streams SSE events to show progress, then adds the completed passage.
    func generatePassage() async {
        isGenerateSheetPresented = false
        isGenerating = true
        generatedPassageId = nil
        errorMessage = nil

        let topic: String
        let level: String
        let style: String
        let length: String

        switch generateMode {
        case .auto:
            topic = selectedAutoTopics.first ?? "Daily Life"
            level = "A2"
            style = "story"
            length = "medium"
        case .custom:
            topic = customTopic.trimmingCharacters(in: .whitespaces)
            level = selectedDifficulty.rawValue
            style = selectedStyle.rawValue
            length = selectedLength.rawValue
        }

        let request = GeneratePassageRequest(
            mode: generateMode.rawValue,
            topic: topic,
            cefrLevel: level,
            style: style,
            length: length
        )

        do {
            let stream = await passageService.generatePassage(request: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            for try await event in stream {
                // The final "complete" event contains the full passage JSON.
                if event.event == "complete" || event.data == "[DONE]" {
                    // Try to decode the passage from the complete event.
                    if event.data != "[DONE]",
                       let data = event.data.data(using: .utf8),
                       let passage = try? decoder.decode(PassageResponse.self, from: data) {
                        passages.insert(passage, at: 0)
                        generatedPassageId = passage.id
                    }
                }
                // Other events (e.g., "progress", "token") are consumed
                // to keep the stream alive. The loading view handles
                // visual feedback independently.
            }

            // If we got here without a passage from SSE, refresh the list
            // to pick up the newly generated passage from the server.
            if generatedPassageId == nil {
                await refreshPassages()
                generatedPassageId = passages.first?.id
            }
        } catch let error as APIError {
            switch error {
            case .usageLimitExceeded:
                showUpgradeSheet = true
            default:
                #if DEBUG
                // Fall back to mock generation during development.
                let newPassage = MockPassageData.createGeneratedPassage(
                    topic: topic,
                    cefrLevel: level,
                    style: style,
                    length: length
                )
                passages.insert(newPassage, at: 0)
                generatedPassageId = newPassage.id
                #else
                errorMessage = error.localizedDescription
                #endif
            }
        } catch {
            #if DEBUG
            // Fall back to mock generation during development.
            let newPassage = MockPassageData.createGeneratedPassage(
                topic: topic,
                cefrLevel: level,
                style: style,
                length: length
            )
            passages.insert(newPassage, at: 0)
            generatedPassageId = newPassage.id
            #else
            errorMessage = error.localizedDescription
            #endif
        }

        resetGenerateForm()
        isGenerating = false
    }

    /// Deletes a passage by ID.
    func deletePassage(_ id: String) async {
        do {
            try await passageService.deletePassage(id)
            passages.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Toggles a topic selection in auto mode.
    func toggleAutoTopic(_ topic: String) {
        if selectedAutoTopics.contains(topic) {
            selectedAutoTopics.remove(topic)
        } else {
            selectedAutoTopics.insert(topic)
        }
    }

    /// Opens the generate sheet.
    func showGenerateSheet() {
        resetGenerateForm()
        isGenerateSheetPresented = true
    }

    /// Dismisses the error message.
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private

    /// Resets the generate form to default values.
    private func resetGenerateForm() {
        generateMode = .auto
        selectedAutoTopics = []
        customTopic = ""
        selectedStyle = .story
        selectedLength = .medium
        selectedDifficulty = .a2
    }
}
