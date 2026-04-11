import SwiftUI

// MARK: - Design Tokens

enum LBTheme {

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: Radius

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let card: CGFloat = 12
        static let large: CGFloat = 12
        static let full: CGFloat = .infinity
    }

    // MARK: Shadows

    struct ShadowStyle: Sendable {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        static let card = ShadowStyle(
            color: .black.opacity(0.06),
            radius: 2,
            x: 0,
            y: 1
        )
        static let elevated = ShadowStyle(
            color: .black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
        static let sheet = ShadowStyle(
            color: .black.opacity(0.08),
            radius: 10,
            x: 0,
            y: -4
        )
    }

    // MARK: Typography

    private static let serifFontName = "InstrumentSerif-Regular"
    private static let serifFallback = "Georgia"

    private static let sansFamilyName = "Instrument Sans"

    /// Returns a serif font, falling back to Georgia if Instrument Serif is not available.
    static func serifFont(size: CGFloat) -> Font {
        if UIFont(name: serifFontName, size: size) != nil {
            return .custom(serifFontName, size: size)
        }
        return .custom(serifFallback, size: size)
    }

    /// Returns a sans font at the given weight using the Instrument Sans variable font.
    /// Falls back to the system font if Instrument Sans is not available.
    private static func sansFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let uiWeight: UIFont.Weight = switch weight {
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        default: .regular
        }

        // Use font descriptor to select the correct weight from the variable font.
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: sansFamilyName,
            .traits: [UIFontDescriptor.TraitKey.weight: uiWeight]
        ])
        let uiFont = UIFont(descriptor: descriptor, size: size)

        // Verify the family resolved correctly; fall back to system if not.
        if uiFont.familyName == sansFamilyName {
            return Font(uiFont)
        }
        return .system(size: size, weight: weight)
    }

    enum Typography {
        /// 36pt serif - hero headlines, splash.
        static let largeTitle: Font = serifFont(size: 36)

        /// 30pt serif - section headers, screen titles.
        static let title: Font = serifFont(size: 30)

        /// 22pt serif - card titles, subheadings.
        static let title2: Font = serifFont(size: 22)

        /// 17pt serif - inline headings, emphasized text.
        static let headline: Font = serifFont(size: 17)

        /// 15pt sans regular - primary body text.
        static let body: Font = sansFont(size: 15, weight: .regular)

        /// 15pt sans medium - emphasized body text, labels.
        static let bodyMedium: Font = sansFont(size: 15, weight: .medium)

        /// 13pt sans regular - secondary info, captions.
        static let caption: Font = sansFont(size: 13, weight: .regular)

        /// 11pt sans semibold uppercase - badges, tiny labels.
        static let small: Font = sansFont(size: 11, weight: .semibold)
    }
}

// MARK: - Shadow View Modifier

extension View {
    /// Applies a LangBrew shadow style.
    func lbShadow(_ style: LBTheme.ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}

// MARK: - Small/Uppercase Text Style Modifier

extension View {
    /// Applies the "small" typographic style: 11pt semibold, uppercase, with tracking.
    func lbSmallStyle() -> some View {
        self
            .font(LBTheme.Typography.small)
            .textCase(.uppercase)
            .kerning(0.8)
    }
}
