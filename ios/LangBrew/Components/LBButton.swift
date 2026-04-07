import SwiftUI

// MARK: - Button Style Variant

enum LBButtonVariant: Sendable {
    /// Dark background, white text.
    case primary
    /// Border with transparent background.
    case secondary
    /// Text-only, no background or border.
    case text
}

// MARK: - Button Component

/// Standard button with primary, secondary, and text-only variants.
/// Supports full-width layout and a loading state.
struct LBButton: View {
    let title: String
    let variant: LBButtonVariant
    let icon: String?
    let fullWidth: Bool
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        variant: LBButtonVariant = .primary,
        icon: String? = nil,
        fullWidth: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.icon = icon
        self.fullWidth = fullWidth
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: LBTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .medium))
                    }
                    Text(title)
                        .font(LBTheme.Typography.bodyMedium)
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, LBTheme.Spacing.xl)
            .padding(.vertical, LBTheme.Spacing.md)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                if variant == .secondary {
                    RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                        .strokeBorder(Color.lbG200, lineWidth: 1.5)
                }
            }
        }
        .disabled(isLoading)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: .lbBlack
        case .secondary: .clear
        case .text: .clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: .lbWhite
        case .secondary: .lbBlack
        case .text: .lbBlack
        }
    }
}

#Preview {
    VStack(spacing: LBTheme.Spacing.lg) {
        LBButton("Get Started", variant: .primary, fullWidth: true) {}
        LBButton("Settings", variant: .secondary, icon: "gearshape") {}
        LBButton("Skip", variant: .text) {}
        LBButton("Loading...", variant: .primary, fullWidth: true, isLoading: true) {}
    }
    .padding()
    .background(Color.lbLinen)
}
