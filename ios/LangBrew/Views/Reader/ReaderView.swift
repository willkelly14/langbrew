import SwiftUI

// MARK: - Reader View

/// The main passage reading screen. Displays passage text with highlighted
/// vocabulary words, scroll-tracked progress, and access to text options
/// and word definition sheets.
struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    init(passage: PassageResponse, vocabulary: [PassageVocabulary]) {
        _viewModel = State(
            wrappedValue: ReaderViewModel(passage: passage, vocabulary: vocabulary)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            viewModel.readingTheme.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar at the very top
                readingProgressBar

                // Navigation bar
                readerNavBar

                // Passage content
                passageScrollView
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showTextOptions) {
            TextOptionsSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.lbWhite)
        }
        .sheet(isPresented: $viewModel.showWordDefinition) {
            WordDefinitionSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.lbWhite)
        }
        .sheet(isPresented: $viewModel.showWordDetail) {
            WordDetailSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.lbWhite)
        }
        .sheet(isPresented: $viewModel.showPhrasePopup) {
            PhraseTranslationPopup(viewModel: viewModel)
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.lbWhite)
        }
    }

    // MARK: - Progress Bar

    private var readingProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(viewModel.readingTheme.backgroundColor)
                    .frame(height: 3)

                Rectangle()
                    .fill(viewModel.readingTheme.textColor.opacity(0.3))
                    .frame(
                        width: geometry.size.width * viewModel.readingProgress,
                        height: 3
                    )
                    .animation(.easeOut(duration: 0.2), value: viewModel.readingProgress)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Navigation Bar

    private var readerNavBar: some View {
        HStack {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(viewModel.readingTheme.textColor)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Title
            Text(viewModel.passage.title)
                .font(LBTheme.Typography.bodyMedium)
                .foregroundStyle(viewModel.readingTheme.textColor)
                .lineLimit(1)

            Spacer()

            // Listening icon (disabled)
            listeningButton

            // Text options
            Button {
                viewModel.showTextOptions = true
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewModel.readingTheme.textColor)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, LBTheme.Spacing.sm)
        .background(viewModel.readingTheme.navBarColor)
    }

    private var listeningButton: some View {
        Button {} label: {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(viewModel.readingTheme.secondaryTextColor.opacity(0.4))
                .frame(width: 44, height: 44)
        }
        .disabled(true)
        .overlay(alignment: .bottom) {
            Text("Soon")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(viewModel.readingTheme.secondaryTextColor.opacity(0.5))
                .offset(y: -2)
        }
    }

    // MARK: - Passage Scroll View

    private var passageScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.xl) {
                // Passage metadata header
                passageHeader

                // Passage body with highlighted words
                HighlightedTextView(
                    content: viewModel.passage.content,
                    vocabulary: viewModel.highlightedVocabulary,
                    allVocabulary: viewModel.vocabulary,
                    fontSize: viewModel.fontSize,
                    lineSpacingValue: viewModel.lineSpacingValue,
                    readingFont: viewModel.readingFont,
                    theme: viewModel.readingTheme,
                    onWordTap: { vocab in
                        viewModel.tapWord(vocab)
                    },
                    onWordLongPress: { word in
                        viewModel.longPressWord(word)
                    },
                    onPhraseSelect: { start, end in
                        viewModel.selectPhrase(startIndex: start, endIndex: end)
                    }
                )

                // End of passage marker
                endOfPassage
            }
            .padding(.horizontal, LBTheme.Spacing.xl)
            .padding(.top, LBTheme.Spacing.lg)
            .padding(.bottom, LBTheme.Spacing.xxxl * 2)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).origin.y
                        )
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            updateScrollProgress(offset: offset)
        }
    }

    // MARK: - Passage Header

    private var passageHeader: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            HStack(spacing: LBTheme.Spacing.sm) {
                LBPill(viewModel.passage.cefrLevel, variant: .filled)
                LBPill(viewModel.passage.topic, variant: .outlined)
            }

            Text(viewModel.passage.title)
                .font(LBTheme.Typography.title)
                .foregroundStyle(viewModel.readingTheme.textColor)

            HStack(spacing: LBTheme.Spacing.md) {
                Label(viewModel.passage.wordCountLabel, systemImage: "text.word.spacing")
                Label(viewModel.passage.readingTimeLabel, systemImage: "clock")
            }
            .font(LBTheme.Typography.caption)
            .foregroundStyle(viewModel.readingTheme.secondaryTextColor)
        }
        .padding(.bottom, LBTheme.Spacing.md)
    }

    // MARK: - End of Passage

    private var endOfPassage: some View {
        VStack(spacing: LBTheme.Spacing.md) {
            Divider()
                .background(viewModel.readingTheme.secondaryTextColor.opacity(0.2))

            HStack(spacing: LBTheme.Spacing.sm) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                Text("End of passage")
                    .font(LBTheme.Typography.caption)
            }
            .foregroundStyle(viewModel.readingTheme.secondaryTextColor)
        }
        .padding(.top, LBTheme.Spacing.xl)
    }

    // MARK: - Scroll Progress

    private func updateScrollProgress(offset: CGFloat) {
        // Negative offset means scrolled down.
        // Map the scroll offset to a 0-1 progress value.
        let scrolled = -offset
        // Approximate total scrollable height based on content.
        let estimatedHeight = CGFloat(viewModel.passage.wordCount) * 2.5
        let progress = max(0, min(1, scrolled / max(estimatedHeight, 1)))
        viewModel.updateProgress(progress)
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Word Detail Sheet

/// An expanded word detail sheet shown on long-press of any word.
/// Displays all available information including multiple definitions,
/// conjugation hints, and usage notes.
struct WordDetailSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LBBottomSheet {
            if viewModel.isLoadingDefinition {
                VStack(spacing: LBTheme.Spacing.md) {
                    ProgressView()
                        .tint(Color.lbBlack)
                    Text("Looking up word...")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LBTheme.Spacing.xxl)
            } else if let vocab = viewModel.selectedVocab {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.lg) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                            Text(vocab.word)
                                .font(LBTheme.Typography.title)
                                .foregroundStyle(Color.lbBlack)

                            if let phonetic = vocab.phonetic {
                                Text(phonetic)
                                    .font(LBTheme.Typography.body)
                                    .italic()
                                    .foregroundStyle(Color.lbG400)
                            }
                        }

                        Spacer()

                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.lbG300)
                        }
                    }

                    // Word type
                    if let wordType = vocab.wordType {
                        LBPill(wordType, variant: .highlight)
                    }

                    // Translation
                    if let translation = vocab.translation {
                        HStack(spacing: LBTheme.Spacing.sm) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.lbG400)
                            Text(translation)
                                .font(LBTheme.Typography.bodyMedium)
                                .foregroundStyle(Color.lbBlack)
                        }
                    }

                    // Definitions
                    if let definitions = vocab.definitions, !definitions.isEmpty {
                        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
                            ForEach(Array(definitions.enumerated()), id: \.offset) { index, def in
                                VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                                    Text("\(index + 1). \(def.definition)")
                                        .font(LBTheme.Typography.body)
                                        .foregroundStyle(Color.lbBlack)

                                    if let example = def.example {
                                        Text(example)
                                            .font(LBTheme.Typography.caption)
                                            .italic()
                                            .foregroundStyle(Color.lbG500)
                                    }
                                }
                            }
                        }
                    } else if let definition = vocab.definition {
                        Text(definition)
                            .font(LBTheme.Typography.body)
                            .foregroundStyle(Color.lbBlack)
                    }

                    // Conjugation hint
                    if let conjugation = vocab.conjugationHint {
                        VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                            Text("Conjugation")
                                .font(LBTheme.Typography.caption)
                                .foregroundStyle(Color.lbG400)
                            Text(conjugation)
                                .font(LBTheme.Typography.caption)
                                .foregroundStyle(Color.lbG500)
                        }
                        .padding(LBTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lbG50)
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))
                    }

                    // Usage notes
                    if let notes = vocab.usageNotes {
                        HStack(alignment: .top, spacing: LBTheme.Spacing.sm) {
                            Image(systemName: "lightbulb")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.lbG400)
                            Text(notes)
                                .font(LBTheme.Typography.caption)
                                .foregroundStyle(Color.lbG500)
                        }
                    }

                    // Add to Language Bank
                    if !viewModel.addedWords.contains(vocab.word) {
                        LBButton("Add to Language Bank", variant: .primary, icon: "plus", fullWidth: true) {
                            viewModel.addWordToBank()
                        }
                    } else {
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
                    }
                }
            }
        }
    }
}

// MARK: - Phrase Translation Popup

/// A compact popup shown when the user selects a phrase (multi-word range).
/// Displays the original phrase, its translation, and optional context.
struct PhraseTranslationPopup: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LBBottomSheet {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.lg) {
                // Header
                HStack(alignment: .top) {
                    Text("Phrase Translation")
                        .font(LBTheme.Typography.title2)
                        .foregroundStyle(Color.lbBlack)

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.lbG300)
                    }
                }

                if let phrase = viewModel.selectedPhrase {
                    // Original phrase
                    Text(phrase)
                        .font(LBTheme.Typography.bodyMedium)
                        .italic()
                        .foregroundStyle(Color.lbBlack)
                        .padding(LBTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lbHighlight)
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))

                    // Translation
                    if let translation = viewModel.phraseTranslation {
                        VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                            HStack(spacing: LBTheme.Spacing.sm) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.lbG400)
                                Text(translation.translation)
                                    .font(LBTheme.Typography.body)
                                    .foregroundStyle(Color.lbBlack)
                            }

                            if let context = translation.context {
                                Text(context)
                                    .font(LBTheme.Typography.caption)
                                    .foregroundStyle(Color.lbG500)
                            }
                        }
                    }

                    // Save phrase button
                    LBButton("Save Phrase", variant: .primary, icon: "bookmark", fullWidth: true) {
                        viewModel.savePhrase()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReaderView(
            passage: MockData.samplePassage,
            vocabulary: MockData.sampleVocabulary
        )
    }
}
