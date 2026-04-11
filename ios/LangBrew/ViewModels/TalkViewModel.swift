import Foundation
import SwiftUI

// MARK: - Starter Topic

/// A quick-start topic chip shown on the Talk home screen.
struct StarterTopic: Identifiable, Sendable {
    let icon: String
    let text: String

    var id: String { text }
}

// MARK: - Topic Grid Item

/// A topic option in the new conversation sheet grid.
struct TopicGridItem: Identifiable, Sendable {
    let icon: String
    let name: String

    var id: String { name }
}

// MARK: - Talk View Model

/// Manages the Talk home screen: conversation list, partner selection,
/// and new conversation creation.
@MainActor
@Observable
final class TalkViewModel {

    // MARK: - Data

    var conversations: [Conversation] = []
    var partners: [ConversationPartner] = []

    // MARK: - Loading State

    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - New Conversation Sheet

    var isNewConversationPresented: Bool = false
    var selectedPartner: ConversationPartner?
    var selectedTopic: String = ""
    var customTopic: String = ""

    // MARK: - Navigation

    var activeConversation: Conversation?
    var navigateToChat: Bool = false

    // MARK: - Language Flag

    var activeFlag: String = ""

    // MARK: - Static Content

    let starterTopics: [StarterTopic] = [
        StarterTopic(icon: "\u{1F6D2}", text: "At the market"),
        StarterTopic(icon: "\u{2708}\u{FE0F}", text: "Booking a trip"),
        StarterTopic(icon: "\u{2615}", text: "Ordering coffee"),
        StarterTopic(icon: "\u{1F3E0}", text: "My home"),
        StarterTopic(icon: "\u{1F44B}", text: "Introductions"),
    ]

    let topicGrid: [TopicGridItem] = [
        TopicGridItem(icon: "\u{1F6D2}", name: "Market"),
        TopicGridItem(icon: "\u{2708}\u{FE0F}", name: "Travel"),
        TopicGridItem(icon: "\u{2615}", name: "Coffee"),
        TopicGridItem(icon: "\u{1F3E0}", name: "Home"),
        TopicGridItem(icon: "\u{1F4C5}", name: "Weekend"),
        TopicGridItem(icon: "\u{1F4BC}", name: "Work"),
        TopicGridItem(icon: "\u{1F37D}\u{FE0F}", name: "Food"),
        TopicGridItem(icon: "\u{1F44B}", name: "Intros"),
        TopicGridItem(icon: "\u{1F3E5}", name: "Doctor"),
    ]

    // MARK: - Dependencies

    private let talkService: TalkService

    // MARK: - Init

    init(talkService: TalkService = .shared) {
        self.talkService = talkService
    }

    // MARK: - Data Loading

    /// Loads partners and conversations in parallel.
    func loadAll() async {
        isLoading = true
        errorMessage = nil

        async let partnersTask: () = loadPartners()
        async let conversationsTask: () = loadConversations()

        _ = await (partnersTask, conversationsTask)

        isLoading = false
    }

    /// Fetches available conversation partners from the API.
    func loadPartners() async {
        do {
            partners = try await talkService.getPartners()
        } catch {
            print("[TalkVM] Failed to load partners: \(error)")
        }
    }

    /// Fetches the user's conversation history from the API.
    func loadConversations() async {
        do {
            let response = try await talkService.listConversations()
            conversations = response.items
        } catch {
            print("[TalkVM] Failed to load conversations: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Conversation Actions

    /// Creates a new conversation with the selected partner and topic.
    func createConversation() async {
        guard let partner = selectedPartner else { return }

        let topic = customTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? selectedTopic
            : customTopic.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !topic.isEmpty else { return }

        do {
            let conversation = try await talkService.createConversation(
                partnerId: partner.id,
                topic: topic
            )
            conversations.insert(conversation, at: 0)
            activeConversation = conversation
            isNewConversationPresented = false
            selectedTopic = ""
            customTopic = ""
            navigateToChat = true
        } catch {
            errorMessage = error.localizedDescription
            print("[TalkVM] Failed to create conversation: \(error)")
        }
    }

    /// Starts a quick conversation using the first available partner (Mia).
    func startQuickConversation(topic: String) async {
        // Default to the first partner (Mia) if available
        guard let defaultPartner = partners.first else {
            errorMessage = "No conversation partners available."
            return
        }

        do {
            let conversation = try await talkService.createConversation(
                partnerId: defaultPartner.id,
                topic: topic
            )
            conversations.insert(conversation, at: 0)
            activeConversation = conversation
            navigateToChat = true
        } catch {
            errorMessage = error.localizedDescription
            print("[TalkVM] Failed to start quick conversation: \(error)")
        }
    }

    /// Deletes a conversation and removes it from the list.
    func deleteConversation(_ conversation: Conversation) async {
        do {
            try await talkService.deleteConversation(id: conversation.id)
            conversations.removeAll { $0.id == conversation.id }
        } catch {
            errorMessage = error.localizedDescription
            print("[TalkVM] Failed to delete conversation: \(error)")
        }
    }

    // MARK: - Selection

    /// Selects a partner for the new conversation.
    func selectPartner(_ partner: ConversationPartner) {
        selectedPartner = partner
    }

    /// Selects a topic from the grid.
    func selectTopic(_ topic: String) {
        selectedTopic = topic
        customTopic = ""
    }
}
