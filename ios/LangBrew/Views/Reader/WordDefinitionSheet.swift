import SwiftUI

// MARK: - Word Definition Sheet

/// A bottom sheet shown when the user taps a highlighted vocabulary word.
/// Displays the word, pronunciation, type, definition, example sentence,
/// and an "Add to Language Bank" button with undo support.
struct WordDefinitionSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LBBottomSheet {
            if let vocab = viewModel.selectedVocab {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.lg) {
                    // Header with dismiss
                    sheetHeader(vocab: vocab)

                    // Phonetic pronunciation
                    if let phonetic = vocab.phonetic {
                        Text(phonetic)
                            .font(LBTheme.Typography.body)
                            .italic()
                            .foregroundStyle(Color.lbG400)
                    }

                    // Word type and speaker
                    wordTypeRow(vocab: vocab)

                    // Definition
                    if let definition = vocab.definition {
                        Text(definition)
                            .font(LBTheme.Typography.body)
                            .foregroundStyle(Color.lbBlack)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Example sentence
                    if let example = vocab.exampleSentence {
                        exampleSentenceView(example)
                    }

                    // Add to Language Bank button
                    addToLanguageBankButton
                }
            } else {
                emptyState
            }
        }
    }

    // MARK: - Header

    private func sheetHeader(vocab: PassageVocabulary) -> some View {
        HStack(alignment: .top) {
            Text(vocab.word)
                .font(LBTheme.Typography.title)
                .foregroundStyle(Color.lbBlack)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.lbG300)
            }
        }
    }

    // MARK: - Word Type Row

    private func wordTypeRow(vocab: PassageVocabulary) -> some View {
        HStack(spacing: LBTheme.Spacing.md) {
            if let wordType = vocab.wordType {
                LBPill(wordType, variant: .highlight)
            }

            Spacer()

            // Speaker button (disabled)
            speakerButton
        }
    }

    private var speakerButton: some View {
        HStack(spacing: LBTheme.Spacing.xs) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 14))
                .foregroundStyle(Color.lbG300)

            Text("Coming soon")
                .font(.system(size: 10))
                .foregroundStyle(Color.lbG300)
        }
        .padding(.horizontal, LBTheme.Spacing.sm)
        .padding(.vertical, LBTheme.Spacing.xs)
        .background(Color.lbG50)
        .clipShape(Capsule())
    }

    // MARK: - Example Sentence

    private func exampleSentenceView(_ example: String) -> some View {
        HStack(alignment: .top, spacing: LBTheme.Spacing.sm) {
            Rectangle()
                .fill(Color.lbG200)
                .frame(width: 3)

            Text(example)
                .font(LBTheme.Typography.body)
                .italic()
                .foregroundStyle(Color.lbG500)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, LBTheme.Spacing.xs)
    }

    // MARK: - Add to Language Bank

    private var addToLanguageBankButton: some View {
        Group {
            switch viewModel.wordAdditionState {
            case .idle:
                LBButton("Add to Language Bank", variant: .primary, icon: "plus", fullWidth: true) {
                    viewModel.addWordToBank()
                }

            case .added:
                VStack(spacing: LBTheme.Spacing.sm) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.lbBlack)
                        Text("Added")
                            .font(LBTheme.Typography.bodyMedium)
                            .foregroundStyle(Color.lbBlack)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LBTheme.Spacing.md)
                    .background(Color.lbHighlight)
                    .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))

                    Button {
                        viewModel.undoAddWord()
                    } label: {
                        Text("Undo")
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(Color.lbG500)
                            .underline()
                    }
                }

            case .undone:
                LBButton("Add to Language Bank", variant: .primary, icon: "plus", fullWidth: true) {
                    viewModel.addWordToBank()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.wordAdditionState)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: LBTheme.Spacing.md) {
            ProgressView()
                .tint(Color.lbBlack)
            Text("Loading definition...")
                .font(LBTheme.Typography.body)
                .foregroundStyle(Color.lbG500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LBTheme.Spacing.xxl)
    }
}

// MARK: - Preview

#Preview("Word Definition") {
    let vm = ReaderViewModel(
        passage: MockData.samplePassage,
        vocabulary: MockData.sampleVocabulary
    )
    vm.selectedVocab = MockData.sampleVocabulary[0]
    vm.selectedWord = MockData.sampleVocabulary[0].word

    return WordDefinitionSheet(viewModel: vm)
}
