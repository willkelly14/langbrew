import SwiftUI

// MARK: - Word Segment

private struct WordSegment: Identifiable {
    let id: Int
    let text: String
    let vocab: PassageVocabulary?
    let isHighlighted: Bool
    let startIndex: Int
    let endIndex: Int
}

// MARK: - Word Frame Preference Key

private struct WordFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Highlighted Text View

/// Renders passage text with tappable highlighted vocabulary words.
///
/// Vocabulary words get a cream highlight background (#ede8d2) and a solid
/// bottom border (#c9be8a, 1.5px). Tapping a highlighted word triggers the
/// word definition sheet. Tapping a non-highlighted word looks up its definition.
/// Long-pressing any word triggers the sentence translation sheet.
/// Dragging across words triggers phrase selection.
struct HighlightedTextView: View {
    let content: String
    let vocabulary: [PassageVocabulary]
    let allVocabulary: [PassageVocabulary]
    let fontSize: CGFloat
    let lineSpacingValue: CGFloat
    let readingFont: ReadingFont

    let selectedWord: String?
    let selectedSentenceRange: (start: Int, end: Int)?

    let onWordTap: (PassageVocabulary) -> Void
    let onNonHighlightedWordTap: (String) -> Void
    let onWordLongPress: (String, Int) -> Void
    let onPhraseSelect: (Int, Int) -> Void

    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var dragStartSegmentId: Int?
    @State private var dragEndSegmentId: Int?
    @State private var isDragging: Bool = false

    var body: some View {
        let segments = buildSegments()

        WrappingHStack(segments: segments, lineSpacing: lineSpacingValue) { segment in
            wordView(for: segment)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: WordFramePreferenceKey.self,
                            value: [segment.id: geo.frame(in: .named("highlightedText"))]
                        )
                    }
                )
        }
        .coordinateSpace(name: "highlightedText")
        .onPreferenceChange(WordFramePreferenceKey.self) { frames in
            wordFrames = frames
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 25, coordinateSpace: .named("highlightedText"))
                .onChanged { value in
                    if !isDragging {
                        // Only activate for horizontal-ish drags to avoid interfering with scroll
                        let dx = abs(value.translation.width)
                        let dy = abs(value.translation.height)
                        guard dx > dy * 0.7 else { return }
                        isDragging = true
                        dragStartSegmentId = findSegmentId(at: value.startLocation)
                    }
                    dragEndSegmentId = findSegmentId(at: value.location)
                }
                .onEnded { _ in
                    if isDragging,
                       let startId = dragStartSegmentId,
                       let endId = dragEndSegmentId,
                       startId != endId {
                        let allSegs = buildSegments()
                        let startSeg = allSegs.first { $0.id == min(startId, endId) }
                        let endSeg = allSegs.first { $0.id == max(startId, endId) }
                        if let s = startSeg, let e = endSeg {
                            onPhraseSelect(s.startIndex, e.endIndex)
                        }
                    }
                    isDragging = false
                    dragStartSegmentId = nil
                    dragEndSegmentId = nil
                }
        )
    }

    // MARK: - Word Views

    @ViewBuilder
    private func wordView(for segment: WordSegment) -> some View {
        if segment.isHighlighted, let vocab = segment.vocab {
            highlightedWordView(segment: segment, vocab: vocab)
        } else {
            plainWordView(segment: segment)
        }
    }

    // MARK: - Highlighted Word

    private func highlightedWordView(segment: WordSegment, vocab: PassageVocabulary) -> some View {
        let isActive = isSegmentActive(segment)
        let inDrag = isDragging && isSegmentInDragRange(segment)
        let inverted = isActive || inDrag

        return Text(segment.text)
            .font(bodyFont)
            .foregroundStyle(inverted ? Color.white : Color.lbNearBlack)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(inverted ? Color.lbBlack : Color.lbHighlight)
            .overlay(alignment: .bottom) {
                if !inverted {
                    Rectangle()
                        .fill(Color.lbHighlightBorder)
                        .frame(height: 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: inverted ? 3 : 2))
            .onLongPressGesture(minimumDuration: 0.5) {
                onWordLongPress(vocab.word, segment.startIndex)
            }
            .onTapGesture {
                onWordTap(vocab)
            }
    }

    // MARK: - Plain Word

    private func plainWordView(segment: WordSegment) -> some View {
        let isActive = isSegmentActive(segment)
        let inDrag = isDragging && isSegmentInDragRange(segment)
        let inverted = isActive || inDrag

        return Text(segment.text)
            .font(bodyFont)
            .foregroundStyle(inverted ? Color.white : Color.lbNearBlack)
            .background(inverted ? Color.lbBlack : Color.clear)
            .onLongPressGesture(minimumDuration: 0.5) {
                let cleanWord = extractWord(from: segment.text)
                if !cleanWord.isEmpty {
                    onWordLongPress(cleanWord, segment.startIndex)
                }
            }
            .onTapGesture {
                let cleanWord = extractWord(from: segment.text)
                if !cleanWord.isEmpty {
                    onNonHighlightedWordTap(cleanWord)
                }
            }
    }

    // MARK: - Font

    private var bodyFont: Font {
        readingFont.bodyFont(size: fontSize)
    }

    // MARK: - Drag Helpers

    private func findSegmentId(at point: CGPoint) -> Int? {
        // First check for direct hit
        for (id, frame) in wordFrames {
            if frame.contains(point) {
                return id
            }
        }
        // Fallback: find closest segment within 50pt
        var closestId: Int?
        var closestDist: CGFloat = .infinity
        for (id, frame) in wordFrames {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let dist = hypot(point.x - center.x, point.y - center.y)
            if dist < closestDist && dist < 50 {
                closestDist = dist
                closestId = id
            }
        }
        return closestId
    }

    /// Checks if a segment should show the active highlight (tapped word or sentence range).
    private func isSegmentActive(_ segment: WordSegment) -> Bool {
        // Check if segment starts within the sentence range (long press)
        if let range = selectedSentenceRange {
            return segment.startIndex >= range.start && segment.startIndex < range.end
        }
        // Check if the segment matches the selected word (tap)
        if let word = selectedWord {
            let cleanWord = extractWord(from: segment.text)
            return !cleanWord.isEmpty && cleanWord.lowercased() == word.lowercased()
        }
        return false
    }

    private func isSegmentInDragRange(_ segment: WordSegment) -> Bool {
        guard let startId = dragStartSegmentId,
              let endId = dragEndSegmentId else { return false }
        let minId = min(startId, endId)
        let maxId = max(startId, endId)
        return segment.id >= minId && segment.id <= maxId
    }

    // MARK: - Segment Builder

    /// Parses the passage content and vocabulary annotations into an ordered
    /// list of segments, splitting text around vocabulary word boundaries.
    private func buildSegments() -> [WordSegment] {
        var segments: [WordSegment] = []
        var currentIndex = 0
        var segmentId = 0

        let sortedVocab = vocabulary.sorted { $0.startIndex < $1.startIndex }

        for vocab in sortedVocab {
            let vocabStart = vocab.startIndex
            let vocabEnd = vocab.endIndex

            guard vocabStart >= currentIndex,
                  vocabEnd <= content.count,
                  vocabStart < vocabEnd else {
                continue
            }

            if currentIndex < vocabStart {
                let start = content.index(content.startIndex, offsetBy: currentIndex)
                let end = content.index(content.startIndex, offsetBy: vocabStart)
                let plainText = String(content[start..<end])
                let words = splitIntoWords(plainText, startingAt: currentIndex, segmentId: &segmentId)
                segments.append(contentsOf: words)
            }

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

        if currentIndex < content.count {
            let start = content.index(content.startIndex, offsetBy: currentIndex)
            let plainText = String(content[start...])
            let words = splitIntoWords(plainText, startingAt: currentIndex, segmentId: &segmentId)
            segments.append(contentsOf: words)
        }

        return segments
    }

    private func splitIntoWords(_ text: String, startingAt offset: Int, segmentId: inout Int) -> [WordSegment] {
        var words: [WordSegment] = []
        var currentPos = 0

        let pattern = #"(\S+\s*|\s+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
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

    private func extractWord(from text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
    }
}

// MARK: - Wrapping HStack

/// A flow layout that wraps words onto new lines, similar to how text naturally
/// reflows. Uses a simple geometry-based approach to lay out word segments
/// in a left-to-right, top-to-bottom flow.
private struct WrappingHStack<Content: View>: View {
    let segments: [WordSegment]
    let lineSpacing: CGFloat
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
                            height -= dimension.height + lineSpacing
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
            selectedWord: nil,
            selectedSentenceRange: nil,
            onWordTap: { _ in },
            onNonHighlightedWordTap: { _ in },
            onWordLongPress: { _, _ in },
            onPhraseSelect: { _, _ in }
        )
        .padding(.horizontal, 36)
        .padding(.vertical, 20)
    }
    .background(Color.lbLinen)
}
