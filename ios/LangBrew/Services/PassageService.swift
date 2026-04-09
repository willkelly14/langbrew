import Foundation

// MARK: - Passage Service Errors

enum PassageServiceError: Error, LocalizedError, Sendable {
    case generationFailed(underlying: Error)
    case passageNotFound
    case definitionFailed(underlying: Error)
    case translationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .generationFailed(let underlying):
            return "Passage generation failed: \(underlying.localizedDescription)"
        case .passageNotFound:
            return "The requested passage could not be found."
        case .definitionFailed(let underlying):
            return "Word definition failed: \(underlying.localizedDescription)"
        case .translationFailed(let underlying):
            return "Translation failed: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Passage Service

/// Wraps all passage and vocabulary API calls through `APIClient`.
/// Uses actor isolation to ensure thread-safe access.
actor PassageService {
    static let shared = PassageService()

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Passage CRUD

    /// Lists the current user's passages with optional filtering and pagination.
    ///
    /// `GET /v1/passages`
    func listPassages(
        search: String? = nil,
        cefrLevel: String? = nil,
        topic: String? = nil,
        sortBy: String? = nil,
        cursor: String? = nil,
        limit: Int? = nil
    ) async throws -> PaginatedPassagesResponse {
        var query: [String: String] = [:]
        if let search, !search.isEmpty { query["search"] = search }
        if let cefrLevel { query["cefr_level"] = cefrLevel }
        if let topic { query["topic"] = topic }
        if let sortBy { query["sort_by"] = sortBy }
        if let cursor { query["cursor"] = cursor }
        if let limit { query["limit"] = String(limit) }

        return try await api.get("/passages", query: query.isEmpty ? nil : query)
    }

    /// Fetches a single passage with its vocabulary annotations.
    ///
    /// `GET /v1/passages/:id`
    func getPassage(_ id: String) async throws -> PassageDetailResponse {
        try await api.get("/passages/\(id)")
    }

    /// Updates a passage's reading progress and/or bookmark position.
    ///
    /// `PATCH /v1/passages/:id`
    func updatePassage(_ id: String, progress: Double? = nil, bookmark: Int? = nil) async throws {
        let body = PassageUpdateRequest(readingProgress: progress, bookmarkPosition: bookmark)
        let _: PassageResponse = try await api.patch("/passages/\(id)", body: body)
    }

    /// Soft-deletes a passage.
    ///
    /// `DELETE /v1/passages/:id`
    func deletePassage(_ id: String) async throws {
        try await api.delete("/passages/\(id)")
    }

    // MARK: - Generation (SSE)

    /// Generates a passage via SSE streaming.
    /// Returns an `AsyncThrowingStream` of SSE events that the caller can
    /// iterate to show progress and receive the final passage data.
    ///
    /// `POST /v1/passages/generate`
    func generatePassage(request: GeneratePassageRequest) async -> AsyncThrowingStream<SSEEvent, Error> {
        await api.stream("/passages/generate", body: request)
    }

    // MARK: - Vocabulary

    /// Defines a word in context.
    ///
    /// `POST /v1/vocabulary/define`
    func defineWord(_ request: DefineRequest) async throws -> DefineResponse {
        try await api.post("/vocabulary/define", body: request)
    }

    /// Translates a phrase or sentence in context.
    ///
    /// `POST /v1/vocabulary/translate`
    func translatePhrase(_ request: TranslateRequest) async throws -> TranslateResponse {
        try await api.post("/vocabulary/translate", body: request)
    }

    /// Adds a vocabulary item to the user's Language Bank.
    ///
    /// `POST /v1/vocabulary`
    func addVocabularyItem(_ request: VocabularyItemCreate) async throws -> VocabularyItem {
        try await api.post("/vocabulary", body: request)
    }

    /// Removes a vocabulary item from the Language Bank.
    ///
    /// `DELETE /v1/vocabulary/:id`
    func removeVocabularyItem(_ id: String) async throws {
        try await api.delete("/vocabulary/\(id)")
    }
}
