import SwiftUI

// MARK: - Flashcard Review View

/// The review session screen with front/back card flip, progress bar,
/// and answer buttons.
struct FlashcardReviewView: View {
    @Bindable var viewModel: FlashcardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hideTabBar) private var hideTabBar
    @State private var flipAngle: Double = 0
    @State private var showingFront: Bool = true

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            if viewModel.reviewCompleted {
                reviewCompletedView
            } else {
                VStack(spacing: 0) {
                    reviewNavBar
                    progressBar
                    cardContent
                    Spacer(minLength: 0)
                    answerButtons
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            hideTabBar.wrappedValue = true
        }
        .onDisappear {
            hideTabBar.wrappedValue = false
        }
    }

    // MARK: - Nav Bar

    private var reviewNavBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.lbBlack)
                    .frame(width: 32, height: 32)
                    .background(Color.lbG50)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Daily Review")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.lbBlack)

            Spacer()

            Text(viewModel.counterLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.lbG400)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.lbG100)
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.lbBlack)
                    .frame(width: geometry.size.width * viewModel.reviewProgress, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.reviewProgress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        Group {
            if let card = viewModel.currentCard {
                ZStack {
                    // Front of card
                    CardFrontView(card: card)
                        .opacity(showingFront ? 1 : 0)
                        .rotation3DEffect(
                            .degrees(showingFront ? 0 : 180),
                            axis: (x: 0, y: 1, z: 0)
                        )

                    // Back of card
                    CardBackView(card: card)
                        .opacity(showingFront ? 0 : 1)
                        .rotation3DEffect(
                            .degrees(showingFront ? -180 : 0),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showingFront.toggle()
                        viewModel.isShowingBack = !showingFront
                    }
                }
                .onChange(of: viewModel.currentCardIndex) { _, _ in
                    // Reset flip state when advancing to next card
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingFront = true
                    }
                }
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Answer Buttons

    private var answerButtons: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.answerWrong()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                    Text("I got it wrong")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color.lbG500)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.lbG50)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
            }
            .buttonStyle(.plain)

            Button {
                viewModel.answerCorrect()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .medium))
                    Text("I got it right")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.lbBlack)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .padding(.top, 12)
    }

    // MARK: - Review Completed

    private var reviewCompletedView: some View {
        VStack(spacing: LBTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.lbBlack)

            Text("Session Complete")
                .font(LBTheme.Typography.title)
                .foregroundStyle(Color.lbBlack)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(viewModel.answersCorrect)")
                        .font(LBTheme.serifFont(size: 28))
                        .foregroundStyle(Color.lbBlack)
                    Text("Correct")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG500)
                }

                Rectangle()
                    .fill(Color.lbG200)
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("\(viewModel.answersWrong)")
                        .font(LBTheme.serifFont(size: 28))
                        .foregroundStyle(Color.lbBlack)
                    Text("Missed")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG500)
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.lbBlack)
                    .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Card Front View

/// The front face of a flashcard showing the target-language word,
/// language tag, example sentence, and flip hint.
private struct CardFrontView: View {
    let card: FlashcardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sound button (top right)
            HStack {
                Spacer()
                Button {} label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.lbG500)
                        .frame(width: 40, height: 40)
                        .background(Color.lbG100)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 0)

            // Language tag
            Text(card.frontLanguageTag)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.lbG500)
                .padding(.top, 10)

            // Word
            Text(card.frontText)
                .font(LBTheme.serifFont(size: 38))
                .foregroundStyle(Color.lbBlack)
                .padding(.top, 4)

            // Example sentence
            if !card.exampleSentence.isEmpty {
                highlightedExampleText(
                    sentence: card.exampleSentence,
                    highlight: card.exampleHighlight
                )
                .font(.system(size: 15))
                .lineSpacing(15 * 0.55)
                .foregroundStyle(Color.lbG500)
                .padding(.top, 18)
            }

            Spacer(minLength: 24)

            // Tap to flip hint
            HStack(spacing: 6) {
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG300)
                Text("Tap to flip")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG300)
                Spacer()
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
        .lbShadow(LBTheme.Shadow.card)
    }

    @ViewBuilder
    private func highlightedExampleText(sentence: String, highlight: String) -> some View {
        if highlight.isEmpty || !sentence.contains(highlight) {
            Text(sentence)
        } else {
            let parts = sentence.components(separatedBy: highlight)
            let attributed = parts.enumerated().reduce(Text("")) { result, item in
                let (index, part) = item
                let partText = result + Text(part)
                if index < parts.count - 1 {
                    return partText + Text(highlight).fontWeight(.bold).foregroundColor(.lbBlack)
                }
                return partText
            }
            attributed
        }
    }
}

// MARK: - Card Back View

/// The back face of a flashcard showing the translation,
/// definitions, and example sentences.
private struct CardBackView: View {
    let card: FlashcardItem

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Sound button (top right)
                HStack {
                    Spacer()
                    Button {} label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.lbG500)
                            .frame(width: 40, height: 40)
                            .background(Color.lbG100)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Language tag
                Text(card.frontLanguageTag)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lbG500)
                    .padding(.top, 10)

                // Original word
                Text(card.frontText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lbG400)
                    .padding(.bottom, 20)

                // Definitions
                ForEach(card.definitions) { definition in
                    definitionBlock(definition)
                        .padding(.bottom, 22)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
        .lbShadow(LBTheme.Shadow.card)
    }

    private func definitionBlock(_ definition: FlashcardDefinition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Number
            Text("\(definition.number)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.lbG400)

            // Translation word
            Text(definition.word)
                .font(LBTheme.serifFont(size: 28))
                .foregroundStyle(Color.lbBlack)

            // Example sentence
            if !definition.example.isEmpty {
                highlightedText(
                    sentence: definition.example,
                    highlight: definition.exampleBold
                )
                .font(.system(size: 14))
                .foregroundStyle(Color.lbG500)
            }

            // Translation / meaning
            if !definition.translation.isEmpty {
                Text(definition.translation)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG400)
            }
        }
    }

    @ViewBuilder
    private func highlightedText(sentence: String, highlight: String) -> some View {
        if highlight.isEmpty || !sentence.contains(highlight) {
            Text(sentence)
        } else {
            let parts = sentence.components(separatedBy: highlight)
            let attributed = parts.enumerated().reduce(Text("")) { result, item in
                let (index, part) = item
                let partText = result + Text(part)
                if index < parts.count - 1 {
                    return partText + Text(highlight).fontWeight(.bold).foregroundColor(.lbBlack)
                }
                return partText
            }
            attributed
        }
    }
}

// MARK: - Preview

#Preview("Front") {
    NavigationStack {
        FlashcardReviewView(viewModel: FlashcardViewModel())
    }
}
