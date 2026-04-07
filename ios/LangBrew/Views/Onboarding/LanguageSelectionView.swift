import SwiftUI

/// O2 -- Language selection screen. Step 1 of 5.
/// Scrollable list of language cards (horizontal rows) with flag emoji,
/// language name, native name, and selection circle.
struct LanguageSelectionView: View {
    let onboardingState: OnboardingState
    let onNext: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Language data including Dutch for 9 languages + "More" card.
    private let languages: [(code: String, flag: String, name: String, native: String)] = [
        ("es", "\u{1F1EA}\u{1F1F8}", "Spanish", "Espa\u{00F1}ol"),
        ("fr", "\u{1F1EB}\u{1F1F7}", "French", "Fran\u{00E7}ais"),
        ("de", "\u{1F1E9}\u{1F1EA}", "German", "Deutsch"),
        ("it", "\u{1F1EE}\u{1F1F9}", "Italian", "Italiano"),
        ("pt", "\u{1F1E7}\u{1F1F7}", "Portuguese", "Portugu\u{00EA}s"),
        ("nl", "\u{1F1F3}\u{1F1F1}", "Dutch", "Nederlands"),
        ("ja", "\u{1F1EF}\u{1F1F5}", "Japanese", "\u{65E5}\u{672C}\u{8A9E}"),
        ("ko", "\u{1F1F0}\u{1F1F7}", "Korean", "\u{D55C}\u{AD6D}\u{C5B4}"),
        ("zh", "\u{1F1E8}\u{1F1F3}", "Chinese", "\u{4E2D}\u{6587}"),
    ]

    private var canProceed: Bool {
        onboardingState.selectedLanguage != nil
    }

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav
                OnboardingNav(
                    showBack: true,
                    rightLabel: "Skip",
                    onBack: { dismiss() },
                    onRight: { onNext() }
                )

                // Progress bar
                OnboardingProgress(progress: 0.2)
                    .padding(.bottom, LBTheme.Spacing.xl)

                VStack(alignment: .leading, spacing: 0) {
                    // Step indicator
                    Text("Step 1 of 5")
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG400)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    // Title
                    Text("What do you want\nto read in?")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.xs)

                    // Subtitle
                    Text("Choose a language to get started.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.lg)

                    // Language list
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: LBTheme.Spacing.sm) {
                            ForEach(languages, id: \.code) { lang in
                                LanguageCardRow(
                                    flag: lang.flag,
                                    name: lang.name,
                                    native: lang.native,
                                    isSelected: onboardingState.selectedLanguage == lang.code
                                ) {
                                    onboardingState.selectedLanguage = lang.code
                                }
                            }

                            // "More languages" dimmed card
                            LanguageCardRow(
                                flag: "\u{1F30D}",
                                name: "More languages",
                                native: "Coming soon",
                                isSelected: false,
                                isDimmed: true
                            ) {}
                        }
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.md)
                    }
                }

                // CTA
                OnboardingCTA("Continue", isEnabled: canProceed, action: onNext)
                    .padding(.horizontal, LBTheme.Spacing.xl)
                    .padding(.bottom, LBTheme.Spacing.md)
            }
        }
    }
}

// MARK: - Language Card Row

private struct LanguageCardRow: View {
    let flag: String
    let name: String
    let native: String
    let isSelected: Bool
    var isDimmed: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Flag emoji
                Text(flag)
                    .font(.system(size: 26))
                    .frame(width: 36, alignment: .center)

                // Language info
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isDimmed ? Color.lbG400 : Color.lbBlack)

                    Text(native)
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG500)
                }

                Spacer()

                // Selection circle
                if !isDimmed {
                    SelectionCircle(isSelected: isSelected)
                }
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.vertical, 14)
            .background(isSelected ? Color.lbHighlight : Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(
                        isSelected ? Color.lbNearBlack : Color.lbG100,
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isDimmed)
        .opacity(isDimmed ? 0.45 : 1)
    }
}

#Preview {
    LanguageSelectionView(onboardingState: OnboardingState()) {}
}
