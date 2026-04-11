import Foundation

// MARK: - CEFR Level

/// Common European Framework of Reference levels used for passage difficulty.
enum CEFRLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"

    var id: String { rawValue }
}

// MARK: - Passage Style

/// The writing style of a generated passage.
enum PassageStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case article = "article"
    case dialogue = "dialogue"
    case story = "story"
    case letter = "letter"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .article: "Article"
        case .dialogue: "Dialogue"
        case .story: "Story"
        case .letter: "Letter"
        }
    }
}

// MARK: - Passage Length

/// The target length of a generated passage.
enum PassageLength: String, Codable, Sendable, CaseIterable, Identifiable {
    case short = "short"
    case medium = "medium"
    case long = "long"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .short: "Short"
        case .medium: "Medium"
        case .long: "Long"
        }
    }
}

// MARK: - Generate Mode

/// Whether the passage topic is auto-selected or user-specified.
enum GenerateMode: String, Sendable, CaseIterable, Identifiable {
    case auto = "auto"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: "Auto"
        case .custom: "Custom"
        }
    }
}

// MARK: - Passage Response

/// Matches the backend `PassageResponse` schema from `GET /v1/passages` and `GET /v1/passages/:id`.
struct PassageResponse: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let userId: String
    let userLanguageId: String
    let title: String
    let content: String
    let language: String
    let cefrLevel: String
    let topic: String
    let wordCount: Int
    let estimatedMinutes: Int
    let knownWordPercentage: Double?
    let newWordCount: Int?
    let isGenerated: Bool
    let style: String?
    let length: String?
    let readingProgress: Double
    let bookmarkPosition: Int?
    let createdAt: String
    let updatedAt: String

    /// Short preview of the content, truncated to approximately two lines.
    var excerpt: String {
        let limit = 120
        if content.count <= limit {
            return content
        }
        let endIndex = content.index(content.startIndex, offsetBy: limit)
        return String(content[..<endIndex]) + "..."
    }

    /// Estimated reading time as a formatted string.
    var readingTimeLabel: String {
        "~\(estimatedMinutes) min"
    }

    /// Word count as a formatted string.
    var wordCountLabel: String {
        "\(wordCount) words"
    }

    /// New word count as a formatted string.
    var newWordCountLabel: String {
        "\(newWordCount ?? 0) new words"
    }

    /// Known word percentage as a formatted string.
    var knownPercentageLabel: String {
        let pct = Int((knownWordPercentage ?? 0) * 100)
        return "\(pct)% known"
    }

    /// Whether this passage is currently being read (has partial progress).
    var isInProgress: Bool {
        readingProgress > 0 && readingProgress < 1.0
    }

    /// Whether this passage has not been started.
    var isNotStarted: Bool {
        readingProgress == 0
    }
}

// MARK: - Passage Vocabulary

/// A vocabulary annotation within a passage.
struct PassageVocabulary: Codable, Sendable, Identifiable {
    let id: String
    let passageId: String?
    let word: String
    let startIndex: Int
    let endIndex: Int
    let isHighlighted: Bool
    let definition: String?
    let translation: String?
    let phonetic: String?
    let wordType: String?
    let exampleSentence: String?
    let conjugationHint: String?
    let definitions: [WordDefinition]?
    let usageNotes: String?
}

// MARK: - Word Definition

/// A single definition entry for a word, with optional example and meaning.
struct WordDefinition: Codable, Sendable {
    let definition: String
    let example: String?
    let meaning: String?
}

// MARK: - Vocabulary Item

/// A saved vocabulary item in the user's Language Bank.
struct VocabularyItem: Codable, Sendable, Identifiable {
    let id: String
    let text: String
    let translation: String
    let phonetic: String?
    let wordType: String?
    let definitions: [WordDefinition]?
    let exampleSentence: String?
    let status: String // new, learning, known, mastered
    let language: String
    let type: String // word, phrase, sentence
    let easeFactor: Double
    let interval: Int
    let repetitions: Int
    let nextReviewDate: String?
    let timesReviewed: Int
    let timesCorrect: Int
    let lastReviewedAt: String?
    let createdAt: String
    let updatedAt: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        translation = try container.decode(String.self, forKey: .translation)
        phonetic = try container.decodeIfPresent(String.self, forKey: .phonetic)
        wordType = try container.decodeIfPresent(String.self, forKey: .wordType)
        definitions = try container.decodeIfPresent([WordDefinition].self, forKey: .definitions)
        exampleSentence = try container.decodeIfPresent(String.self, forKey: .exampleSentence)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "new"
        language = try container.decode(String.self, forKey: .language)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "word"
        easeFactor = try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 0
        repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions) ?? 0
        nextReviewDate = try container.decodeIfPresent(String.self, forKey: .nextReviewDate)
        timesReviewed = try container.decodeIfPresent(Int.self, forKey: .timesReviewed) ?? 0
        timesCorrect = try container.decodeIfPresent(Int.self, forKey: .timesCorrect) ?? 0
        lastReviewedAt = try container.decodeIfPresent(String.self, forKey: .lastReviewedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

// MARK: - Phrase Translation

/// A translation result for a user-selected phrase within a passage.
struct PhraseTranslation: Codable, Sendable {
    let phrase: String
    let translation: String
    let context: String?
}

// MARK: - Generate Passage Request

/// Request body for `POST /v1/passages/generate`.
struct GeneratePassageRequest: Codable, Sendable {
    let mode: String
    let topic: String?
    let cefrLevel: String?
    let style: String?
    let length: String?
}

// MARK: - Paginated Passages Response

/// Response from `GET /v1/passages` with cursor-based pagination.
struct PaginatedPassagesResponse: Codable, Sendable {
    let items: [PassageResponse]
    let cursor: String?
}

// MARK: - Passage Detail Response

/// Response from `GET /v1/passages/:id` including vocabulary annotations.
/// The backend returns a flat response with vocabulary embedded as `vocabulary_annotations`.
struct PassageDetailResponse: Codable, Sendable {
    let id: String
    let userId: String
    let userLanguageId: String
    let title: String
    let content: String
    let language: String
    let cefrLevel: String
    let topic: String
    let wordCount: Int
    let estimatedMinutes: Int
    let knownWordPercentage: Double?
    let isGenerated: Bool
    let style: String?
    let length: String?
    let readingProgress: Double
    let bookmarkPosition: Int?
    let vocabularyAnnotations: [PassageVocabulary]
    let createdAt: String
    let updatedAt: String
}

// MARK: - Passage Update Request

/// Request body for `PATCH /v1/passages/:id`.
struct PassageUpdateRequest: Codable, Sendable {
    let readingProgress: Double?
    let bookmarkPosition: Int?
}

// MARK: - Define Request / Response

/// Request body for `POST /v1/vocabulary/define`.
struct DefineRequest: Codable, Sendable {
    let word: String
    let language: String
    let contextSentence: String?
}

/// Response from `POST /v1/vocabulary/define`.
struct DefineResponse: Codable, Sendable {
    let word: String
    let phonetic: String?
    let wordType: String?
    let definitions: [WordDefinition]
    let exampleSentence: String?
    let source: String? // "dictionary" or "ai"
}

// MARK: - Translate Request / Response

/// Request body for `POST /v1/vocabulary/translate`.
struct TranslateRequest: Codable, Sendable {
    let text: String
    let sourceLanguage: String
    let targetLanguage: String
    let context: String?
}

/// Response from `POST /v1/vocabulary/translate`.
struct TranslateResponse: Codable, Sendable {
    let text: String
    let translation: String
}

// MARK: - Vocabulary Item Create

/// Request body for `POST /v1/vocabulary`.
struct VocabularyItemCreate: Codable, Sendable {
    let text: String
    let translation: String
    let phonetic: String?
    let wordType: String?
    let definitions: [WordDefinition]?
    let exampleSentence: String?
    let language: String
    let type: String // word, phrase, sentence
    let sourceType: String? // passage, book_chapter, conversation
    let sourceId: String?
    let contextSentence: String?
}
