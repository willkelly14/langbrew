import SwiftUI

// MARK: - Onboarding Nav Bar

/// Reusable top navigation bar for onboarding screens.
/// Displays a back chevron on the left and optional right text ("Skip" or "Later").
struct OnboardingNav: View {
    let showBack: Bool
    let rightLabel: String?
    let onBack: (() -> Void)?
    let onRight: (() -> Void)?

    init(
        showBack: Bool = true,
        rightLabel: String? = nil,
        onBack: (() -> Void)? = nil,
        onRight: (() -> Void)? = nil
    ) {
        self.showBack = showBack
        self.rightLabel = rightLabel
        self.onBack = onBack
        self.onRight = onRight
    }

    var body: some View {
        HStack {
            if showBack {
                Button {
                    onBack?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.lbBlack)
                }
            }

            Spacer()

            if let rightLabel {
                Button {
                    onRight?()
                } label: {
                    Text(rightLabel)
                        .font(LBTheme.Typography.bodyMedium)
                        .foregroundStyle(Color.lbG400)
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, LBTheme.Spacing.xl)
    }
}

// MARK: - Onboarding Progress Bar

/// Full-width progress bar for onboarding steps.
/// Thin (~3px) bar with g100 track and black fill.
struct OnboardingProgress: View {
    /// Progress value from 0.0 to 1.0.
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.lbG100)

                Rectangle()
                    .fill(Color.lbBlack)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 3)
        .padding(.horizontal, LBTheme.Spacing.xl)
    }
}

// MARK: - Selection Circle

/// Radio button style indicator.
/// Empty: g200 border circle. Checked: black filled circle with white checkmark.
struct SelectionCircle: View {
    let isSelected: Bool
    var size: CGFloat = 22

    var body: some View {
        if isSelected {
            Circle()
                .fill(Color.lbBlack)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(Color.lbWhite)
                }
        } else {
            Circle()
                .strokeBorder(Color.lbG200, lineWidth: 1.5)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Onboarding CTA Button

/// Full-width call-to-action button for onboarding screens.
/// Black bg, white text, 12px radius, ~50px height, bodyMedium font.
struct OnboardingCTA: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.lbWhite)
                } else {
                    Text(title)
                        .font(LBTheme.Typography.bodyMedium)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.lbBlack)
            .foregroundStyle(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Onboarding Text Field

/// Standard text field for onboarding auth forms.
/// White bg, g200 border, 12px radius.
struct OnboardingInput: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                .fill(Color.lbWhite)
            RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                .strokeBorder(isFocused ? Color.lbG400 : Color.lbG200, lineWidth: 1.5)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(textContentType)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(LBTheme.Typography.body)
            .foregroundStyle(Color.lbNearBlack)
            .focused($isFocused)
            .padding(.horizontal, LBTheme.Spacing.lg)
        }
        .frame(height: 50)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}

// MARK: - Auth Divider

/// Horizontal divider with "or" text, used in auth screens.
struct AuthDivider: View {
    var body: some View {
        HStack(spacing: LBTheme.Spacing.lg) {
            Rectangle()
                .fill(Color.lbG200)
                .frame(height: 0.5)
            Text("or")
                .font(LBTheme.Typography.caption)
                .foregroundStyle(Color.lbG400)
            Rectangle()
                .fill(Color.lbG200)
                .frame(height: 0.5)
        }
        .padding(.vertical, LBTheme.Spacing.lg)
    }
}

// MARK: - Auth Provider Button

/// Social login button (Apple or Google style).
struct AuthButton: View {
    enum Style {
        case apple
        case google
    }

    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                authIcon
                Text(style == .apple ? "Continue with Apple" : "Continue with Google")
                    .font(LBTheme.Typography.body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(style == .apple ? Color.lbBlack : Color.lbWhite)
            .foregroundStyle(style == .apple ? Color.lbWhite : Color.lbNearBlack)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                if style == .google {
                    RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                        .strokeBorder(Color.lbG200, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var authIcon: some View {
        switch style {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 18))
        case .google:
            // Placeholder for Google icon - uses SF Symbol
            Image(systemName: "g.circle.fill")
                .font(.system(size: 18))
        }
    }
}

// MARK: - Carousel Dot Indicator

/// Dot indicator for carousel pages.
struct CarouselDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: LBTheme.Spacing.sm) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? Color.lbBlack : Color.lbG200)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Flow Layout (extracted to be reusable)

struct OnboardingFlowLayout: Layout {
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

// MARK: - Previews

#Preview("OnboardingNav") {
    VStack {
        OnboardingNav(rightLabel: "Skip")
        OnboardingNav(rightLabel: "Later")
        OnboardingNav(showBack: false)
    }
    .background(Color.lbLinen)
}

#Preview("Components") {
    VStack(spacing: 16) {
        OnboardingProgress(progress: 0.6)
        HStack(spacing: 16) {
            SelectionCircle(isSelected: false)
            SelectionCircle(isSelected: true)
        }
        OnboardingCTA("Continue") {}
        AuthDivider()
    }
    .padding()
    .background(Color.lbLinen)
}
