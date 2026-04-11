import Foundation

// MARK: - Feedback View Model

/// Manages loading and displaying post-conversation AI feedback.
/// Polls the backend until feedback is generated (up to 30 seconds).
@MainActor
@Observable
final class FeedbackViewModel {

    // MARK: - Feedback Data

    var feedback: ConversationFeedback?

    // MARK: - Loading State

    var isLoading: Bool = true
    var errorMessage: String?
    var showErrorAlert: Bool = false

    // MARK: - Conversation Info

    var conversationId: String = ""
    var topic: String = ""
    var durationMinutes: Int = 0

    // MARK: - Computed

    /// Overall score as a 0.0-1.0 progress value for circular indicators.
    var scoreProgress: Double {
        guard let feedback else { return 0 }
        return Double(feedback.overallScore) / 100.0
    }

    /// Combined label showing topic and duration.
    var topicLabel: String {
        if topic.isEmpty {
            return "\(durationMinutes) min"
        }
        return "\(topic) \u{00B7} \(durationMinutes) min"
    }

    // MARK: - Dependencies

    private let talkService: TalkService

    // MARK: - Init

    init(talkService: TalkService = .shared) {
        self.talkService = talkService
    }

    // MARK: - Data Loading

    /// Polls for feedback every 1 second, up to 30 attempts.
    /// The backend returns nil (HTTP 202) while feedback is still generating.
    func loadFeedback() async {
        guard !conversationId.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        let maxAttempts = 30

        for attempt in 1...maxAttempts {
            do {
                if let result = try await talkService.getFeedback(conversationId: conversationId) {
                    feedback = result
                    isLoading = false
                    return
                }

                // Feedback not ready yet -- wait and retry
                if attempt < maxAttempts {
                    try await Task.sleep(for: .seconds(1))
                }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                print("[FeedbackVM] Polling error (attempt \(attempt)): \(error)")
                isLoading = false
                return
            }
        }

        // Exhausted all attempts
        errorMessage = "Feedback is taking longer than expected. Please try again later."
        showErrorAlert = true
        isLoading = false
    }
}
