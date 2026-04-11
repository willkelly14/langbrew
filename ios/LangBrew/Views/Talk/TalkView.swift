import SwiftUI

// MARK: - Talk View

/// The main Talk tab screen (Screen 3b) showing conversation history,
/// quick-start topic chips, and the "New Conversation" entry point.
struct TalkView: View {
    @Bindable var viewModel: TalkViewModel
    @State private var chatViewModel = ChatViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lbLinen
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView()
                        .tint(.lbG400)
                } else if let error = viewModel.errorMessage, viewModel.conversations.isEmpty {
                    LBEmptyState(
                        icon: "exclamationmark.triangle",
                        title: "Something went wrong",
                        subtitle: error,
                        buttonTitle: "Retry"
                    ) {
                        Task { await viewModel.loadAll() }
                    }
                } else {
                    conversationList
                }
            }
            .overlay {
                if viewModel.isNewConversationPresented {
                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.isNewConversationPresented = false
                            }
                            .transition(.opacity)

                        NewConversationSheet(
                            viewModel: viewModel,
                            onDismiss: { viewModel.isNewConversationPresented = false }
                        )
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isNewConversationPresented)
            .navigationDestination(isPresented: $viewModel.navigateToChat) {
                if let conversation = viewModel.activeConversation {
                    ChatView(conversation: conversation)
                }
            }
            .task {
                await viewModel.loadAll()
            }
            .refreshable {
                await viewModel.loadAll()
            }
        }
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                talkHeader
                newConversationButton
                starterTopicsSection
                recentLabel

                if viewModel.conversations.isEmpty {
                    emptyConversations
                } else {
                    conversationRows
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Header

    private var talkHeader: some View {
        HStack {
            Text("Talk")
                .font(LBTheme.Typography.largeTitle)
                .foregroundStyle(Color.lbBlack)

            Spacer()

            Text(viewModel.activeFlag)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(Color.lbG50)
                .clipShape(Circle())
        }
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - New Conversation Button

    private var newConversationButton: some View {
        Button {
            viewModel.isNewConversationPresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                Text("New Conversation")
                    .font(.system(size: 15))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.lbNearBlack)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - Starter Topics

    private var starterTopicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try a topic")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.lbG400)
                .padding(.horizontal, 30)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.starterTopics) { topic in
                        Button {
                            Task { await viewModel.startQuickConversation(topic: topic.text) }
                        } label: {
                            HStack(spacing: 7) {
                                Text(topic.icon)
                                    .font(.system(size: 15))
                                Text(topic.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.lbNearBlack)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.lbWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.lbG200, lineWidth: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 30)
            }
        }
        .padding(.top, 14)
    }

    // MARK: - Recent Label

    private var recentLabel: some View {
        Text("RECENT")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.lbG400)
            .kerning(0.66)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    // MARK: - Conversation Rows

    private var conversationRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.conversations.enumerated()), id: \.element.id) { index, conversation in
                Button {
                    viewModel.activeConversation = conversation
                    viewModel.navigateToChat = true
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .buttonStyle(.plain)

                if index < viewModel.conversations.count - 1 {
                    Divider()
                        .foregroundStyle(Color.lbG100)
                        .padding(.leading, 88)
                }
            }
        }
        .padding(.horizontal, 30)
    }

    // MARK: - Empty State

    private var emptyConversations: some View {
        VStack(spacing: LBTheme.Spacing.lg) {
            Spacer().frame(height: 40)

            LBEmptyState(
                icon: "bubble.left.and.bubble.right",
                title: "No conversations yet",
                subtitle: "Start a conversation to practice speaking with an AI partner."
            )
        }
    }
}

// MARK: - Conversation Row

/// A single row in the recent conversations list.
private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 14) {
            // Avatar circle
            LBAvatarCircle(
                name: conversation.partnerName,
                size: 44,
                style: .light,
                initialsFontSize: 16
            )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.topic)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.lbNearBlack)
                    .lineLimit(1)

                Text(conversation.lastMessagePreview ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG400)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Meta
            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.timeAgoLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lbG400)

                if conversation.hasUnread {
                    Text("1")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.lbNearBlack)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Preview

#Preview {
    TalkView(viewModel: TalkViewModel())
}
