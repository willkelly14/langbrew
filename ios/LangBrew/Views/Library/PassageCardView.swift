import SwiftUI

// MARK: - Passage Card View

/// A card displaying a passage summary in the Library grid.
/// Shows CEFR level badge, AI badge, title, metadata, excerpt, and progress.
struct PassageCardView: View {
    let passage: PassageResponse

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            // Badges
            HStack(spacing: LBTheme.Spacing.xs) {
                // CEFR level badge
                Text(passage.cefrLevel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.lbNearBlack)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lbG100)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                // AI badge
                if passage.isGenerated {
                    Text("AI")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.lbNearBlack)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.lbHighlight)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                Spacer()
            }

            // Title
            Text(passage.title)
                .font(LBTheme.Typography.headline)
                .foregroundStyle(Color.lbBlack)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Metadata: word count + time
            Text("\(passage.wordCountLabel) \u{00B7} \(passage.readingTimeLabel)")
                .font(LBTheme.Typography.caption)
                .foregroundStyle(Color.lbG400)

            // Excerpt
            Text(passage.excerpt)
                .font(LBTheme.Typography.caption)
                .foregroundStyle(Color.lbG500)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            // Progress bar
            if passage.readingProgress > 0 {
                LBProgressBar(
                    progress: passage.readingProgress,
                    height: 4,
                    label: progressLabel
                )
            } else {
                LBProgressBar(
                    progress: 0,
                    trackColor: .lbG100,
                    height: 4
                )
            }
        }
        .padding(LBTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        .lbShadow(LBTheme.Shadow.card)
    }

    private var progressLabel: String? {
        if passage.readingProgress >= 1.0 {
            return "Done"
        } else if passage.readingProgress > 0 {
            return "\(Int(passage.readingProgress * 100))%"
        }
        return nil
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
