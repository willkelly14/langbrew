import SwiftUI

/// A showcase view that renders every LangBrew design system component
/// with mock data for visual verification. Set as the initial view in
/// ContentView during Milestone 0.2 development.
struct ComponentShowcase: View {
    @State private var selectedTab: LBTab = .home
    @State private var showSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.xxl) {
                    headerSection
                    colorsSection
                    typographySection
                    buttonsSection
                    pillsSection
                    cardsSection
                    progressSection
                    streakSection
                    statsSection
                    avatarSection
                    emptyStateSection
                    loadingSection
                    errorSection
                    flagsSection
                    sheetSection
                }
                .padding(.horizontal, LBTheme.Spacing.lg)
                .padding(.top, LBTheme.Spacing.lg)
                .padding(.bottom, 120) // Room for tab bar
            }
            .background(Color.lbLinen)

            LBTabBar(selectedTab: $selectedTab)
        }
        .lbSheet(isPresented: $showSheet) {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
                Text("Bottom Sheet")
                    .font(LBTheme.Typography.title2)
                Text("This is a LangBrew bottom sheet with a drag indicator, styled content area, and customizable presentation.")
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG500)
                LBButton("Confirm", variant: .primary, fullWidth: true) {
                    showSheet = false
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            Text("LangBrew")
                .font(LBTheme.Typography.largeTitle)
                .foregroundStyle(Color.lbBlack)
            Text("Design System & Component Library")
                .font(LBTheme.Typography.body)
                .foregroundStyle(Color.lbG500)
        }
    }

    private var colorsSection: some View {
        ShowcaseSection(title: "Colors") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: LBTheme.Spacing.sm) {
                ColorSwatch(color: .lbBlack, name: "black")
                ColorSwatch(color: .lbNearBlack, name: "nearBlk")
                ColorSwatch(color: .lbG500, name: "g500")
                ColorSwatch(color: .lbG400, name: "g400")
                ColorSwatch(color: .lbG300, name: "g300")
                ColorSwatch(color: .lbG200, name: "g200")
                ColorSwatch(color: .lbG100, name: "g100")
                ColorSwatch(color: .lbG50, name: "g50")
                ColorSwatch(color: .lbLinen, name: "linen")
                ColorSwatch(color: .lbHighlight, name: "highlight")
                ColorSwatch(color: .lbWhite, name: "white")
            }
        }
    }

    private var typographySection: some View {
        ShowcaseSection(title: "Typography") {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
                Text("Large Title (36pt serif)")
                    .font(LBTheme.Typography.largeTitle)
                Text("Title (30pt serif)")
                    .font(LBTheme.Typography.title)
                Text("Title 2 (22pt serif)")
                    .font(LBTheme.Typography.title2)
                Text("Headline (17pt serif)")
                    .font(LBTheme.Typography.headline)
                Text("Body (15pt sans)")
                    .font(LBTheme.Typography.body)
                Text("Body Medium (15pt sans 500)")
                    .font(LBTheme.Typography.bodyMedium)
                Text("Caption (13pt sans)")
                    .font(LBTheme.Typography.caption)
                Text("SMALL (11PT SANS 600)")
                    .lbSmallStyle()
            }
            .foregroundStyle(Color.lbBlack)
        }
    }

    private var buttonsSection: some View {
        ShowcaseSection(title: "Buttons") {
            VStack(spacing: LBTheme.Spacing.md) {
                LBButton("Get Started", variant: .primary, fullWidth: true) {}
                LBButton("Settings", variant: .secondary, icon: "gearshape") {}
                LBButton("Skip for now", variant: .text) {}
                LBButton("Loading", variant: .primary, fullWidth: true, isLoading: true) {}
            }
        }
    }

    private var pillsSection: some View {
        ShowcaseSection(title: "Pills & Tags") {
            FlowLayout(spacing: LBTheme.Spacing.sm) {
                LBPill("A1", variant: .filled)
                LBPill("A2", variant: .filled)
                LBPill("B1", variant: .filled)
                LBPill("Travel", variant: .outlined)
                LBPill("Daily Life", variant: .outlined)
                LBPill("Food", variant: .outlined)
                LBPill("AI Generated", variant: .highlight, icon: "sparkles")
                LBPill("New", variant: .highlight)
            }
        }
    }

    private var cardsSection: some View {
        ShowcaseSection(title: "Cards") {
            VStack(spacing: LBTheme.Spacing.md) {
                LBCard {
                    VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
                        HStack {
                            LBPill("A2", variant: .filled)
                            LBPill("AI Generated", variant: .highlight, icon: "sparkles")
                        }
                        Text("The Morning Market")
                            .font(LBTheme.Typography.title2)
                        Text("Spanish \u{00B7} 96% known \u{00B7} ~4 min")
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(Color.lbG500)
                        Text("El mercado de la ma\u{00F1}ana estaba lleno de colores y aromas...")
                            .font(LBTheme.Typography.body)
                            .foregroundStyle(Color.lbG500)
                            .lineLimit(2)
                    }
                }

                LBCard(style: .dark) {
                    VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
                        Text("Today's Passage")
                            .font(LBTheme.Typography.caption)
                            .opacity(0.7)
                        Text("A Day in the Park")
                            .font(LBTheme.Typography.title2)
                        Text("French \u{00B7} A2 \u{00B7} 12 new words")
                            .font(LBTheme.Typography.caption)
                            .opacity(0.7)
                    }
                }
            }
        }
    }

    private var progressSection: some View {
        ShowcaseSection(title: "Progress Bars") {
            VStack(spacing: LBTheme.Spacing.md) {
                LBProgressBar(progress: 0.34, label: "34%")
                LBProgressBar(progress: 0.72, foregroundColor: .lbNearBlack, height: 12, label: "72%")
                LBProgressBar(progress: 1.0, foregroundColor: .lbG500, label: "Complete")
            }
        }
    }

    private var streakSection: some View {
        ShowcaseSection(title: "Streak Dots") {
            VStack(spacing: LBTheme.Spacing.lg) {
                HStack(spacing: LBTheme.Spacing.sm) {
                    Text("\u{1F525}")
                        .font(.system(size: 20))
                    Text("12 day streak")
                        .font(LBTheme.Typography.bodyMedium)
                }

                LBStreakDots(days: [true, true, true, true, false, false, false])
            }
        }
    }

    private var statsSection: some View {
        ShowcaseSection(title: "Stat Cards") {
            HStack(spacing: LBTheme.Spacing.md) {
                LBStatCard(value: 247, label: "Words", icon: "textformat.abc")
                LBStatCard(value: 38, label: "Learning", icon: "brain")
                LBStatCard(value: 53, label: "Mastered", icon: "checkmark.seal")
            }
        }
    }

    private var avatarSection: some View {
        ShowcaseSection(title: "Avatars") {
            HStack(spacing: LBTheme.Spacing.lg) {
                LBAvatarCircle(name: "Will Kelly", size: 56, showBorder: true)
                LBAvatarCircle(name: "Maria Santos", size: 44)
                LBAvatarCircle(name: "Mia", size: 36, showBorder: true)
                LBAvatarCircle(name: "C", size: 32)
            }
        }
    }

    private var emptyStateSection: some View {
        ShowcaseSection(title: "Empty State") {
            LBCard(padding: 0) {
                LBEmptyState(
                    icon: "book.closed",
                    title: "No books yet",
                    subtitle: "Import a book or generate your first passage to get started.",
                    buttonTitle: "Import a Book"
                ) {}
            }
        }
    }

    private var loadingSection: some View {
        ShowcaseSection(title: "Loading Skeletons") {
            VStack(spacing: LBTheme.Spacing.md) {
                LBLoadingSkeleton(height: 24)
                LBLoadingSkeleton(width: 200, height: 16)
                LBCardSkeleton()
            }
        }
    }

    private var errorSection: some View {
        ShowcaseSection(title: "Error State") {
            LBCard(padding: 0) {
                LBErrorState(message: "Unable to load passages. Check your connection and try again.") {}
            }
        }
    }

    private var flagsSection: some View {
        ShowcaseSection(title: "Language Flags") {
            FlowLayout(spacing: LBTheme.Spacing.sm) {
                ForEach(FlagMapper.supportedLanguages, id: \.self) { code in
                    HStack(spacing: LBTheme.Spacing.xs) {
                        Text(FlagMapper.flag(for: code))
                            .font(.system(size: 20))
                        Text(FlagMapper.languageName(for: code))
                            .font(LBTheme.Typography.caption)
                    }
                    .padding(.horizontal, LBTheme.Spacing.md)
                    .padding(.vertical, LBTheme.Spacing.sm)
                    .background(Color.lbWhite)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var sheetSection: some View {
        ShowcaseSection(title: "Bottom Sheet") {
            LBButton("Open Bottom Sheet", variant: .secondary, fullWidth: true) {
                showSheet = true
            }
        }
    }
}

// MARK: - Showcase Section

private struct ShowcaseSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text(title)
                .lbSmallStyle()
                .foregroundStyle(Color.lbG400)

            content()
        }
    }
}

// MARK: - Color Swatch

private struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack(spacing: LBTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: LBTheme.Radius.medium)
                .fill(color)
                .frame(height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: LBTheme.Radius.medium)
                        .strokeBorder(Color.lbG200, lineWidth: 0.5)
                }

            Text(name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.lbG500)
        }
    }
}

// MARK: - Flow Layout

/// A simple wrapping horizontal layout for pills and tags.
struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private struct ArrangementResult {
        let size: CGSize
        let positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return ArrangementResult(
            size: CGSize(width: maxX, height: currentY + lineHeight),
            positions: positions
        )
    }
}

#Preview {
    ComponentShowcase()
}
