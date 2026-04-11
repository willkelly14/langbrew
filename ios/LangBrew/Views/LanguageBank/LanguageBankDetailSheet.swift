import SwiftUI

// MARK: - Language Bank Detail Sheet

/// Screen 6b: Item detail bottom sheet showing word info, stats, status controls,
/// and a remove button. Presented as a custom overlay with LBBottomSheet styling.
struct LanguageBankDetailSheet: View {
    @Bindable var viewModel: LanguageBankViewModel
    let onDismiss: () -> Void

    var body: some View {
        if let item = viewModel.selectedItem {
            LBBottomSheet(onDismiss: onDismiss) {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Word header: large serif word + phonetic
                    DetailWordHeader(item: item)

                    // 2. POS row + speaker button
                    DetailPOSRow(item: item)
                        .padding(.top, 6)

                    // 3. Divider
                    DetailDivider()
                        .padding(.top, 14)

                    // 4. Definition
                    if let definition = item.definition {
                        Text(definition)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbBlack)
                            .lineSpacing(4)
                            .padding(.top, 14)
                    }

                    // 5. Example sentence
                    if let example = item.exampleSentence {
                        DetailExampleSentence(
                            example: example,
                            highlightWord: item.text
                        )
                        .padding(.top, 10)
                    }

                    // 6. Divider before stats
                    DetailDivider()
                        .padding(.top, 14)

                    // 7. Stats section label + cards
                    DetailSectionLabel(text: "STATS")
                        .padding(.top, 14)

                    DetailStatsRow(item: item)
                        .padding(.top, 10)

                    // 8. Status section label + pills
                    DetailSectionLabel(text: "STATUS")
                        .padding(.top, 18)

                    DetailStatusPills(
                        currentStatus: item.status,
                        onSelect: { newStatus in
                            viewModel.updateStatus(newStatus)
                        }
                    )
                    .padding(.top, 10)

                    // 9. Remove button
                    Button {
                        viewModel.removeSelectedItem()
                    } label: {
                        Text("Remove")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.lbWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color(hex: "c45c5c"))
                            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

// MARK: - Word Header

/// Word in large serif + phonetic in gray italic.
private struct DetailWordHeader: View {
    let item: LanguageBankItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.text)
                .font(LBTheme.Typography.title)
                .foregroundStyle(Color.lbBlack)

            if let phonetic = item.phonetic {
                Text(phonetic)
                    .font(.system(size: 14).italic())
                    .foregroundStyle(Color.lbG400)
            }
        }
    }
}

// MARK: - POS Row

/// Part of speech badge + speaker button.
/// Matches mockup: POS 13px, speaker 28x28 circle.
private struct DetailPOSRow: View {
    let item: LanguageBankItem

    var body: some View {
        HStack {
            if let pos = item.posLabel {
                Text(pos)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)
            }

            Spacer()

            // Speaker button (28x28 circle)
            Button {} label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lbBlack)
                    .frame(width: 28, height: 28)
                    .background(Color.lbG50)
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Example Sentence

/// Example sentence with the target word highlighted in bold.
/// Matches mockup: 13px italic, lbG500, highlighted word in bold.
private struct DetailExampleSentence: View {
    let example: String
    let highlightWord: String

    var body: some View {
        highlightedText
            .font(.system(size: 13).italic())
            .foregroundStyle(Color.lbG500)
    }

    /// Builds an attributed text with the highlight word in bold.
    private var highlightedText: Text {
        let lowered = example.lowercased()
        let target = highlightWord.lowercased()

        guard let range = lowered.range(of: target) else {
            return Text("\"\(example)\"")
        }

        let before = String(example[example.startIndex..<range.lowerBound])
        let match = String(example[range])
        let after = String(example[range.upperBound..<example.endIndex])

        return Text("\"\(before)")
            + Text(match).bold()
            + Text("\(after)\"")
    }
}

// MARK: - Section Label

/// Uppercase section label (e.g., "STATS", "STATUS").
/// Matches mockup: 10px 700 weight, letter-spacing 0.8px, uppercase, lbG500.
private struct DetailSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.lbG500)
            .kerning(0.8)
    }
}

// MARK: - Stats Row

/// Three stat cards: Times Reviewed, Accuracy, Passages.
/// Matches mockup: gap 8px, bg lbG50, borderRadius 12, padding 12px, center aligned.
/// Number: 20px 600 weight. Label: 11px lbG400.
private struct DetailStatsRow: View {
    let item: LanguageBankItem

    var body: some View {
        HStack(spacing: 8) {
            DetailStatCard(value: "\(item.timesReviewed)x", label: "Reviewed")
            DetailStatCard(value: "\(item.accuracy)%", label: "Accuracy")
            DetailStatCard(value: "\(item.passageCount)", label: "Passages")
        }
    }
}

/// A single stat card in the detail sheet.
private struct DetailStatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.lbNearBlack)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.lbG400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
    }
}

// MARK: - Status Pills

/// Three status buttons: New, Known, Mastered.
/// Matches mockup: gap 8px, flex 1, padding 10px, borderRadius 10, border 1.5px lbG200.
/// Active: colored border, near-black text, 600 weight.
/// Inactive: lbG200 border, lbG500 text, 500 weight.
private struct DetailStatusPills: View {
    let currentStatus: VocabStatus
    let onSelect: (VocabStatus) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(VocabStatus.allCases) { status in
                Button {
                    onSelect(status)
                } label: {
                    Text(status.displayName)
                        .font(.system(
                            size: 13,
                            weight: currentStatus == status ? .semibold : .medium
                        ))
                        .foregroundStyle(
                            currentStatus == status ? Color.lbNearBlack : Color.lbG500
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.lbWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    currentStatus == status
                                        ? status.activeBorderColor
                                        : Color.lbG200,
                                    lineWidth: 1.5
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Divider

/// Thin horizontal divider matching mockup: 0.5px lbG100.
private struct DetailDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.lbG100)
            .frame(height: 0.5)
    }
}

#Preview {
    ZStack {
        Color.lbLinen.ignoresSafeArea()

        VStack {
            Spacer()
            LanguageBankDetailSheet(
                viewModel: {
                    let vm = LanguageBankViewModel.preview()
                    vm.selectedItem = vm.allItems.first
                    return vm
                }(),
                onDismiss: {}
            )
        }
    }
}
