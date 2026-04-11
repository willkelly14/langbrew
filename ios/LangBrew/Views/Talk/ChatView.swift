import SwiftUI

/// Active chat conversation screen (Screen 3a).
struct ChatView: View {
    let conversation: Conversation
    @State private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            chatToolbar
            topicBar

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        messagesContent

                        // Invisible anchor for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .onChange(of: viewModel.messages.count) {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isStreaming) {
                    scrollToBottom(proxy: proxy)
                }
            }

            inputBar
        }
        .background(Color.lbLinen)
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $viewModel.showFeedback) {
            FeedbackView(
                conversationId: viewModel.feedbackConversationId,
                topic: viewModel.topic
            )
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .task {
            viewModel.configure(conversation: conversation)
            await viewModel.loadMessages()
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            Text("Talk")
                .font(LBTheme.Typography.largeTitle)
                .foregroundStyle(Color.lbBlack)
            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - Toolbar

    private var chatToolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14))
                    Text("Chats")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.lbNearBlack)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Text("Show text")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)
                Toggle("", isOn: $viewModel.showTranscript)
                    .toggleStyle(SwitchToggleStyle(tint: Color.lbNearBlack))
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 12)
    }

    // MARK: - Topic Bar

    private var topicBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "face.smiling")
                .font(.system(size: 22))
                .foregroundStyle(Color.lbBlack)

            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY'S TOPIC")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lbG400)
                    .kerning(0.5)
                Text(viewModel.topic)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.lbBlack)
            }

            Spacer()

            Button {
                Task { await viewModel.requestFeedback() }
            } label: {
                Text("Feedback")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.lbG200, lineWidth: 1.5)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 30)
        .padding(.top, 12)
    }

    // MARK: - Messages Content

    @ViewBuilder
    private var messagesContent: some View {
        ForEach(viewModel.messages) { message in
            chatBubble(for: message)
        }

        if viewModel.isStreaming {
            typingIndicator
        }
    }

    // MARK: - Chat Bubble

    @ViewBuilder
    private func chatBubble(for message: ChatMessage) -> some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 50)
                Text(message.displayText)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.lbBlack)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 12,
                            bottomTrailingRadius: 6,
                            topTrailingRadius: 12
                        )
                    )
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.partnerName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.lbG400)

                        Text(message.displayText)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .foregroundStyle(Color.lbBlack)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.white)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 6,
                            bottomTrailingRadius: 12,
                            topTrailingRadius: 12
                        )
                    )

                    Spacer(minLength: 50)
                }

                Button {
                    // Translation not implemented yet
                } label: {
                    Text("Translate")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG400)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    TypingDot(delay: Double(index) * 0.15)
                }
            }
            .frame(height: 10)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)

            Spacer()
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Type or tap mic...", text: $viewModel.inputText)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.lbG50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onSubmit {
                    if viewModel.canSend {
                        Task { await viewModel.sendMessage() }
                    }
                }

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.lbBlack)
                        .frame(width: 44, height: 44)

                    Image(systemName: viewModel.canSend ? "arrow.up" : "mic.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .padding(.bottom, 18)
    }
}

// MARK: - Typing Dot

/// A single bouncing dot for the typing indicator animation.
private struct TypingDot: View {
    let delay: Double
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color.lbG300)
            .frame(width: 8, height: 8)
            .offset(y: isAnimating ? -4 : 2)
            .animation(
                .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

#Preview {
    ChatView(conversation: Conversation(
        id: "preview",
        partnerId: "mia",
        partnerName: "Mia",
        topic: "Weekend Plans",
        language: "es",
        cefrLevel: "A2",
        status: "active",
        messageCount: 0,
        lastMessagePreview: nil,
        lastMessageAt: nil,
        hasUnread: false,
        startedAt: ISO8601DateFormatter().string(from: Date()),
        endedAt: nil,
        createdAt: ISO8601DateFormatter().string(from: Date())
    ))
}
