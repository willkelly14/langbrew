import SwiftUI

/// Post-conversation feedback screen (Screen 3c).
struct FeedbackView: View {
    let conversationId: String
    let topic: String
    @State private var viewModel = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.lbLinen.ignoresSafeArea()

            if viewModel.isLoading {
                FeedbackLoadingView()
            } else if let feedback = viewModel.feedback {
                feedbackContent(feedback)
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("Retry") {
                Task { await viewModel.loadFeedback() }
            }
            Button("Go Back", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Could not load feedback.")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.lbBlack)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Your Feedback")
                    .font(LBTheme.serifFont(size: 22))
                    .foregroundStyle(Color.lbBlack)
            }
        }
        .task {
            viewModel.conversationId = conversationId
            viewModel.topic = topic
            await viewModel.loadFeedback()
        }
    }

    // MARK: - Feedback Content

    private func feedbackContent(_ feedback: ConversationFeedback) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                scoreCard(feedback)

                sectionTitle("Skill Breakdown")
                skillsCard(feedback)

                if let strengths = feedback.strengths {
                    sectionTitle("What You Did Well")
                    calloutCard(
                        label: strengths.label.uppercased(),
                        text: strengths.text,
                        bgColor: Color(hex: "E8F5E9"),
                        labelColor: Color(hex: "2E7D32")
                    )
                }

                if let corrections = feedback.corrections, !corrections.isEmpty {
                    sectionTitle("Corrections")
                    ForEach(corrections) { correction in
                        correctionCard(correction)
                    }
                }

                if let tips = feedback.tips {
                    sectionTitle("Tip for Next Time")
                    calloutCard(
                        label: tips.label.uppercased(),
                        text: tips.text,
                        bgColor: Color(hex: "FFF8E1"),
                        labelColor: Color(hex: "E65100")
                    )
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.lbBlack)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Score Card

    private func scoreCard(_ feedback: ConversationFeedback) -> some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.lbG100, lineWidth: 6)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: viewModel.scoreProgress)
                    .stroke(
                        Color.lbBlack,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                Text(feedback.letterGrade)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.lbNearBlack)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.topicLabel.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lbG400)
                    .kerning(0.5)

                Text(feedback.summary ?? "")
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(Color.lbNearBlack)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 20)
    }

    // MARK: - Skills Card

    private func skillsCard(_ feedback: ConversationFeedback) -> some View {
        VStack(spacing: 14) {
            skillRow("Grammar", feedback.grammarScore)
            skillRow("Vocabulary", feedback.vocabularyScore)
            skillRow("Fluency", feedback.fluencyScore)
            skillRow("Confidence", feedback.confidenceScore)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 20)
    }

    private func skillRow(_ name: String, _ score: Int) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.lbNearBlack)
                .frame(width: 76, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.lbG100)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.lbBlack)
                        .frame(
                            width: geo.size.width * CGFloat(score) / 100.0,
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            Text("\(score)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.lbG500)
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Section Title

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(LBTheme.serifFont(size: 17))
            .foregroundStyle(Color.lbBlack)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }

    // MARK: - Callout Card

    private func calloutCard(
        label: String,
        text: String,
        bgColor: Color,
        labelColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(labelColor)
                .kerning(0.5)

            Text(text)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(Color.lbNearBlack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 12)
    }

    // MARK: - Correction Card

    private func correctionCard(_ correction: CorrectionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text(correction.original)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "C62828"))
                    .strikethrough()

                Text("  \u{2192}  ")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.lbG300)

                Text(correction.corrected)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "2E7D32"))
            }

            Text(correction.explanation)
                .font(.system(size: 12))
                .foregroundStyle(Color.lbG400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 8)
    }
}

// MARK: - Feedback Loading View

/// Full-screen loading animation shown while feedback is being generated.
/// Reuses the floating words and bouncing dots from PassageLoadingView
/// with feedback-specific status messages.
private struct FeedbackLoadingView: View {
    @State private var currentMessageIndex: Int = 0
    @State private var messageOpacity: Double = 1.0

    private let messages = [
        "Reviewing your conversation...",
        "Analyzing your grammar...",
        "Checking vocabulary usage...",
        "Measuring fluency...",
        "Noting your strengths...",
        "Preparing corrections...",
        "Almost ready...",
    ]

    private let messageTimer = Timer.publish(
        every: 2.5, on: .main, in: .common
    ).autoconnect()

    var body: some View {
        ZStack {
            Color.lbLinen.ignoresSafeArea()

            FloatingWordsView()

            VStack(spacing: LBTheme.Spacing.lg) {
                Spacer()

                Text(messages[currentMessageIndex])
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.lbNearBlack)
                    .opacity(messageOpacity)
                    .animation(.easeInOut(duration: 0.4), value: messageOpacity)

                BouncingDots()

                Spacer()
                Spacer()
            }
        }
        .onReceive(messageTimer) { _ in
            cycleMessage()
        }
    }

    private func cycleMessage() {
        withAnimation(.easeOut(duration: 0.3)) {
            messageOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            currentMessageIndex = (currentMessageIndex + 1) % messages.count
            withAnimation(.easeIn(duration: 0.3)) {
                messageOpacity = 1
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView(conversationId: "preview", topic: "Weekend Plans")
    }
}
