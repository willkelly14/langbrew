import Foundation

// MARK: - Talk Service Errors

enum TalkServiceError: Error, LocalizedError, Sendable {
    case loadFailed(underlying: Error)
    case conversationFailed(underlying: Error)
    case messageFailed(underlying: Error)
    case feedbackFailed(underlying: Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .loadFailed(let underlying):
            return "Failed to load talk data: \(underlying.localizedDescription)"
        case .conversationFailed(let underlying):
            return "Conversation operation failed: \(underlying.localizedDescription)"
        case .messageFailed(let underlying):
            return "Message send failed: \(underlying.localizedDescription)"
        case .feedbackFailed(let underlying):
            return "Failed to load feedback: \(underlying.localizedDescription)"
        case .notFound:
            return "The requested conversation could not be found."
        }
    }
}

// MARK: - Talk Service

/// Wraps all Talk (AI conversation) API calls through `APIClient`.
/// Uses actor isolation to ensure thread-safe access.
actor TalkService {
    static let shared = TalkService()

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    // MARK: - Partners

    /// Fetches all available conversation partners.
    ///
    /// `GET /v1/talk/partners`
    func getPartners() async throws -> [ConversationPartner] {
        try await api.get("/talk/partners")
    }

    // MARK: - Conversations

    /// Creates a new conversation with a partner.
    ///
    /// `POST /v1/talk/conversations`
    func createConversation(
        partnerId: String,
        topic: String,
        language: String? = nil
    ) async throws -> Conversation {
        let body = CreateConversationRequest(
            partnerId: partnerId,
            topic: topic,
            language: language
        )
        return try await api.post("/talk/conversations", body: body)
    }

    /// Lists conversations with cursor-based pagination.
    ///
    /// `GET /v1/talk/conversations`
    func listConversations(
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> PaginatedConversationsResponse {
        var query: [String: String] = ["limit": String(limit)]
        if let cursor { query["cursor"] = cursor }
        return try await api.get("/talk/conversations", query: query)
    }

    /// Gets a conversation with all its messages.
    ///
    /// `GET /v1/talk/conversations/:id`
    func getConversation(id: String) async throws -> ConversationDetailResponse {
        try await api.get("/talk/conversations/\(id)")
    }

    /// Sends a message and returns an SSE stream for the AI response.
    ///
    /// `POST /v1/talk/conversations/:id/messages`
    func sendMessage(
        conversationId: String,
        text: String
    ) async -> AsyncThrowingStream<SSEEvent, Error> {
        let body = SendMessageRequest(textContent: text)
        return await api.stream("/talk/conversations/\(conversationId)/messages", body: body)
    }

    /// Requests feedback on the conversation so far (does not end it).
    ///
    /// `POST /v1/talk/conversations/:id/feedback`
    func requestFeedback(conversationId: String) async throws {
        let body: [String: String] = [:]
        let _: EmptyResponse = try await api.post(
            "/talk/conversations/\(conversationId)/feedback", body: body
        )
    }

    /// Gets feedback for a conversation.
    /// Returns nil if feedback is still generating (202 status).
    ///
    /// `GET /v1/talk/conversations/:id/feedback`
    func getFeedback(conversationId: String) async throws -> ConversationFeedback? {
        do {
            return try await api.get("/talk/conversations/\(conversationId)/feedback")
        } catch let error as APIError {
            if case .httpError(let statusCode, _) = error, statusCode == 202 {
                return nil
            }
            throw error
        }
    }

    /// Deletes a conversation.
    ///
    /// `DELETE /v1/talk/conversations/:id`
    func deleteConversation(id: String) async throws {
        try await api.delete("/talk/conversations/\(id)")
    }

    // MARK: - Audio Transcription

    /// Uploads a WAV audio recording for speech-to-text transcription.
    ///
    /// `POST /v1/talk/transcribe`
    func transcribeAudio(data: Data, language: String?) async throws -> TranscriptionResponse {
        let fields = language.map { ["language": $0] } ?? [:]
        return try await api.uploadMultipart(
            "/talk/transcribe",
            fileData: data,
            fileName: "recording.wav",
            mimeType: "audio/wav",
            fields: fields
        )
    }
}
