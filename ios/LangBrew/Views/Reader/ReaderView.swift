import SwiftUI

// MARK: - Reader View

/// The main passage reading screen. Displays passage text with highlighted
/// vocabulary words, scroll-tracked progress, and access to text options
/// and word definition sheets.
struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hideTabBar) private var hideTabBar

    init(passage: PassageResponse, vocabulary: [PassageVocabulary]) {
        _viewModel = State(
            wrappedValue: ReaderViewModel(passage: passage, vocabulary: vocabulary)
        )
    }

    /// Whether any sheet overlay is currently visible.
    private var isShowingSheet: Bool {
        viewModel.showTextOptions || viewModel.showWordDefinition
            || viewModel.showWordDetail || viewModel.showPhrasePopup
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            readerNavBar

            // Passage content
            passageScrollView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lbLinen.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            readerBottomBar
        }
        .overlay {
            if isShowingSheet {
                sheetOverlay
            }
        }
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.25), value: isShowingSheet)
        .onAppear { hideTabBar.wrappedValue = true }
        .onDisappear { hideTabBar.wrappedValue = false }
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
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
    }

    // MARK: - Passage Scroll View

    private var passageScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HighlightedTextView(
                    content: viewModel.passage.content,
                    vocabulary: viewModel.highlightedVocabulary,
                    allVocabulary: viewModel.vocabulary,
                    fontSize: viewModel.fontSize,
                    lineSpacingValue: viewModel.lineSpacingValue,
                    readingFont: viewModel.readingFont,
                    selectedWord: viewModel.selectedWord,
                    selectedSentenceRange: viewModel.selectedSentenceRange,
                    onWordTap: { vocab in
                        viewModel.tapWord(vocab)
                    },
                    onNonHighlightedWordTap: { word in
                        viewModel.tapNonHighlightedWord(word)
                    },
                    onWordLongPress: { word, position in
                        viewModel.longPressWord(word, at: position)
                    },
                    onPhraseSelect: { start, end in
                        viewModel.selectPhrase(startIndex: start, endIndex: end)
                    }
                )

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

    private var readerBottomBar: some View {
        VStack(spacing: 0) {
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

            HStack {
                Text("1 / 1")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lbG400)

                Spacer()

                Text(viewModel.passage.topic)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lbG400)

                Spacer()

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

    // MARK: - Sheet Overlay

    @ViewBuilder
    private var sheetOverlay: some View {
        ZStack(alignment: .bottom) {
            // Scrim
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissActiveSheet()
                }
                .transition(.opacity)

            // Sheet content
            Group {
                if viewModel.showWordDefinition {
                    WordDefinitionSheet(viewModel: viewModel, onDismiss: { viewModel.dismissActiveSheet() })
                } else if viewModel.showWordDetail {
                    SentenceTranslationSheet(viewModel: viewModel)
                } else if viewModel.showPhrasePopup {
                    PhraseTranslationSheet(viewModel: viewModel, onDismiss: { viewModel.dismissActiveSheet() })
                } else if viewModel.showTextOptions {
                    TextOptionsSheet(viewModel: viewModel, onDismiss: { viewModel.dismissActiveSheet() })
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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

struct SentenceTranslationSheet: View {
    @Bindable var viewModel: ReaderViewModel

    var body: some View {
        LBBottomSheet(onDismiss: { viewModel.dismissActiveSheet() }) {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.lg) {
                // Original sentence from the passage
                if let sentence = viewModel.selectedSentence {
                    Text(sentence)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.lbBlack)
                        .lineSpacing(20 * 0.4)
                }

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

                Divider()
                    .background(Color.lbG100)

                // Translation
                if viewModel.isLoadingSentenceTranslation {
                    ProgressView()
                        .tint(Color.lbBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LBTheme.Spacing.md)
                } else if let translation = viewModel.sentenceTranslation {
                    Text(translation)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.lbNearBlack)
                        .lineSpacing(15 * 0.6)
                }

                // Buttons
                HStack(spacing: LBTheme.Spacing.md) {
                    Button {
                        UIPasteboard.general.string = viewModel.sentenceTranslation ?? ""
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
                        viewModel.dismissActiveSheet()
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

// MARK: - Phrase Translation Sheet (4c2)

struct PhraseTranslationSheet: View {
    @Bindable var viewModel: ReaderViewModel
    var onDismiss: (() -> Void)?

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.lg) {
                if let phrase = viewModel.selectedPhrase {
                    Text(phrase)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.lbBlack)
                        .lineSpacing(20 * 0.4)

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

                    Divider()
                        .background(Color.lbG100)

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
