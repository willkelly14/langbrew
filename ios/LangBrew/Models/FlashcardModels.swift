import Foundation

// MARK: - Vocabulary List Item (from GET /v1/vocabulary)

/// Matches backend `VocabularyListItem` schema for list endpoints.
struct VocabularyListItem: Codable, Sendable, Identifiable {
    let id: String
    let text: String
    let translation: String
    let phonetic: String?
    let wordType: String?
    let language: String
    let type: String // word, phrase, sentence
    let status: String // new, learning, known, mastered
    let easeFactor: Double
    let interval: Int
    let repetitions: Int
    let nextReviewDate: String?
    let timesReviewed: Int
    let timesCorrect: Int
    let lastReviewedAt: String?
    let createdAt: String
    let updatedAt: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        translation = try container.decode(String.self, forKey: .translation)
        phonetic = try container.decodeIfPresent(String.self, forKey: .phonetic)
        wordType = try container.decodeIfPresent(String.self, forKey: .wordType)
        language = try container.decode(String.self, forKey: .language)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "word"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "new"
        easeFactor = try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 0
        repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions) ?? 0
        nextReviewDate = try container.decodeIfPresent(String.self, forKey: .nextReviewDate)
        timesReviewed = try container.decodeIfPresent(Int.self, forKey: .timesReviewed) ?? 0
        timesCorrect = try container.decodeIfPresent(Int.self, forKey: .timesCorrect) ?? 0
        lastReviewedAt = try container.decodeIfPresent(String.self, forKey: .lastReviewedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
}

// MARK: - Paginated Vocabulary Response

/// Response from `GET /v1/vocabulary` with cursor-based pagination.
struct PaginatedVocabularyResponse: Codable, Sendable {
    let items: [VocabularyListItem]
    let nextCursor: String?
}

// MARK: - Vocabulary Stats Response

/// Response from `GET /v1/vocabulary/stats`.
struct VocabularyStatsResponse: Codable, Sendable {
    let total: Int
    let new: Int
    let learning: Int
    let known: Int
    let mastered: Int
    let words: Int
    let phrases: Int
    let sentences: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        new = try container.decodeIfPresent(Int.self, forKey: .new) ?? 0
        learning = try container.decodeIfPresent(Int.self, forKey: .learning) ?? 0
        known = try container.decodeIfPresent(Int.self, forKey: .known) ?? 0
        mastered = try container.decodeIfPresent(Int.self, forKey: .mastered) ?? 0
        words = try container.decodeIfPresent(Int.self, forKey: .words) ?? 0
        phrases = try container.decodeIfPresent(Int.self, forKey: .phrases) ?? 0
        sentences = try container.decodeIfPresent(Int.self, forKey: .sentences) ?? 0
    }
}

// MARK: - Vocabulary Update Request

/// Request body for `PATCH /v1/vocabulary/{item_id}`.
struct VocabularyUpdateRequest: Codable, Sendable {
    let status: String?
    let translation: String?
    let phonetic: String?
    let wordType: String?
    let definitions: [[String: String]]?
    let exampleSentence: String?
    let resetSm2: Bool?
}

// MARK: - Vocabulary Encounter

/// A recorded encounter of a vocabulary item from `GET /v1/vocabulary/{id}/encounters`.
struct VocabularyEncounterResponse: Codable, Sendable, Identifiable {
    let id: String
    let sourceType: String
    let sourceId: String
    let contextSentence: String
    let createdAt: String
}

// MARK: - Flashcard Card Response

/// A vocabulary item projected as a flashcard for review.
/// Matches backend `FlashcardCardResponse` schema.
struct FlashcardCardResponse: Codable, Sendable, Identifiable {
    let id: String
    let text: String
    let translation: String
    let phonetic: String?
    let wordType: String?
    let definitions: [[String: String]]?
    let exampleSentence: String?
    let language: String
    let type: String // word, phrase, sentence
    let status: String // new, learning, known, mastered
    let easeFactor: Double
    let interval: Int
    let repetitions: Int
    let nextReviewDate: String?
    let timesReviewed: Int
    let timesCorrect: Int
    let lastReviewedAt: String?
    let createdAt: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        translation = try container.decode(String.self, forKey: .translation)
        phonetic = try container.decodeIfPresent(String.self, forKey: .phonetic)
        wordType = try container.decodeIfPresent(String.self, forKey: .wordType)
        definitions = try container.decodeIfPresent([[String: String]].self, forKey: .definitions)
        exampleSentence = try container.decodeIfPresent(String.self, forKey: .exampleSentence)
        language = try container.decode(String.self, forKey: .language)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "word"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "new"
        easeFactor = try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 0
        repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions) ?? 0
        nextReviewDate = try container.decodeIfPresent(String.self, forKey: .nextReviewDate)
        timesReviewed = try container.decodeIfPresent(Int.self, forKey: .timesReviewed) ?? 0
        timesCorrect = try container.decodeIfPresent(Int.self, forKey: .timesCorrect) ?? 0
        lastReviewedAt = try container.decodeIfPresent(String.self, forKey: .lastReviewedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

// MARK: - Flashcard Due Response

/// Response from `GET /v1/flashcards/due` (full card list).
struct FlashcardDueResponse: Codable, Sendable {
    let items: [FlashcardCardResponse]
    let totalDue: Int
}

// MARK: - Flashcard Due Count Response

/// Response from `GET /v1/flashcards/due?count_only=true`.
struct FlashcardDueCountResponse: Codable, Sendable {
    let count: Int
}

// MARK: - Flashcard Review Request

/// Request body for `POST /v1/flashcards/{item_id}/review`.
struct FlashcardReviewRequest: Codable, Sendable {
    let quality: Int // 1=wrong, 3=right
    let responseTimeMs: Int?
}

// MARK: - Flashcard Review Response

/// Response from `POST /v1/flashcards/{item_id}/review`.
struct FlashcardReviewResponse: Codable, Sendable {
    let id: String
    let text: String
    let translation: String
    let status: String
    let easeFactor: Double
    let interval: Int
    let repetitions: Int
    let nextReviewDate: String?
    let timesReviewed: Int
    let timesCorrect: Int
    let lastReviewedAt: String?
    let reviewEventId: String
}

// MARK: - Study Session Create Request

/// Request body for `POST /v1/flashcards/sessions`.
struct StudySessionCreateRequest: Codable, Sendable {
    let mode: String // daily, hardest, new, ahead, random
    let cardLimit: Int
    let cardTypeFilter: String?
}

// MARK: - Study Session Response

/// Response from study session endpoints.
struct StudySessionResponse: Codable, Sendable, Identifiable {
    let id: String
    let language: String
    let mode: String
    let cardLimit: Int
    let cardTypeFilter: String?
    let totalCards: Int
    let correctCount: Int
    let incorrectCount: Int
    let durationSeconds: Int?
    let completedAt: String?
    let createdAt: String
    let updatedAt: String
}

// MARK: - Session Review Card

/// Per-card breakdown within a study session detail.
struct SessionReviewCard: Codable, Sendable {
    let cardOrder: Int
    let vocabularyItemId: String
    let text: String
    let translation: String
    let quality: Int
    let previousEaseFactor: Double
    let newEaseFactor: Double
    let previousInterval: Int
    let newInterval: Int
    let responseTimeMs: Int?
}

// MARK: - Study Session Detail Response

/// Full study session detail with per-card breakdown.
struct StudySessionDetailResponse: Codable, Sendable {
    let id: String
    let language: String
    let mode: String
    let cardLimit: Int
    let cardTypeFilter: String?
    let totalCards: Int
    let correctCount: Int
    let incorrectCount: Int
    let durationSeconds: Int?
    let completedAt: String?
    let createdAt: String
    let updatedAt: String
    let cards: [SessionReviewCard]
}

// MARK: - Study Session Complete Request

/// Request body for `PATCH /v1/flashcards/sessions/{session_id}`.
struct StudySessionCompleteRequest: Codable, Sendable {
    let durationSeconds: Int
}

// MARK: - Paginated Study Sessions Response

/// Response from `GET /v1/flashcards/sessions`.
struct PaginatedStudySessionsResponse: Codable, Sendable {
    let items: [StudySessionResponse]
    let nextCursor: String?
}

// MARK: - Flashcard Stats Response

/// Full flashcard statistics from `GET /v1/flashcards/stats`.
struct FlashcardStatsResponse: Codable, Sendable {
    let masteryBreakdown: MasteryBreakdownResponse
    let streakData: StreakDataResponse
    let accuracy: AccuracyDataResponse
    let forecast: [ForecastDayResponse]
    let velocity: VelocityDataResponse
    let timeSpent: TimeSpentDataResponse
}

// MARK: - Mastery Breakdown

struct MasteryBreakdownResponse: Codable, Sendable {
    let new: Int
    let learning: Int
    let known: Int
    let mastered: Int
    let total: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        new = try container.decodeIfPresent(Int.self, forKey: .new) ?? 0
        learning = try container.decodeIfPresent(Int.self, forKey: .learning) ?? 0
        known = try container.decodeIfPresent(Int.self, forKey: .known) ?? 0
        mastered = try container.decodeIfPresent(Int.self, forKey: .mastered) ?? 0
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }
}

// MARK: - Streak Data

struct StreakDataResponse: Codable, Sendable {
    let current: Int
    let longest: Int
    let todayReviewed: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        current = try container.decodeIfPresent(Int.self, forKey: .current) ?? 0
        longest = try container.decodeIfPresent(Int.self, forKey: .longest) ?? 0
        todayReviewed = try container.decodeIfPresent(Bool.self, forKey: .todayReviewed) ?? false
    }
}

// MARK: - Accuracy Data

struct AccuracyDataResponse: Codable, Sendable {
    let totalReviews: Int
    let correct: Int
    let incorrect: Int
    let accuracyPercentage: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalReviews = try container.decodeIfPresent(Int.self, forKey: .totalReviews) ?? 0
        correct = try container.decodeIfPresent(Int.self, forKey: .correct) ?? 0
        incorrect = try container.decodeIfPresent(Int.self, forKey: .incorrect) ?? 0
        accuracyPercentage = try container.decodeIfPresent(Double.self, forKey: .accuracyPercentage) ?? 0.0
    }
}

// MARK: - Forecast Day (API response)

struct ForecastDayResponse: Codable, Sendable {
    let date: String
    let count: Int
}

// MARK: - Velocity Data

struct VelocityDataResponse: Codable, Sendable {
    let wordsPerDay7d: Double
    let wordsPerDay30d: Double
    let newWordsThisWeek: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wordsPerDay7d = try container.decodeIfPresent(Double.self, forKey: .wordsPerDay7d) ?? 0.0
        wordsPerDay30d = try container.decodeIfPresent(Double.self, forKey: .wordsPerDay30d) ?? 0.0
        newWordsThisWeek = try container.decodeIfPresent(Int.self, forKey: .newWordsThisWeek) ?? 0
    }
}

// MARK: - Time Spent Data

struct TimeSpentDataResponse: Codable, Sendable {
    let totalSeconds: Int
    let averageSessionSeconds: Double
    let sessionsCount: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalSeconds = try container.decodeIfPresent(Int.self, forKey: .totalSeconds) ?? 0
        averageSessionSeconds = try container.decodeIfPresent(Double.self, forKey: .averageSessionSeconds) ?? 0.0
        sessionsCount = try container.decodeIfPresent(Int.self, forKey: .sessionsCount) ?? 0
    }
}
