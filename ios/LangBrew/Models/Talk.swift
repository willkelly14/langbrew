import Foundation

// MARK: - Conversation Partner

/// A pre-defined AI conversation partner with personality and avatar.
/// Matches the backend `conversation_partners` table.
struct ConversationPartner: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let personalityTag: String
    let avatarUrl: String
}

// MARK: - Conversation

/// A chat conversation between the user and an AI partner.
/// Matches the backend `ConversationResponse` schema.
struct Conversation: Codable, Sendable, Identifiable {
    let id: String
    let partnerId: String
    let partnerName: String
    let topic: String
    let language: String
    let cefrLevel: String
    let status: String
    let messageCount: Int
    let lastMessagePreview: String?
    let lastMessageAt: String?
    let hasUnread: Bool
    let startedAt: String
    let endedAt: String?
    let createdAt: String

    /// Time-ago label for display.
    var timeAgoLabel: String {
        guard let dateStr = lastMessageAt ?? Optional(createdAt) else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr) else { return "" }

        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 172800 { return "Yesterday" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

// MARK: - Chat Message

/// A single message within a conversation.
/// Matches the backend `MessageResponse` schema.
struct ChatMessage: Codable, Sendable, Identifiable {
    let id: String
    let conversationId: String
    let sequenceNumber: Int
    let role: String // "user" or "assistant"
    let contentType: String // "text" or "audio"
    let textContent: String?
    let createdAt: String

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
    var displayText: String { textContent ?? "" }
}

// MARK: - Conversation Feedback

/// Post-conversation AI feedback with scores and corrections.
/// Matches the backend `conversation_feedback` table.
struct ConversationFeedback: Codable, Sendable {
    let id: String
    let conversationId: String
    let overallScore: Int
    let grammarScore: Int
    let vocabularyScore: Int
    let fluencyScore: Int
    let confidenceScore: Int
    let summary: String?
    let strengths: FeedbackCallout?
    let tips: FeedbackCallout?
    let corrections: [CorrectionItem]?
    let createdAt: String

    /// Letter grade based on overall score.
    var letterGrade: String {
        switch overallScore {
        case 90...100: return "A+"
        case 85..<90: return "A"
        case 80..<85: return "A-"
        case 75..<80: return "B+"
        case 70..<75: return "B"
        case 65..<70: return "B-"
        case 60..<65: return "C+"
        case 55..<60: return "C"
        case 50..<55: return "C-"
        default: return "D"
        }
    }
}

// MARK: - Feedback Callout

/// A labeled feedback section (strengths or tips).
struct FeedbackCallout: Codable, Sendable {
    let label: String
    let text: String
}

// MARK: - Correction Item

/// A single grammar or vocabulary correction from feedback.
struct CorrectionItem: Codable, Sendable, Identifiable {
    let original: String
    let corrected: String
    let explanation: String

    var id: String { "\(original)-\(corrected)" }
}

// MARK: - Paginated Conversations Response

/// Response from `GET /v1/talk/conversations` with cursor-based pagination.
struct PaginatedConversationsResponse: Codable, Sendable {
    let items: [Conversation]
    let nextCursor: String?
}

// MARK: - Conversation Detail Response

/// Response from `GET /v1/talk/conversations/:id` including messages.
struct ConversationDetailResponse: Codable, Sendable {
    let conversation: Conversation
    let messages: [ChatMessage]
}

// MARK: - Create Conversation Request

/// Request body for `POST /v1/talk/conversations`.
struct CreateConversationRequest: Codable, Sendable {
    let partnerId: String
    let topic: String
    let language: String?
}

// MARK: - Send Message Request

/// Request body for `POST /v1/talk/conversations/:id/messages`.
struct SendMessageRequest: Codable, Sendable {
    let textContent: String
}
