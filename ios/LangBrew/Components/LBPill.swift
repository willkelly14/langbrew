import SwiftUI

// MARK: - Pill Variant

enum LBPillVariant: Sendable {
    /// Dark background, white text.
    case filled
    /// Border with transparent background.
    case outlined
    /// Cream/highlight background.
    case highlight
}

// MARK: - Pill Component

/// A pill-shaped tag used for CEFR badges, filter pills, and topic tags.
struct LBPill: View {
    let text: String
    let variant: LBPillVariant
    let icon: String?

    init(_ text: String, variant: LBPillVariant = .filled, icon: String? = nil) {
        self.text = text
        self.variant = variant
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: LBTheme.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(LBTheme.Typography.caption)
        }
        .padding(.horizontal, LBTheme.Spacing.md)
        .padding(.vertical, LBTheme.Spacing.sm)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            if variant == .outlined {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.lbG200, lineWidth: 1)
            }
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .filled: .lbBlack
        case .outlined: .clear
        case .highlight: .lbHighlight
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .filled: .lbWhite
        case .outlined: .lbBlack
        case .highlight: .lbNearBlack
        }
    }
}

#Preview {
    HStack(spacing: LBTheme.Spacing.sm) {
        LBPill("A2", variant: .filled)
        LBPill("Travel", variant: .outlined)
        LBPill("New", variant: .highlight, icon: "sparkles")
    }
    .padding()
    .background(Color.lbLinen)
}
