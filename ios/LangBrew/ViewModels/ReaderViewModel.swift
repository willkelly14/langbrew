import Foundation
import SwiftUI

// MARK: - Reading Theme

/// Visual themes for the reading experience.
enum ReadingTheme: String, Codable, Sendable, CaseIterable, Identifiable {
    case light
    case sepia
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: .lbWhite
        case .sepia: .lbLinen
        case .dark: Color(hex: "1a1814")
        }
    }

    var textColor: Color {
        switch self {
        case .light: .lbBlack
        case .sepia: .lbBlack
        case .dark: Color(hex: "e0dbd0")
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light: .lbG500
        case .sepia: .lbG500
        case .dark: Color(hex: "9e9385")
        }
    }

    var highlightColor: Color {
        switch self {
        case .light: .lbHighlight
        case .sepia: Color(hex: "e5dfca")
        case .dark: Color(hex: "3d3529")
        }
    }

    var navBarColor: Color {
        switch self {
        case .light: .lbWhite
        case .sepia: .lbLinen
        case .dark: Color(hex: "1a1814")
        }
    }
}

// MARK: - Reading Font

/// Font family preference for reading.
enum ReadingFont: String, Codable, Sendable, CaseIterable, Identifiable {
    case serif
    case sansSerif

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .serif: "Serif"
        case .sansSerif: "Sans-serif"
        }
    }
}

// MARK: - Line Spacing Option

/// Line spacing presets for reading comfort.
enum LineSpacingOption: String, Codable, Sendable, CaseIterable, Identifiable {
    case compact
    case normal
    case relaxed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .normal: "Normal"
        case .relaxed: "Relaxed"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .compact: 1.2
        case .normal: 1.5
        case .relaxed: 2.0
        }
    }
}

// MARK: - Word Addition State

/// Tracks the state of adding a word to the Language Bank.
enum WordAdditionState: Sendable, Equatable {
    case idle
    case added
    case undone
}

// MARK: - Reader View Model

/// Manages all state for the passage reader, including text display settings,
/// reading progress, word lookup, and vocabulary bank interactions.
@MainActor
@Observable
final class ReaderViewModel {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let fontSize = "lb_reader_fontSize"
        static let lineSpacing = "lb_reader_lineSpacing"
        static let readingFont = "lb_reader_font"
        static let readingTheme = "lb_reader_theme"
    }

    // MARK: - Passage Data

    let passage: PassageResponse
    let vocabulary: [PassageVocabulary]

    // MARK: - Reading Progress

    var readingProgress: Double = 0.0

    // MARK: - Text Display Settings

    var fontSize: CGFloat {
        didSet { UserDefaults.standard.set(Double(fontSize), forKey: Keys.fontSize) }
    }

    var lineSpacing: LineSpacingOption {
        didSet { UserDefaults.standard.set(lineSpacing.rawValue, forKey: Keys.lineSpacing) }
    }

    var readingFont: ReadingFont {
        didSet { UserDefaults.standard.set(readingFont.rawValue, forKey: Keys.readingFont) }
    }

    var readingTheme: ReadingTheme {
        didSet { UserDefaults.standard.set(readingTheme.rawValue, forKey: Keys.readingTheme) }
    }

    // MARK: - Sheet State

    var showTextOptions: Bool = false
    var showWordDefinition: Bool = false
    var showWordDetail: Bool = false
    var showPhrasePopup: Bool = false

    // MARK: - Word Lookup

    var selectedVocab: PassageVocabulary?
    var selectedWord: String?
    var isLoadingDefinition: Bool = false

    /// When a non-highlighted word is long-pressed, we create a temporary
    /// vocabulary entry with a lookup from the API.
    var lookedUpVocab: PassageVocabulary?

    // MARK: - Phrase Selection

    var selectedPhraseStart: Int?
    var selectedPhraseEnd: Int?
    var selectedPhrase: String?
    var phraseTranslation: PhraseTranslation?

    // MARK: - Language Bank

    var addedWords: Set<String> = []
    var wordAdditionState: WordAdditionState = .idle
    private var undoTask: Task<Void, Never>?

    // MARK: - Progress Debounce

    /// Task for debounced progress saving to the API.
    private var progressDebounceTask: Task<Void, Never>?

    // MARK: - Services

    private let passageService: PassageService

    // MARK: - Init

    init(
        passage: PassageResponse,
        vocabulary: [PassageVocabulary],
        passageService: PassageService = .shared
    ) {
        self.passage = passage
        self.vocabulary = vocabulary
        self.passageService = passageService

        // Restore saved preferences from UserDefaults.
        let defaults = UserDefaults.standard

        let savedFontSize = defaults.double(forKey: Keys.fontSize)
        self.fontSize = savedFontSize > 0 ? CGFloat(savedFontSize) : 18

        if let savedSpacing = defaults.string(forKey: Keys.lineSpacing),
           let spacing = LineSpacingOption(rawValue: savedSpacing) {
            self.lineSpacing = spacing
        } else {
            self.lineSpacing = .normal
        }

        if let savedFont = defaults.string(forKey: Keys.readingFont),
           let font = ReadingFont(rawValue: savedFont) {
            self.readingFont = font
        } else {
            self.readingFont = .serif
        }

        if let savedTheme = defaults.string(forKey: Keys.readingTheme),
           let theme = ReadingTheme(rawValue: savedTheme) {
            self.readingTheme = theme
        } else {
            self.readingTheme = .sepia
        }
    }

    // MARK: - Computed Properties

    /// The font used for passage body text, based on user preference.
    var bodyFont: Font {
        switch readingFont {
        case .serif:
            return LBTheme.serifFont(size: fontSize)
        case .sansSerif:
            return .system(size: fontSize)
        }
    }

    /// Computed line spacing in points.
    var lineSpacingValue: CGFloat {
        fontSize * (lineSpacing.multiplier - 1.0)
    }

    /// Vocabulary items that should be highlighted in the text.
    var highlightedVocabulary: [PassageVocabulary] {
        vocabulary.filter { $0.isHighlighted && !addedWords.contains($0.word) }
    }

    // MARK: - Word Actions

    /// Called when a highlighted word is tapped.
    func tapWord(_ vocab: PassageVocabulary) {
        selectedVocab = vocab
        selectedWord = vocab.word
        showWordDefinition = true
        wordAdditionState = addedWords.contains(vocab.word) ? .added : .idle
    }

    /// Called when any word is long-pressed.
    /// Attempts to fetch the definition from the API, falling back to
    /// a mock lookup if the API call fails.
    func longPressWord(_ word: String) {
        // Check if it matches a vocabulary annotation.
        if let vocab = vocabulary.first(where: { $0.word.lowercased() == word.lowercased() }) {
            selectedVocab = vocab
            selectedWord = vocab.word
            showWordDetail = true
            wordAdditionState = addedWords.contains(vocab.word) ? .added : .idle
        } else {
            // Look up via API (or fallback to mock).
            selectedWord = word
            selectedVocab = nil
            isLoadingDefinition = true
            showWordDetail = true

            Task {
                let vocab = await fetchDefinition(for: word)
                lookedUpVocab = vocab
                selectedVocab = vocab
                isLoadingDefinition = false
            }
        }
    }

    /// Adds the currently selected word to the Language Bank.
    /// Persists to the API in the background and gracefully ignores failures.
    func addWordToBank() {
        guard let word = selectedWord else { return }

        undoTask?.cancel()
        addedWords.insert(word)
        wordAdditionState = .added

        // Persist to API in the background.
        let vocab = selectedVocab
        Task {
            await addWordToAPI(word: word, vocab: vocab)
        }

        // Auto-dismiss undo state after 5 seconds.
        undoTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                wordAdditionState = .idle
            }
        }
    }

    /// Undoes adding the currently selected word.
    func undoAddWord() {
        guard let word = selectedWord else { return }
        undoTask?.cancel()
        addedWords.remove(word)
        wordAdditionState = .undone

        // Reset to idle after a short delay.
        Task {
            try? await Task.sleep(for: .seconds(1))
            wordAdditionState = .idle
        }
    }

    // MARK: - Phrase Actions

    /// Called when a phrase is selected by tapping two word boundaries.
    /// Fetches translation from the API, falling back to mock data.
    func selectPhrase(startIndex: Int, endIndex: Int) {
        selectedPhraseStart = startIndex
        selectedPhraseEnd = endIndex

        let content = passage.content
        let start = content.index(content.startIndex, offsetBy: min(startIndex, content.count))
        let end = content.index(content.startIndex, offsetBy: min(endIndex, content.count))
        selectedPhrase = String(content[start..<end])

        showPhrasePopup = true

        // Fetch translation from API.
        if let phrase = selectedPhrase {
            Task {
                await fetchTranslation(for: phrase)
            }
        }
    }

    /// Saves the currently selected phrase to the Language Bank.
    func savePhrase() {
        guard let phrase = selectedPhrase,
              let translation = phraseTranslation else {
            showPhrasePopup = false
            return
        }

        // Persist to API in the background.
        Task {
            let request = VocabularyItemCreate(
                text: phrase,
                translation: translation.translation,
                phonetic: nil,
                wordType: nil,
                definitions: nil,
                exampleSentence: nil,
                language: passage.language,
                type: "phrase",
                sourceType: "passage",
                sourceId: passage.id,
                contextSentence: translation.context
            )
            do {
                _ = try await passageService.addVocabularyItem(request)
            } catch {
                // Silently fail; the phrase was still shown to the user.
            }
        }

        showPhrasePopup = false
        selectedPhrase = nil
        phraseTranslation = nil
    }

    /// Dismisses any active selection or sheet.
    func dismissSheets() {
        showWordDefinition = false
        showWordDetail = false
        showPhrasePopup = false
        showTextOptions = false
        selectedVocab = nil
        selectedWord = nil
        lookedUpVocab = nil
        selectedPhrase = nil
        phraseTranslation = nil
    }

    // MARK: - Progress

    /// Updates reading progress based on scroll position.
    /// Debounces API calls to avoid excessive requests -- waits 2 seconds
    /// of inactivity before persisting to the server.
    func updateProgress(_ progress: Double) {
        readingProgress = min(max(progress, 0), 1)

        // Cancel any pending debounce.
        progressDebounceTask?.cancel()

        // Schedule a new debounced save.
        let passageId = passage.id
        let currentProgress = readingProgress
        let service = passageService
        progressDebounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            do {
                try await service.updatePassage(passageId, progress: currentProgress)
            } catch {
                // Silently fail progress save; don't interrupt reading.
            }
        }
    }

    // MARK: - Private Helpers

    /// Fetches a word definition from the API, falling back to a mock on failure.
    private func fetchDefinition(for word: String) async -> PassageVocabulary {
        let request = DefineRequest(
            word: word,
            language: passage.language,
            contextSentence: nil
        )

        do {
            let response = try await passageService.defineWord(request)
            return PassageVocabulary(
                id: "lookup-\(word)",
                passageId: passage.id,
                word: word,
                startIndex: 0,
                endIndex: word.count,
                isHighlighted: false,
                definition: response.definitions.first?.definition,
                translation: nil,
                phonetic: response.phonetic,
                wordType: response.wordType,
                exampleSentence: response.exampleSentence,
                conjugationHint: nil,
                definitions: response.definitions.map { def in
                    WordDefinition(
                        definition: def.definition,
                        example: def.example,
                        meaning: def.meaning
                    )
                },
                usageNotes: nil
            )
        } catch {
            // Fall back to mock lookup on API failure.
            return createMockLookup(for: word)
        }
    }

    /// Fetches a phrase translation from the API, falling back to mock data.
    private func fetchTranslation(for phrase: String) async {
        let request = TranslateRequest(
            text: phrase,
            sourceLanguage: passage.language,
            targetLanguage: "English",
            context: nil
        )

        do {
            let response = try await passageService.translatePhrase(request)
            phraseTranslation = PhraseTranslation(
                phrase: phrase,
                translation: response.translation,
                context: nil
            )
        } catch {
            // Fall back to mock translations on API failure.
            phraseTranslation = MockData.samplePhraseTranslations[phrase.lowercased()]
                ?? PhraseTranslation(
                    phrase: phrase,
                    translation: "[Translation for: \(phrase)]",
                    context: nil
                )
        }
    }

    /// Persists a word addition to the API. Fails silently.
    private func addWordToAPI(word: String, vocab: PassageVocabulary?) async {
        let request = VocabularyItemCreate(
            text: word,
            translation: vocab?.translation ?? "",
            phonetic: vocab?.phonetic,
            wordType: vocab?.wordType,
            definitions: vocab?.definitions,
            exampleSentence: vocab?.exampleSentence,
            language: passage.language,
            type: "word",
            sourceType: "passage",
            sourceId: passage.id,
            contextSentence: nil
        )

        do {
            _ = try await passageService.addVocabularyItem(request)
        } catch {
            // Silently fail; the word is still tracked locally.
        }
    }

    /// Creates a mock vocabulary entry for a non-highlighted word lookup.
    private func createMockLookup(for word: String) -> PassageVocabulary {
        PassageVocabulary(
            id: "lookup-\(word)",
            passageId: passage.id,
            word: word,
            startIndex: 0,
            endIndex: word.count,
            isHighlighted: false,
            definition: "Definition for \"\(word)\" would be fetched from the API.",
            translation: "[\(word) translation]",
            phonetic: "/\(word)/",
            wordType: "unknown",
            exampleSentence: "Example sentence using \"\(word)\" would appear here.",
            conjugationHint: nil,
            definitions: [
                WordDefinition(
                    definition: "Primary definition for \"\(word)\" would be fetched from the API.",
                    example: "An example sentence would appear here.",
                    meaning: nil
                ),
            ],
            usageNotes: nil
        )
    }
}
