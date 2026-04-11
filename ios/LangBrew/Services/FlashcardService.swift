import Foundation

// MARK: - Flashcard Service Errors

enum FlashcardServiceError: Error, LocalizedError, Sendable {
    case loadFailed(underlying: Error)
    case reviewFailed(underlying: Error)
    case sessionFailed(underlying: Error)
    case statsFailed(underlying: Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .loadFailed(let underlying):
            return "Failed to load flashcard data: \(underlying.localizedDescription)"
        case .reviewFailed(let underlying):
            return "Review submission failed: \(underlying.localizedDescription)"
        case .sessionFailed(let underlying):
            return "Session operation failed: \(underlying.localizedDescription)"
        case .statsFailed(let underlying):
            return "Failed to load statistics: \(underlying.localizedDescription)"
        case .notFound:
            return "The requested item could not be found."
        }
    }
}

// MARK: - Flashcard Service

/// Wraps all flashcard, vocabulary listing, study session, and stats API calls
/// through `APIClient`. Uses actor isolation to ensure thread-safe access.
actor FlashcardService {
    static let shared = FlashcardService()

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Vocabulary Listing

    /// Lists vocabulary items with optional filtering and pagination.
    ///
    /// `GET /v1/vocabulary`
    func listVocabulary(
        search: String? = nil,
        type: String? = nil,
        status: String? = nil,
        language: String? = nil,
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> PaginatedVocabularyResponse {
        var query: [String: String] = ["limit": String(limit)]
        if let search, !search.isEmpty { query["search"] = search }
        if let type { query["type"] = type }
        if let status { query["status"] = status }
        if let language { query["language"] = language }
        if let cursor { query["cursor"] = cursor }

        return try await api.get("/vocabulary", query: query)
    }

    /// Fetches aggregate vocabulary statistics.
    ///
    /// `GET /v1/vocabulary/stats`
    func getVocabularyStats(language: String? = nil) async throws -> VocabularyStatsResponse {
        var query: [String: String] = [:]
        if let language { query["language"] = language }

        return try await api.get("/vocabulary/stats", query: query.isEmpty ? nil : query)
    }

    /// Fetches full detail for a vocabulary item including encounters.
    ///
    /// `GET /v1/vocabulary/{item_id}`
    func getVocabularyDetail(id: String) async throws -> VocabularyItem {
        try await api.get("/vocabulary/\(id)")
    }

    /// Updates a vocabulary item (status, translation, etc.).
    ///
    /// `PATCH /v1/vocabulary/{item_id}`
    func updateVocabulary(id: String, status: String? = nil) async throws -> VocabularyItem {
        let body = VocabularyUpdateRequest(
            status: status,
            translation: nil,
            phonetic: nil,
            wordType: nil,
            definitions: nil,
            exampleSentence: nil,
            resetSm2: nil
        )
        return try await api.patch("/vocabulary/\(id)", body: body)
    }

    /// Fetches encounter history for a vocabulary item.
    ///
    /// `GET /v1/vocabulary/{item_id}/encounters`
    func getEncounters(id: String) async throws -> [VocabularyEncounterResponse] {
        try await api.get("/vocabulary/\(id)/encounters")
    }

    // MARK: - Flashcard Review

    /// Gets cards due for review.
    ///
    /// `GET /v1/flashcards/due`
    func getDueCards(
        mode: String = "daily",
        type: String? = nil,
        limit: Int? = nil,
        countOnly: Bool = false
    ) async throws -> FlashcardDueResponse {
        var query: [String: String] = ["mode": mode]
        if let type { query["type"] = type }
        if let limit { query["limit"] = String(limit) }
        if countOnly { query["count_only"] = "true" }

        return try await api.get("/flashcards/due", query: query)
    }

    /// Gets only the count of cards due for review.
    ///
    /// `GET /v1/flashcards/due?count_only=true`
    func getDueCount(mode: String = "daily") async throws -> FlashcardDueCountResponse {
        let query: [String: String] = ["mode": mode, "count_only": "true"]
        return try await api.get("/flashcards/due", query: query)
    }

    /// Submits a flashcard review and updates SM-2 data.
    ///
    /// `POST /v1/flashcards/{item_id}/review`
    func reviewCard(
        id: String,
        quality: Int,
        responseTimeMs: Int? = nil,
        sessionId: String? = nil
    ) async throws -> FlashcardReviewResponse {
        let body = FlashcardReviewRequest(quality: quality, responseTimeMs: responseTimeMs)
        var query: [String: String]? = nil
        if let sessionId {
            query = ["session_id": sessionId]
        }
        // The review endpoint uses query param for session_id and body for quality
        // Build the path with query param if needed
        var path = "/flashcards/\(id)/review"
        if let sessionId {
            path += "?session_id=\(sessionId)"
        }
        _ = query // Suppress unused warning
        return try await api.post(path, body: body)
    }

    // MARK: - Study Sessions

    /// Creates a new study session.
    ///
    /// `POST /v1/flashcards/sessions`
    func createSession(
        mode: String,
        cardLimit: Int = 25,
        cardTypeFilter: String? = nil
    ) async throws -> StudySessionResponse {
        let body = StudySessionCreateRequest(
            mode: mode,
            cardLimit: cardLimit,
            cardTypeFilter: cardTypeFilter
        )
        return try await api.post("/flashcards/sessions", body: body)
    }

    /// Lists past study sessions with pagination.
    ///
    /// `GET /v1/flashcards/sessions`
    func listSessions(
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> PaginatedStudySessionsResponse {
        var query: [String: String] = ["limit": String(limit)]
        if let cursor { query["cursor"] = cursor }

        return try await api.get("/flashcards/sessions", query: query)
    }

    /// Gets full detail for a study session with per-card breakdown.
    ///
    /// `GET /v1/flashcards/sessions/{session_id}`
    func getSessionDetail(id: String) async throws -> StudySessionDetailResponse {
        try await api.get("/flashcards/sessions/\(id)")
    }

    /// Completes a study session by setting its duration.
    ///
    /// `PATCH /v1/flashcards/sessions/{session_id}`
    func completeSession(id: String, durationSeconds: Int) async throws -> StudySessionResponse {
        let body = StudySessionCompleteRequest(durationSeconds: durationSeconds)
        return try await api.patch("/flashcards/sessions/\(id)", body: body)
    }

    /// Creates a new study session from missed cards in a previous session.
    ///
    /// `POST /v1/flashcards/sessions/{session_id}/restudy`
    func restudySession(id: String) async throws -> StudySessionDetailResponse {
        // Use an empty struct as the body for the POST
        let body: [String: String] = [:]
        return try await api.post("/flashcards/sessions/\(id)/restudy", body: body)
    }

    // MARK: - Stats

    /// Fetches comprehensive flashcard statistics.
    ///
    /// `GET /v1/flashcards/stats`
    func getStats() async throws -> FlashcardStatsResponse {
        try await api.get("/flashcards/stats")
    }
}
