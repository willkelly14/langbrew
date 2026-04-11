import Foundation
import SwiftUI

// MARK: - Reading Font

/// Font family preference for reading.
enum ReadingFont: String, Codable, Sendable, CaseIterable, Identifiable {
    case sans
    case serif
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sans: "Sans"
        case .serif: "Serif"
        case .mono: "Mono"
        }
    }

    /// The sample text font shown in the Text Options sheet.
    func sampleFont(size: CGFloat) -> Font {
        switch self {
        case .sans: .system(size: size)
        case .serif: LBTheme.serifFont(size: size)
        case .mono: .system(size: size, design: .monospaced)
        }
    }

    /// The body text font for the reader.
    func bodyFont(size: CGFloat) -> Font {
        switch self {
        case .sans: .system(size: size)
        case .serif: LBTheme.serifFont(size: size)
        case .mono: .system(size: size, design: .monospaced)
        }
    }
}

// MARK: - Line Spacing Option

/// Line spacing presets for reading comfort.
enum LineSpacingOption: String, Codable, Sendable, CaseIterable, Identifiable {
    case compact
    case `default`
    case relaxed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .default: "Default"
        case .relaxed: "Relaxed"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .compact: 1.2
        case .default: 1.5
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

    // MARK: - Sentence Translation (Long Press)

    /// The sentence extracted from the passage that contains the long-pressed word.
    var selectedSentence: String?
    /// Character range (start, end) of the selected sentence in the passage content.
    var selectedSentenceRange: (start: Int, end: Int)?
    /// Translation of the selected sentence.
    var sentenceTranslation: String?
    /// Whether a sentence translation is being fetched.
    var isLoadingSentenceTranslation: Bool = false

    // MARK: - Phrase Selection

    var selectedPhraseStart: Int?
    var selectedPhraseEnd: Int?
    var selectedPhrase: String?
    var phraseTranslation: PhraseTranslation?

    // MARK: - Language Bank

    var addedWords: Set<String> = []
    var wordAdditionState: WordAdditionState = .idle
    private var undoTask: Task<Void, Never>?

    /// Maps word text to the backend vocabulary item ID returned after saving,
    /// so that undo can issue a DELETE to remove the item from the database.
    private var addedWordItemIds: [String: String] = [:]

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
        self.fontSize = savedFontSize > 0 ? CGFloat(savedFontSize) : 19

        if let savedSpacing = defaults.string(forKey: Keys.lineSpacing),
           let spacing = LineSpacingOption(rawValue: savedSpacing) {
            self.lineSpacing = spacing
        } else {
            self.lineSpacing = .default
        }

        if let savedFont = defaults.string(forKey: Keys.readingFont),
           let font = ReadingFont(rawValue: savedFont) {
            self.readingFont = font
        } else {
            self.readingFont = .serif
        }
    }

    // MARK: - Computed Properties

    /// The font used for passage body text, based on user preference.
    var bodyFont: Font {
        readingFont.bodyFont(size: fontSize)
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

    /// Called when a non-highlighted word is tapped.
    /// Fetches the definition from the API and shows the word definition sheet.
    func tapNonHighlightedWord(_ word: String) {
        // Check if it matches a vocabulary annotation first.
        if let vocab = vocabulary.first(where: { $0.word.lowercased() == word.lowercased() }) {
            tapWord(vocab)
        } else {
            selectedWord = word
            selectedVocab = nil
            isLoadingDefinition = true
            showWordDefinition = true

            Task {
                let vocab = await fetchDefinition(for: word)
                lookedUpVocab = vocab
                selectedVocab = vocab
                isLoadingDefinition = false
            }
        }
    }

    /// Called when any word is long-pressed.
    /// Extracts the sentence containing the word from the passage content,
    /// highlights it, and fetches a translation.
    func longPressWord(_ word: String, at position: Int) {
        selectedWord = word

        // Extract the sentence from the passage content at this position.
        guard let (sentence, startIdx, endIdx) = extractSentence(at: position) else { return }

        selectedSentence = sentence
        selectedSentenceRange = (start: startIdx, end: endIdx)
        sentenceTranslation = nil
        isLoadingSentenceTranslation = true
        showWordDetail = true

        Task {
            await fetchSentenceTranslation(for: sentence)
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
    /// If the word was already persisted to the backend, issues a DELETE request.
    func undoAddWord() {
        guard let word = selectedWord else { return }
        undoTask?.cancel()
        addedWords.remove(word)
        wordAdditionState = .undone

        // Remove from the backend if the POST already completed.
        if let itemId = addedWordItemIds.removeValue(forKey: word) {
            let service = passageService
            Task {
                do {
                    try await service.removeVocabularyItem(itemId)
                } catch {
                    // Best-effort deletion; don't block the UI on failure.
                }
            }
        }

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

    /// Dismisses the currently active sheet with animation-friendly single state change.
    func dismissActiveSheet() {
        showWordDefinition = false
        showWordDetail = false
        showPhrasePopup = false
        showTextOptions = false
        selectedSentence = nil
        selectedSentenceRange = nil
        sentenceTranslation = nil
        isLoadingSentenceTranslation = false
        selectedWord = nil
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
                translation: response.definitions.first?.meaning,
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
            print("[ReaderVM] defineWord failed for '\(word)': \(error)")
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
            print("[ReaderVM] phraseTranslation failed for '\(phrase)': \(error)")
            phraseTranslation = MockData.samplePhraseTranslations[phrase.lowercased()]
                ?? PhraseTranslation(
                    phrase: phrase,
                    translation: "[Translation for: \(phrase)]",
                    context: nil
                )
        }
    }

    /// Extracts the sentence from the passage content at the given character position.
    /// Returns the sentence text and its character range (start, end offsets).
    private func extractSentence(at position: Int) -> (String, Int, Int)? {
        let text = passage.content
        guard position >= 0, position < text.count else { return nil }

        let posIdx = text.index(text.startIndex, offsetBy: position)

        // Find sentence start: last sentence-ending punctuation before this position, or start of string.
        let beforePos = text[..<posIdx]
        let sentenceStartIdx: String.Index
        if let lastPunct = beforePos.lastIndex(where: { ".!?\n".contains($0) }) {
            sentenceStartIdx = text.index(after: lastPunct)
        } else {
            sentenceStartIdx = text.startIndex
        }

        // Find sentence end: first sentence-ending punctuation at or after this position, or end of string.
        let fromPos = text[posIdx...]
        let sentenceEndIdx: String.Index
        if let nextPunct = fromPos.firstIndex(where: { ".!?\n".contains($0) }) {
            sentenceEndIdx = text.index(after: nextPunct)
        } else {
            sentenceEndIdx = text.endIndex
        }

        let sentence = String(text[sentenceStartIdx..<sentenceEndIdx])
            .trimmingCharacters(in: .whitespaces)
        let startOffset = text.distance(from: text.startIndex, to: sentenceStartIdx)
        let endOffset = text.distance(from: text.startIndex, to: sentenceEndIdx)

        return (sentence, startOffset, endOffset)
    }

    /// Fetches a translation for a sentence from the passage.
    private func fetchSentenceTranslation(for sentence: String) async {
        let request = TranslateRequest(
            text: sentence,
            sourceLanguage: passage.language,
            targetLanguage: "English",
            context: nil
        )

        do {
            let response = try await passageService.translatePhrase(request)
            sentenceTranslation = response.translation
        } catch {
            print("[ReaderVM] sentenceTranslation failed: \(error)")
            sentenceTranslation = "[Translation unavailable]"
        }
        isLoadingSentenceTranslation = false
    }

    /// Persists a word addition to the API. Fails silently.
    /// On success, stores the returned item ID so undo can delete it.
    private func addWordToAPI(word: String, vocab: PassageVocabulary?) async {
        // Use the vocab translation if available; fall back to the first
        // definition's meaning so we never send an empty string (the backend
        // requires min_length=1 on `translation`).
        let translation: String = {
            if let t = vocab?.translation, !t.isEmpty { return t }
            if let meaning = vocab?.definitions?.first?.meaning, !meaning.isEmpty { return meaning }
            if let def = vocab?.definitions?.first?.definition, !def.isEmpty { return def }
            return word
        }()

        let request = VocabularyItemCreate(
            text: word,
            translation: translation,
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
            let item = try await passageService.addVocabularyItem(request)
            addedWordItemIds[word] = item.id
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
