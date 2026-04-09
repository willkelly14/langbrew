import SwiftUI

// MARK: - Hex Color Initializer

extension Color {
    /// Creates a Color from a hex string (e.g., "#2a2318" or "2a2318").
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - LangBrew Color Palette

extension Color {
    /// Deep brown-black, primary text color.
    static let lbBlack = Color(hex: "2a2318")

    /// Near-black, secondary dark.
    static let lbNearBlack = Color(hex: "3d3529")

    /// Gray 50 - lightest warm gray.
    static let lbG50 = Color(hex: "ebe7de")

    /// Gray 100.
    static let lbG100 = Color(hex: "e0dbd0")

    /// Gray 200.
    static let lbG200 = Color(hex: "c8c1b3")

    /// Gray 300.
    static let lbG300 = Color(hex: "a89f91")

    /// Gray 400.
    static let lbG400 = Color(hex: "8a8178")

    /// Gray 500 - darkest warm gray.
    static let lbG500 = Color(hex: "6d655d")

    /// Off-white — primary surface white.
    static let lbWhite = Color(hex: "faf9f6")

    /// Linen cream - primary background.
    static let lbLinen = Color(hex: "f3f0ea")

    /// Highlight yellow - vocabulary highlights.
    static let lbHighlight = Color(hex: "ede8d2")

    /// Vocabulary highlight border color used in the reader.
    static let lbHighlightBorder = Color(hex: "c9be8a")
}

// MARK: - ShapeStyle Convenience

extension ShapeStyle where Self == Color {
    static var lbBlack: Color { .lbBlack }
    static var lbNearBlack: Color { .lbNearBlack }
    static var lbG50: Color { .lbG50 }
    static var lbG100: Color { .lbG100 }
    static var lbG200: Color { .lbG200 }
    static var lbG300: Color { .lbG300 }
    static var lbG400: Color { .lbG400 }
    static var lbG500: Color { .lbG500 }
    static var lbWhite: Color { .lbWhite }
    static var lbLinen: Color { .lbLinen }
    static var lbHighlight: Color { .lbHighlight }
    static var lbHighlightBorder: Color { .lbHighlightBorder }
}
