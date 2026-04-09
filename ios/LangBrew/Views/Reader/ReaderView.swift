import SwiftUI

// MARK: - Reader View

/// The main passage reading screen. Displays passage text with highlighted
/// vocabulary words, scroll-tracked progress, and access to text options
/// and word definition sheets.
///
/// Mockup: no metadata header in reader, progress bar at bottom,
/// bottom bar with page label + chapter + TOC icon.
struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    init(passage: PassageResponse, vocabulary: [PassageVocabulary]) {
        _viewModel = State(
            wrappedValue: ReaderViewModel(passage: passage, vocabulary: vocabulary)
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                readerNavBar

                // Passage content
                passageScrollView
            }

            // Bottom bar (overlaid)
            readerBottomBar
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
            SentenceTranslationSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.lbWhite)
        }
        .sheet(isPresented: $viewModel.showPhrasePopup) {
            PhraseTranslationSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.lbWhite)
        }
    }

    // MARK: - Navigation Bar

    private var readerNavBar: some View {
        HStack {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.lbBlack)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Title
            Text(viewModel.passage.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.lbG500)
                .lineLimit(1)

            Spacer()

            // Listening icon
            Button {} label: {
                Image(systemName: "headphones")
                    .font(.system(size: 20, weight: .regular))
                    .imageScale(.medium)
                    .foregroundStyle(Color.lbBlack)
                    .frame(width: 44, height: 44)
            }
            .disabled(true)
            .opacity(0.4)

            // Text options (Aa icon)
            Button {
                viewModel.showTextOptions = true
            } label: {
                Text("Aa")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.lbBlack)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, LBTheme.Spacing.sm)
    }

    // MARK: - Passage Scroll View

    private var passageScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Passage body with highlighted words (no metadata header)
                HighlightedTextView(
                    content: viewModel.passage.content,
                    vocabulary: viewModel.highlightedVocabulary,
                    allVocabulary: viewModel.vocabulary,
                    fontSize: viewModel.fontSize,
                    lineSpacingValue: viewModel.lineSpacingValue,
                    readingFont: viewModel.readingFont,
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
            .padding(.horizontal, 36)
            .padding(.top, 20)
            .padding(.bottom, 80)
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

    // MARK: - End of Passage

    private var endOfPassage: some View {
        VStack(spacing: LBTheme.Spacing.md) {
            Divider()
                .background(Color.lbG200)

            HStack(spacing: LBTheme.Spacing.sm) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                Text("End of passage")
                    .font(LBTheme.Typography.caption)
            }
            .foregroundStyle(Color.lbG400)
        }
        .padding(.top, LBTheme.Spacing.xl)
    }

    // MARK: - Bottom Bar

    /// Progress line at top, then page label / chapter / TOC icon.
    /// Gradient bg from transparent to linen.
    private var readerBottomBar: some View {
        VStack(spacing: 0) {
            // Progress line (2px height, g100 track, black fill)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.lbG100)
                        .frame(height: 2)

                    Rectangle()
                        .fill(Color.lbBlack)
                        .frame(
                            width: geometry.size.width * viewModel.readingProgress,
                            height: 2
                        )
                        .animation(.easeOut(duration: 0.2), value: viewModel.readingProgress)
                }
            }
            .frame(height: 2)

            // Bar content
            HStack {
                // Page label
                Text("1 / 1")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lbG400)

                Spacer()

                // Chapter name (center)
                Text(viewModel.passage.topic)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lbG400)

                Spacer()

                // TOC icon
                Button {} label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.lbG400)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.vertical, LBTheme.Spacing.sm)
        }
        .background(
            LinearGradient(
                colors: [Color.lbLinen.opacity(0), Color.lbLinen],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    // MARK: - Scroll Progress

    private func updateScrollProgress(offset: CGFloat) {
        let scrolled = -offset
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

// MARK: - Sentence Translation Sheet (4c)

/// Shown on long-press of a word. Displays the sentence containing the word
/// with translation, language badge, and action buttons.
struct SentenceTranslationSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LBBottomSheet {
            if viewModel.isLoadingDefinition {
                VStack(spacing: LBTheme.Spacing.md) {
                    ProgressView()
                        .tint(Color.lbBlack)
                    Text("Translating...")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LBTheme.Spacing.xxl)
            } else if let vocab = viewModel.selectedVocab {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.lg) {
                    // Original text (the word or sentence)
                    Text(vocab.exampleSentence ?? vocab.word)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.lbBlack)
                        .lineSpacing(20 * 0.4)

                    // Language row
                    HStack(spacing: LBTheme.Spacing.md) {
                        Text("Spanish \u{2192} English")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.lbG500)
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.lbG100)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Speaker button
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

                    // Divider
                    Divider()
                        .background(Color.lbG100)

                    // Translation result
                    Text(vocab.definition ?? vocab.translation ?? "Translation unavailable")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.lbNearBlack)
                        .lineSpacing(15 * 0.6)

                    // Two buttons: Copy + Save Sentence
                    HStack(spacing: LBTheme.Spacing.md) {
                        Button {
                            UIPasteboard.general.string = vocab.definition ?? vocab.translation ?? ""
                        } label: {
                            Text("Copy")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.lbG500)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.lbG100)
                                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.addWordToBank()
                            dismiss()
                        } label: {
                            Text("Save Sentence")
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
    }
}

// MARK: - Phrase Translation Sheet (4c2)

/// Shown when the user selects a phrase. Displays original phrase,
/// language badge, translation, and Copy + Save Phrase buttons.
struct PhraseTranslationSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LBBottomSheet {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.lg) {
                if let phrase = viewModel.selectedPhrase {
                    // Original phrase
                    Text(phrase)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.lbBlack)
                        .lineSpacing(20 * 0.4)

                    // Language row
                    HStack(spacing: LBTheme.Spacing.md) {
                        Text("Spanish \u{2192} English")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.lbG500)
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.lbG100)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

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

                    // Divider
                    Divider()
                        .background(Color.lbG100)

                    // Translation
                    if let translation = viewModel.phraseTranslation {
                        Text(translation.translation)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.lbNearBlack)
                            .lineSpacing(15 * 0.6)
                    } else {
                        ProgressView()
                            .tint(Color.lbBlack)
                            .frame(maxWidth: .infinity)
                    }

                    // Two buttons: Copy + Save Phrase
                    HStack(spacing: LBTheme.Spacing.md) {
                        Button {
                            UIPasteboard.general.string = viewModel.phraseTranslation?.translation ?? ""
                        } label: {
                            Text("Copy")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.lbG500)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.lbG100)
                                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.savePhrase()
                        } label: {
                            Text("Save Phrase")
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
