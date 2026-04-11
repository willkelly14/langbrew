import Foundation

// MARK: - Chat View Model

/// Manages an active conversation with SSE streaming for AI responses.
@MainActor
@Observable
final class ChatViewModel {

    // MARK: - Messages

    var messages: [ChatMessage] = []

    // MARK: - Input

    var inputText: String = ""

    // MARK: - Streaming State

    var isStreaming: Bool = false

    // MARK: - Transcript Toggle

    var showTranscript: Bool = true

    // MARK: - Conversation Info

    var conversationId: String = ""
    var partnerName: String = ""
    var topic: String = ""

    // MARK: - Feedback Navigation

    var showFeedback: Bool = false
    var feedbackConversationId: String = ""

    // MARK: - Loading State

    var isLoading: Bool = false
    var errorMessage: String?
    var showErrorAlert: Bool = false

    // MARK: - Computed

    /// Whether the send button should be enabled.
    var canSend: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isStreaming
    }

    // MARK: - Dependencies

    private let talkService: TalkService

    // MARK: - Init

    init(talkService: TalkService = .shared) {
        self.talkService = talkService
    }

    // MARK: - Configuration

    /// Configures the view model from a Conversation model.
    func configure(conversation: Conversation) {
        conversationId = conversation.id
        partnerName = conversation.partnerName
        topic = conversation.topic
    }

    // MARK: - Data Loading

    /// Fetches existing messages for the conversation.
    func loadMessages() async {
        guard !conversationId.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let detail = try await talkService.getConversation(id: conversationId)
            messages = detail.messages
        } catch {
            errorMessage = error.localizedDescription
            print("[ChatVM] Failed to load messages: \(error)")
        }

        isLoading = false
    }

    // MARK: - Send Message (SSE Streaming)

    /// Sends the user's message and streams the AI response via SSE.
    /// Tokens are accumulated silently — the complete response appears all at once.
    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        // Clear input and begin streaming
        inputText = ""
        isStreaming = true
        errorMessage = nil

        // Add user message optimistically
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            sequenceNumber: messages.count + 1,
            role: "user",
            contentType: "text",
            textContent: trimmed,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        messages.append(userMessage)

        // Stream AI response — consume the SSE stream, then reload from server
        let stream = await talkService.sendMessage(
            conversationId: conversationId,
            text: trimmed
        )

        do {
            for try await sseEvent in stream {
                if sseEvent.event == "done" || sseEvent.event == "error" {
                    if sseEvent.event == "error" {
                        errorMessage = sseEvent.data
                        showErrorAlert = true
                    }
                    break
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }

        // Reload messages from server — the backend has saved both messages by now
        if let detail = try? await talkService.getConversation(id: conversationId) {
            messages = detail.messages
        }

        isStreaming = false
    }

    // MARK: - Request Feedback

    /// Requests feedback on the conversation so far without ending it.
    func requestFeedback() async {
        guard !conversationId.isEmpty else { return }

        // Navigate to feedback immediately — loading screen shows while it generates
        feedbackConversationId = conversationId
        showFeedback = true

        do {
            try await talkService.requestFeedback(conversationId: conversationId)
        } catch {
            // Don't block navigation — feedback screen handles polling
            print("[ChatVM] Failed to request feedback: \(error)")
        }
    }

}
