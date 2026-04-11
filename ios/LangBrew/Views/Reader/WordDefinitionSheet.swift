import SwiftUI

// MARK: - Word Definition Sheet

/// A bottom sheet shown when the user taps a highlighted vocabulary word.
/// Mockup (4b): word, phonetic, POS+speaker, divider, definition, example,
/// "+ Language Bank" button with "Added to Language Bank" + Undo states.
struct WordDefinitionSheet: View {
    @Bindable var viewModel: ReaderViewModel
    var onDismiss: (() -> Void)?

    /// The word to display — available immediately even while loading.
    private var displayWord: String {
        viewModel.selectedVocab?.word ?? viewModel.selectedWord ?? ""
    }

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 0) {
                // Word — shown immediately
                Text(displayWord)
                    .font(LBTheme.serifFont(size: 28))
                    .foregroundStyle(Color.lbBlack)
                    .padding(.bottom, 4)

                if let vocab = viewModel.selectedVocab {
                    // Phonetic
                    if let phonetic = vocab.phonetic {
                        Text(phonetic)
                            .font(.custom("Georgia", size: 14))
                            .italic()
                            .foregroundStyle(Color.lbG500)
                            .padding(.bottom, 8)
                    }

                    // Part of speech row + Speaker button
                    HStack(spacing: LBTheme.Spacing.md) {
                        if let wordType = vocab.wordType {
                            Text(wordType.localizedCapitalized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.lbG500)
                                .kerning(0.8)
                                .textCase(.uppercase)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.lbG100)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        // Speaker button (28px circle, g100 bg)
                        Button {} label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.lbG500)
                                .frame(width: 28, height: 28)
                                .background(Color.lbG100)
                                .clipShape(Circle())
                        }
                        .disabled(true)

                        Spacer()
                    }
                    .padding(.bottom, 14)

                    // Divider
                    Divider()
                        .background(Color.lbG100)
                        .padding(.bottom, 14)

                    // English meaning (from translation or definitions[].meaning)
                    if let meaning = englishMeaning(for: vocab) {
                        Text(meaning)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.lbNearBlack)
                            .lineSpacing(15 * 0.6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, LBTheme.Spacing.md)
                    }

                    // Example sentence
                    if let example = vocab.exampleSentence {
                        exampleText(example, highlightWord: vocab.word)
                            .padding(.bottom, LBTheme.Spacing.lg)
                    }

                    // Add to Language Bank / Added state
                    addToLanguageBankSection
                } else if viewModel.isLoadingDefinition {
                    // Loading spinner below the word, like phrase/sentence popups
                    Divider()
                        .background(Color.lbG100)
                        .padding(.top, 10)
                        .padding(.bottom, 14)

                    ProgressView()
                        .tint(Color.lbBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LBTheme.Spacing.lg)
                }
            }
        }
    }

    // MARK: - English Meaning

    /// Returns the best English meaning: prefers translation, then first definition's meaning,
    /// then falls back to the definition field itself.
    private func englishMeaning(for vocab: PassageVocabulary) -> String? {
        if let translation = vocab.translation, !translation.isEmpty {
            return translation
        }
        if let meaning = vocab.definitions?.first?.meaning, !meaning.isEmpty {
            return meaning
        }
        return vocab.definition
    }

    // MARK: - Example Text

    /// Renders the example sentence with the vocab word bolded.
    private func exampleText(_ example: String, highlightWord: String) -> some View {
        let parts = example.components(separatedBy: highlightWord)
        var result = Text("")
        for (index, part) in parts.enumerated() {
            result = result + Text(part)
                .font(.system(size: 14))
                .italic()
                .foregroundColor(Color.lbG500)
            if index < parts.count - 1 {
                result = result + Text(highlightWord)
                    .font(.system(size: 14, weight: .bold))
                    .italic()
                    .foregroundColor(Color.lbG500)
            }
        }
        return result
            .lineSpacing(14 * 0.55)
    }

    // MARK: - Add to Language Bank

    private var addToLanguageBankSection: some View {
        Group {
            switch viewModel.wordAdditionState {
            case .idle, .undone:
                // "+ Language Bank" button
                Button {
                    viewModel.addWordToBank()
                } label: {
                    Text("+ Language Bank")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.lbBlack)
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                }
                .buttonStyle(.plain)

            case .added:
                // "Added to Language Bank" state
                HStack(spacing: LBTheme.Spacing.sm) {
                    // Checkmark in circle
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.lbG500)
                        .frame(width: 22, height: 22)
                        .background(Color.lbG100)
                        .clipShape(Circle())

                    Text("Added to Language Bank")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lbG500)

                    Spacer()

                    // Undo link
                    Button {
                        viewModel.undoAddWord()
                    } label: {
                        Text("Undo")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.lbG400)
                            .underline()
                    }
                }
                .padding(.vertical, LBTheme.Spacing.md)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.wordAdditionState)
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
