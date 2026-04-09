import SwiftUI

// MARK: - Passage Card View

/// A card displaying a passage summary in the Library grid.
/// Shows CEFR tag + status dot, title, "X new words" meta,
/// progress bar + percentage (or "Not started" / time label).
struct PassageCardView: View {
    let passage: PassageResponse

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            // Top row: CEFR tag + status dot
            HStack(spacing: LBTheme.Spacing.xs) {
                // CEFR tag
                Text(passage.cefrLevel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.lbG500)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lbG100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                // Status dot
                if passage.isInProgress {
                    Circle()
                        .fill(Color.lbNearBlack)
                        .frame(width: 6, height: 6)
                }
            }

            // Title
            Text(passage.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.lbBlack)
                .lineSpacing(14 * 0.35)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Meta
            Text(passage.newWordCountLabel)
                .font(.system(size: 11))
                .foregroundStyle(Color.lbG400)

            Spacer(minLength: 0)

            // Bottom: progress bar + percentage, or time / status
            if passage.isInProgress {
                HStack(spacing: LBTheme.Spacing.sm) {
                    // Progress bar (3px height, g200 track, near-black fill)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.lbG200)
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.lbNearBlack)
                                .frame(
                                    width: geometry.size.width * passage.readingProgress,
                                    height: 3
                                )
                        }
                    }
                    .frame(height: 3)

                    // Percentage
                    Text("\(Int(passage.readingProgress * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.lbG500)
                }
            } else if passage.readingProgress >= 1.0 {
                HStack(spacing: LBTheme.Spacing.sm) {
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.lbNearBlack)
                            .frame(width: geometry.size.width, height: 3)
                    }
                    .frame(height: 3)

                    Text("Done")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.lbG500)
                }
            } else {
                // Not started
                Text(passage.readingTimeLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.lbG400)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        .lbShadow(LBTheme.Shadow.card)
    }
}

#Preview {
    let columns = [
        GridItem(.flexible(), spacing: LBTheme.Spacing.md),
        GridItem(.flexible(), spacing: LBTheme.Spacing.md),
    ]

    ScrollView {
        LazyVGrid(columns: columns, spacing: LBTheme.Spacing.md) {
            ForEach(MockPassageData.passages) { passage in
                PassageCardView(passage: passage)
            }
        }
        .padding(LBTheme.Spacing.lg)
    }
    .background(Color.lbLinen)
}
