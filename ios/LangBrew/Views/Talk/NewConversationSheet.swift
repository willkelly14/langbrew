import SwiftUI

// MARK: - New Conversation Sheet

/// Bottom sheet overlay for creating a new conversation (Screen 3b-ii).
/// Lets the user pick a partner, select or type a topic, and start chatting.
/// Uses the same `LBBottomSheet` pattern as `GeneratePassageSheet`.
struct NewConversationSheet: View {
    @Bindable var viewModel: TalkViewModel
    var onDismiss: (() -> Void)?

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("New conversation")
                    .font(LBTheme.serifFont(size: 24))
                    .foregroundStyle(Color.lbBlack)
                    .padding(.bottom, 4)

                // Subtitle
                Text("Pick a partner and topic, or describe your own.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)
                    .padding(.bottom, 18)

                // Partner selector
                partnerSelector

                // Topic grid
                topicSection

                // Custom topic input
                customTopicInput

                // Start button
                startButton
            }
        }
    }

    // MARK: - Partner Selector

    private var partnerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TALK WITH")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.lbG400)
                .kerning(0.66)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(viewModel.partners) { partner in
                        Button {
                            viewModel.selectPartner(partner)
                        } label: {
                            VStack(spacing: 6) {
                                LBAvatarCircle(
                                    imageURL: URL(string: partner.avatarUrl),
                                    name: partner.name,
                                    size: 48,
                                    showBorder: viewModel.selectedPartner?.id == partner.id,
                                    style: .light,
                                    initialsFontSize: 18
                                )
                                .overlay {
                                    if viewModel.selectedPartner?.id == partner.id {
                                        Circle()
                                            .strokeBorder(Color.lbBlack, lineWidth: 2)
                                            .frame(width: 48, height: 48)
                                    }
                                }

                                Text(partner.name)
                                    .font(.system(
                                        size: 11,
                                        weight: viewModel.selectedPartner?.id == partner.id
                                            ? .semibold : .medium
                                    ))
                                    .foregroundStyle(
                                        viewModel.selectedPartner?.id == partner.id
                                            ? Color.lbBlack : Color.lbG500
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.bottom, 18)
    }

    // MARK: - Topic Section

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with refresh
            HStack {
                Text("TOPIC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.lbG400)
                    .kerning(0.66)

                Spacer()

                Button {
                    // Refresh topics -- currently static, placeholder for future
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Refresh")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.lbG400)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            // 3-column grid
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 8),
                    count: 3
                ),
                spacing: 8
            ) {
                ForEach(viewModel.topicGrid) { topic in
                    Button {
                        viewModel.selectTopic(topic.name)
                    } label: {
                        HStack(spacing: 8) {
                            Text(topic.icon)
                                .font(.system(size: 16))

                            Text(topic.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.lbNearBlack)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.lbWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    viewModel.selectedTopic == topic.name
                                        ? Color.lbBlack : Color.lbG100,
                                    lineWidth: 1.5
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Custom Topic Input

    private var customTopicInput: some View {
        TextField("Or type your own topic...", text: $viewModel.customTopic)
            .font(.system(size: 14))
            .foregroundStyle(Color.lbNearBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.lbG50)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(Color.lbG100, lineWidth: 1.5)
            }
            .padding(.bottom, 14)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            Task {
                await viewModel.createConversation()
            }
        } label: {
            Text("Start conversation")
                .font(.system(size: 15))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.lbBlack)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        }
        .buttonStyle(.plain)
        .opacity(canStart ? 1 : 0.5)
        .disabled(!canStart)
    }

    // MARK: - Helpers

    /// The CTA is enabled when a partner is selected and a topic is chosen or typed.
    private var canStart: Bool {
        guard viewModel.selectedPartner != nil else { return false }
        let hasGridTopic = !viewModel.selectedTopic.isEmpty
        let hasCustomTopic = !viewModel.customTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasGridTopic || hasCustomTopic
    }
}

// MARK: - Preview

#Preview {
    ZStack(alignment: .bottom) {
        Color.lbLinen
            .ignoresSafeArea()

        NewConversationSheet(viewModel: TalkViewModel())
    }
}
