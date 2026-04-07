import SwiftUI

/// A centered empty state view with icon, title, subtitle, and optional CTA button.
struct LBEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: LBTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.lbG300)

            VStack(spacing: LBTheme.Spacing.sm) {
                Text(title)
                    .font(LBTheme.Typography.title2)
                    .foregroundStyle(Color.lbBlack)

                Text(subtitle)
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG500)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let action {
                LBButton(buttonTitle, variant: .primary, action: action)
            }
        }
        .padding(LBTheme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    LBEmptyState(
        icon: "book.closed",
        title: "No books yet",
        subtitle: "Import a book or generate your first passage to get started.",
        buttonTitle: "Import a Book"
    ) {}
    .background(Color.lbLinen)
}
