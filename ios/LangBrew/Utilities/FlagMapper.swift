import Foundation

/// Maps ISO 639-1 language codes to their corresponding flag emojis.
enum FlagMapper {
    private static let mapping: [String: String] = [
        "es": "\u{1F1EA}\u{1F1F8}", // Spanish
        "fr": "\u{1F1EB}\u{1F1F7}", // French
        "pt": "\u{1F1E7}\u{1F1F7}", // Portuguese (Brazil)
        "it": "\u{1F1EE}\u{1F1F9}", // Italian
        "de": "\u{1F1E9}\u{1F1EA}", // German
        "ja": "\u{1F1EF}\u{1F1F5}", // Japanese
        "ko": "\u{1F1F0}\u{1F1F7}", // Korean
        "zh": "\u{1F1E8}\u{1F1F3}", // Chinese
    ]

    /// Returns the flag emoji for a given language code, or a globe emoji if unknown.
    static func flag(for languageCode: String) -> String {
        mapping[languageCode.lowercased()] ?? "\u{1F310}" // Globe
    }

    /// Returns the display name for a language code.
    static func languageName(for code: String) -> String {
        let names: [String: String] = [
            "es": "Spanish",
            "fr": "French",
            "pt": "Portuguese",
            "it": "Italian",
            "de": "German",
            "ja": "Japanese",
            "ko": "Korean",
            "zh": "Chinese",
        ]
        return names[code.lowercased()] ?? code.uppercased()
    }

    /// Returns the native name for a language code.
    static func nativeName(for code: String) -> String {
        let names: [String: String] = [
            "es": "Espa\u{00F1}ol",
            "fr": "Fran\u{00E7}ais",
            "pt": "Portugu\u{00EA}s",
            "it": "Italiano",
            "de": "Deutsch",
            "ja": "\u{65E5}\u{672C}\u{8A9E}",
            "ko": "\u{D55C}\u{AD6D}\u{C5B4}",
            "zh": "\u{4E2D}\u{6587}",
        ]
        return names[code.lowercased()] ?? code.uppercased()
    }

    /// All supported language codes.
    static let supportedLanguages: [String] = ["es", "fr", "pt", "it", "de", "ja", "ko", "zh"]
}
