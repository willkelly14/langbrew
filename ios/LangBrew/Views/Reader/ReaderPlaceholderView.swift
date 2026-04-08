import SwiftUI

// MARK: - Reader Placeholder View

/// Temporary placeholder for the Reader screen.
/// Will be replaced with the full reader implementation in Milestone 3.2.
struct ReaderPlaceholderView: View {
    let passageId: String

    /// Looks up the passage from mock data, if available.
    private var passage: PassageResponse? {
        MockPassageData.passages.first { $0.id == passageId }
    }

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: LBTheme.Spacing.xl) {
                Spacer()

                if let passage {
                    // Show basic passage info
                    VStack(spacing: LBTheme.Spacing.md) {
                        LBPill(passage.cefrLevel, variant: .filled)

                        Text(passage.title)
                            .font(LBTheme.Typography.title)
                            .foregroundStyle(Color.lbBlack)
                            .multilineTextAlignment(.center)

                        Text("\(passage.wordCountLabel) \u{00B7} \(passage.readingTimeLabel)")
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(Color.lbG500)
                    }

                    LBEmptyState(
                        icon: "book.pages",
                        title: "Reader coming soon",
                        subtitle: "The full reading experience with vocabulary highlights and word definitions is being built."
                    )
                } else {
                    LBEmptyState(
                        icon: "book.pages",
                        title: "Reader coming soon",
                        subtitle: "The passage reader will be available in the next update."
                    )
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(passage?.title ?? "Reader")
                    .font(LBTheme.Typography.bodyMedium)
                    .foregroundStyle(Color.lbBlack)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReaderPlaceholderView(passageId: "mock-001")
    }
}
