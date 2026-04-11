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
    var isWaitingForFirstToken: Bool = false
    /// Tracks accumulated text during streaming — drives view updates.
    var streamingText: String = ""

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
    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        // Clear input and begin streaming
        inputText = ""
        isStreaming = true
        isWaitingForFirstToken = true
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

        // Add empty AI placeholder
        let placeholderId = UUID().uuidString
        let placeholder = ChatMessage(
            id: placeholderId,
            conversationId: conversationId,
            sequenceNumber: messages.count + 1,
            role: "assistant",
            contentType: "text",
            textContent: "",
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        messages.append(placeholder)

        // Stream AI response
        var accumulatedText = ""
        streamingText = ""
        let stream = await talkService.sendMessage(
            conversationId: conversationId,
            text: trimmed
        )

        do {
            print("[ChatVM] Starting SSE stream consumption")
            for try await sseEvent in stream {
                let eventType = sseEvent.event ?? ""
                print("[ChatVM] SSE event: type='\(eventType)' data='\(sseEvent.data.prefix(50))'")

                if eventType == "done" {
                    print("[ChatVM] Done event received")
                    break
                }

                if eventType == "error" {
                    errorMessage = sseEvent.data
                    showErrorAlert = true
                    print("[ChatVM] Error event received")
                    break
                }

                // Accumulate token data (both "token" events and untyped events)
                let tokenData = sseEvent.data
                if !tokenData.isEmpty {
                    if isWaitingForFirstToken {
                        isWaitingForFirstToken = false
                    }
                    accumulatedText += tokenData
                    streamingText = accumulatedText
                    updatePlaceholder(id: placeholderId, text: accumulatedText)
                    print("[ChatVM] Updated placeholder, total length: \(accumulatedText.count)")
                }
            }
            print("[ChatVM] Stream ended, accumulated \(accumulatedText.count) chars")
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            print("[ChatVM] SSE stream error: \(error)")
        }

        isWaitingForFirstToken = false
        isStreaming = false
        streamingText = ""
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

    // MARK: - Private Helpers

    /// Replaces the AI placeholder message with updated text content.
    /// ChatMessage is a struct, so we find and replace the entire value.
    private func updatePlaceholder(id: String, text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let existing = messages[index]
        messages[index] = ChatMessage(
            id: existing.id,
            conversationId: existing.conversationId,
            sequenceNumber: existing.sequenceNumber,
            role: existing.role,
            contentType: existing.contentType,
            textContent: text,
            createdAt: existing.createdAt
        )
    }
}
