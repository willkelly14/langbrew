import SwiftUI

// MARK: - Word Definition Sheet

/// A bottom sheet shown when the user taps a vocabulary word.
/// Layout:
///   Word heading + phonetic + POS badge
///   ─────────────────────────────────────
///   MEANING        — English meanings (numbered if >1)
///   IN CONTEXT     — English meaning in this passage's context
///   SENTENCE       — Context sentence from the passage + translation
///   EXAMPLE        — Example sentence + translation
///   [+ Language Bank] button
struct WordDefinitionSheet: View {
    @Bindable var viewModel: ReaderViewModel
    var onDismiss: (() -> Void)?

    /// The word to display -- available immediately even while loading.
    private var displayWord: String {
        viewModel.selectedVocab?.word ?? viewModel.selectedWord ?? ""
    }

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 0) {
                // ── Word heading ──
                Text(displayWord)
                    .font(LBTheme.serifFont(size: 28))
                    .foregroundStyle(Color.lbBlack)
                    .padding(.bottom, 4)

                if let vocab = viewModel.selectedVocab {
                    headerSection(vocab: vocab)
                    divider

                    meaningSection(vocab: vocab)
                    inContextSection(vocab: vocab)
                    sentenceSection(vocab: vocab)
                    exampleSection(vocab: vocab)

                    addToLanguageBankSection
                } else if viewModel.isLoadingDefinition {
                    divider
                    ProgressView()
                        .tint(Color.lbBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LBTheme.Spacing.lg)
                } else if let error = viewModel.definitionError {
                    divider
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbG500)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, LBTheme.Spacing.md)

                    Button {
                        viewModel.retryDefinition()
                    } label: {
                        Text("Try Again")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.lbBlack)
                            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Shared divider

    private var divider: some View {
        Divider()
            .background(Color.lbG100)
            .padding(.top, 2)
            .padding(.bottom, 14)
    }

    // MARK: - Header (Phonetic + POS + Speaker)

    @ViewBuilder
    private func headerSection(vocab: PassageVocabulary) -> some View {
        if let phonetic = vocab.phonetic {
            Text(phonetic)
                .font(.custom("Georgia", size: 14))
                .italic()
                .foregroundStyle(Color.lbG500)
                .padding(.bottom, 8)
        }

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
    }

    // MARK: - 1. Meaning (English meanings from definitions)

    @ViewBuilder
    private func meaningSection(vocab: PassageVocabulary) -> some View {
        let meanings = (vocab.definitions ?? []).compactMap { def in
            (def.meaning?.isEmpty == false) ? def.meaning : nil
        }

        // Fall back: use the flat translation field (English meaning)
        // or the flat definition field as a last resort.
        let fallback: String? = {
            if let t = vocab.translation, !t.isEmpty { return t }
            if let d = vocab.definition, !d.isEmpty { return d }
            return nil
        }()

        if !meanings.isEmpty {
            sectionLabel("Meaning")

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(meanings.enumerated()), id: \.offset) { index, meaning in
                    Text(meanings.count > 1 ? "\(index + 1). \(meaning)" : meaning)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.lbNearBlack)
                        .lineSpacing(15 * 0.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, LBTheme.Spacing.lg)
        } else if let text = fallback {
            sectionLabel("Meaning")

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.lbNearBlack)
                .lineSpacing(15 * 0.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, LBTheme.Spacing.lg)
        }
    }

    // MARK: - 2. In-Context Meaning

    @ViewBuilder
    private func inContextSection(vocab: PassageVocabulary) -> some View {
        // Only show when it differs from the first meaning — avoids redundancy
        let firstMeaning = (vocab.definitions ?? []).first?.meaning
        let inContext = vocab.translation

        if let inContext, !inContext.isEmpty,
           inContext.lowercased() != (firstMeaning ?? "").lowercased() {
            sectionLabel("In This Passage")

            Text(inContext)
                .font(.system(size: 15))
                .foregroundStyle(Color.lbNearBlack)
                .lineSpacing(15 * 0.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, LBTheme.Spacing.lg)
        }
    }

    // MARK: - 3. Context Sentence + Translation

    @ViewBuilder
    private func sentenceSection(vocab: PassageVocabulary) -> some View {
        if let sentence = viewModel.wordContextSentence {
            sectionLabel("Sentence")

            highlightedSentenceText(sentence, highlightWord: vocab.word)
                .padding(.bottom, 4)

            if viewModel.isLoadingWordContext, viewModel.wordContextTranslation == nil {
                ProgressView()
                    .tint(Color.lbG500)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, LBTheme.Spacing.lg)
            } else if let translation = viewModel.wordContextTranslation {
                Text(translation)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(Color.lbG500)
                    .lineSpacing(14 * 0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, LBTheme.Spacing.lg)
            } else if let error = viewModel.wordContextTranslationError {
                HStack(spacing: 4) {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lbG400)
                    Button {
                        viewModel.retryContextTranslation()
                    } label: {
                        Text("Retry")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.lbG500)
                            .underline()
                    }
                }
                .padding(.bottom, LBTheme.Spacing.lg)
            } else {
                Spacer()
                    .frame(height: LBTheme.Spacing.lg)
            }
        }
    }

    // MARK: - 4. Example Sentence + Translation

    @ViewBuilder
    private func exampleSection(vocab: PassageVocabulary) -> some View {
        if let example = vocab.exampleSentence {
            sectionLabel("Example")

            highlightedSentenceText(example, highlightWord: vocab.word)
                .padding(.bottom, 4)

            if viewModel.isLoadingWordContext, viewModel.wordExampleTranslation == nil {
                ProgressView()
                    .tint(Color.lbG500)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, LBTheme.Spacing.md)
            } else if let translation = viewModel.wordExampleTranslation {
                Text(translation)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(Color.lbG500)
                    .lineSpacing(14 * 0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, LBTheme.Spacing.md)
            } else if let error = viewModel.wordExampleTranslationError {
                HStack(spacing: 4) {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lbG400)
                    Button {
                        viewModel.retryExampleTranslation()
                    } label: {
                        Text("Retry")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.lbG500)
                            .underline()
                    }
                }
                .padding(.bottom, LBTheme.Spacing.md)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.lbG500)
            .kerning(0.8)
            .textCase(.uppercase)
            .padding(.bottom, 6)
    }

    private func highlightedSentenceText(_ sentence: String, highlightWord: String) -> some View {
        let parts = sentence.components(separatedBy: highlightWord)
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
                HStack(spacing: LBTheme.Spacing.sm) {
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
