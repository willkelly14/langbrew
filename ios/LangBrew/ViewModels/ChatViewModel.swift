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

    // MARK: - Voice Recording State

    var isTranscribing: Bool = false
    var showMicPermissionDenied: Bool = false

    /// The recording service for voice input.
    private let recordingService = AudioRecordingService()

    /// Whether the recording service is currently capturing audio.
    var isRecording: Bool { recordingService.isRecording }

    /// Current recording duration in seconds.
    var recordingDuration: TimeInterval { recordingService.recordingDuration }

    /// Normalized amplitude (0-1) for waveform visualization.
    var currentAmplitude: Float { recordingService.currentAmplitude }

    // MARK: - Transcript Toggle

    var showTranscript: Bool = true

    // MARK: - Conversation Info

    var conversationId: String = ""
    var partnerName: String = ""
    var topic: String = ""
    var conversationLanguage: String = ""

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
        conversationLanguage = conversation.language
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

    // MARK: - Voice Recording

    /// Toggles the recording state: starts recording if idle, stops and transcribes if recording.
    func toggleRecording() async {
        if isRecording {
            await stopAndTranscribe()
        } else {
            // Check / request permission
            recordingService.checkPermissionStatus()
            if recordingService.permissionStatus == .denied {
                showMicPermissionDenied = true
                return
            }

            do {
                try await recordingService.startRecording()
            } catch {
                if case AudioRecordingError.permissionDenied = error {
                    showMicPermissionDenied = true
                } else {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    /// Stops recording, transcribes the audio, and sends the result as a message.
    func stopAndTranscribe() async {
        let wavData = recordingService.stopRecording()

        guard let wavData, !wavData.isEmpty else {
            // Recording too short, silently return
            return
        }

        isTranscribing = true

        do {
            let language = conversationLanguage.isEmpty ? nil : conversationLanguage
            let response = try await talkService.transcribeAudio(data: wavData, language: language)
            let trimmed = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                isTranscribing = false
                return
            }
            inputText = trimmed
            isTranscribing = false
            await sendMessage()
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            showErrorAlert = true
            isTranscribing = false
        }
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
