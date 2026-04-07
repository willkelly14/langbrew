import SwiftUI

// MARK: - Card Style

enum LBCardStyle: Sendable {
    /// White background with dark text (default).
    case light
    /// Dark background with white text.
    case dark
}

// MARK: - Card Component

/// A rounded card container with configurable padding and style.
/// Used throughout the app for content grouping.
struct LBCard<Content: View>: View {
    let style: LBCardStyle
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        style: LBCardStyle = .light,
        padding: CGFloat = LBTheme.Spacing.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .lbShadow(LBTheme.Shadow.card)
    }

    private var backgroundColor: Color {
        switch style {
        case .light: .lbWhite
        case .dark: .lbBlack
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .light: .lbBlack
        case .dark: .lbWhite
        }
    }
}

#Preview("Light Card") {
    LBCard {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            Text("Card Title")
                .font(LBTheme.Typography.title2)
            Text("This is a light card with some sample content.")
                .font(LBTheme.Typography.body)
        }
    }
    .padding()
    .background(Color.lbLinen)
}

#Preview("Dark Card") {
    LBCard(style: .dark) {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            Text("Dark Card")
                .font(LBTheme.Typography.title2)
            Text("This is a dark card with inverted colors.")
                .font(LBTheme.Typography.body)
        }
    }
    .padding()
    .background(Color.lbLinen)
}
