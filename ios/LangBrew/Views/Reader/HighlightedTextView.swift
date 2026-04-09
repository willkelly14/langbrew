import SwiftUI

// MARK: - Word Segment

/// Represents a segment of passage text that may or may not be a vocabulary word.
private struct WordSegment: Identifiable {
    let id: Int
    let text: String
    let vocab: PassageVocabulary?
    let isHighlighted: Bool
    let startIndex: Int
    let endIndex: Int
}

// MARK: - Highlighted Text View

/// Renders passage text with tappable highlighted vocabulary words.
///
/// Vocabulary words get a cream highlight background (#ede8d2) and a solid
/// bottom border (#c9be8a, 1.5px). Tapping a highlighted word triggers the
/// word definition sheet. Long-pressing any word triggers the sentence
/// translation sheet.
struct HighlightedTextView: View {
    let content: String
    let vocabulary: [PassageVocabulary]
    let allVocabulary: [PassageVocabulary]
    let fontSize: CGFloat
    let lineSpacingValue: CGFloat
    let readingFont: ReadingFont

    let onWordTap: (PassageVocabulary) -> Void
    let onWordLongPress: (String) -> Void
    let onPhraseSelect: (Int, Int) -> Void

    /// Tracks the first word index tapped for phrase selection.
    @State private var phraseStartWordIndex: Int?
    /// Whether we are in phrase-select mode (after first tap on non-highlighted word).
    @State private var isPhraseSelectMode: Bool = false

    var body: some View {
        let segments = buildSegments()

        WrappingHStack(segments: segments) { segment in
            if segment.isHighlighted, let vocab = segment.vocab {
                highlightedWordView(segment: segment, vocab: vocab)
            } else {
                plainWordView(segment: segment)
            }
        }
    }

    // MARK: - Highlighted Word

    private func highlightedWordView(segment: WordSegment, vocab: PassageVocabulary) -> some View {
        Text(segment.text)
            .font(bodyFont)
            .foregroundStyle(Color.lbNearBlack)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Color.lbHighlight)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.lbHighlightBorder)
                    .frame(height: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .onTapGesture {
                onWordTap(vocab)
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                onWordLongPress(vocab.word)
            }
    }

    // MARK: - Plain Word

    private func plainWordView(segment: WordSegment) -> some View {
        Text(segment.text)
            .font(bodyFont)
            .foregroundStyle(Color.lbNearBlack)
            .background(
                isPhraseSelectMode && isInPhraseRange(segment)
                    ? Color.lbBlack : Color.clear
            )
            .foregroundStyle(
                isPhraseSelectMode && isInPhraseRange(segment)
                    ? Color.white : Color.lbNearBlack
            )
            .onLongPressGesture(minimumDuration: 0.5) {
                // Extract the first actual word from the segment text.
                let cleanWord = extractWord(from: segment.text)
                if !cleanWord.isEmpty {
                    onWordLongPress(cleanWord)
                }
            }
    }

    // MARK: - Font

    private var bodyFont: Font {
        readingFont.bodyFont(size: fontSize)
    }

    // MARK: - Segment Builder

    /// Parses the passage content and vocabulary annotations into an ordered
    /// list of segments, splitting text around vocabulary word boundaries.
    private func buildSegments() -> [WordSegment] {
        var segments: [WordSegment] = []
        var currentIndex = 0
        var segmentId = 0

        // Sort vocabulary by start index.
        let sortedVocab = vocabulary.sorted { $0.startIndex < $1.startIndex }

        for vocab in sortedVocab {
            let vocabStart = vocab.startIndex
            let vocabEnd = vocab.endIndex

            // Safety: skip if indices are out of bounds.
            guard vocabStart >= currentIndex,
                  vocabEnd <= content.count,
                  vocabStart < vocabEnd else {
                continue
            }

            // Add plain text before this vocabulary word.
            if currentIndex < vocabStart {
                let start = content.index(content.startIndex, offsetBy: currentIndex)
                let end = content.index(content.startIndex, offsetBy: vocabStart)
                let plainText = String(content[start..<end])

                // Split plain text into words for long-press support.
                let words = splitIntoWords(plainText, startingAt: currentIndex, segmentId: &segmentId)
                segments.append(contentsOf: words)
            }

            // Add the highlighted vocabulary word.
            let start = content.index(content.startIndex, offsetBy: vocabStart)
            let end = content.index(content.startIndex, offsetBy: vocabEnd)
            let vocabText = String(content[start..<end])

            segments.append(WordSegment(
                id: segmentId,
                text: vocabText,
                vocab: vocab,
                isHighlighted: true,
                startIndex: vocabStart,
                endIndex: vocabEnd
            ))
            segmentId += 1
            currentIndex = vocabEnd
        }

        // Add remaining text after the last vocabulary word.
        if currentIndex < content.count {
            let start = content.index(content.startIndex, offsetBy: currentIndex)
            let plainText = String(content[start...])
            let words = splitIntoWords(plainText, startingAt: currentIndex, segmentId: &segmentId)
            segments.append(contentsOf: words)
        }

        return segments
    }

    /// Splits a plain text string into word-level segments for individual long-press support.
    /// Preserves whitespace and punctuation attached to words.
    private func splitIntoWords(_ text: String, startingAt offset: Int, segmentId: inout Int) -> [WordSegment] {
        var words: [WordSegment] = []
        var currentPos = 0

        // Split on word boundaries but keep whitespace attached to words.
        let pattern = #"(\S+\s*|\s+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            // Fallback: return the whole text as one segment.
            let segment = WordSegment(
                id: segmentId,
                text: text,
                vocab: nil,
                isHighlighted: false,
                startIndex: offset,
                endIndex: offset + text.count
            )
            segmentId += 1
            return [segment]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let range = match.range
            let word = nsText.substring(with: range)

            // Check if this word matches any vocabulary from the full set (for long-press lookup).
            let cleanWord = extractWord(from: word)
            let matchingVocab = allVocabulary.first { $0.word.lowercased() == cleanWord.lowercased() }

            words.append(WordSegment(
                id: segmentId,
                text: word,
                vocab: matchingVocab,
                isHighlighted: false,
                startIndex: offset + currentPos,
                endIndex: offset + currentPos + word.count
            ))
            segmentId += 1
            currentPos += word.count
        }

        return words
    }

    /// Extracts a clean word from text by removing punctuation and whitespace.
    private func extractWord(from text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
    }

    /// Checks if a segment falls within the current phrase selection range.
    private func isInPhraseRange(_ segment: WordSegment) -> Bool {
        guard let start = phraseStartWordIndex else { return false }
        return segment.startIndex >= start
    }
}

// MARK: - Wrapping HStack

/// A flow layout that wraps words onto new lines, similar to how text naturally
/// reflows. Uses a simple geometry-based approach to lay out word segments
/// in a left-to-right, top-to-bottom flow.
private struct WrappingHStack<Content: View>: View {
    let segments: [WordSegment]
    @ViewBuilder let content: (WordSegment) -> Content

    @State private var totalHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(segments) { segment in
                content(segment)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if segment.id == segments.last?.id {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if segment.id == segments.last?.id {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geometry.size.height
            }
            return Color.clear
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        HighlightedTextView(
            content: MockData.spanishPassageContent,
            vocabulary: MockData.sampleVocabulary,
            allVocabulary: MockData.sampleVocabulary,
            fontSize: 19,
            lineSpacingValue: 19 * 0.85,
            readingFont: .serif,
            onWordTap: { _ in },
            onWordLongPress: { _ in },
            onPhraseSelect: { _, _ in }
        )
        .padding(.horizontal, 36)
        .padding(.vertical, 20)
    }
    .background(Color.lbLinen)
}
