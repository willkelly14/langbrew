import SwiftUI

/// O3 -- Proficiency level selection. Step 2 of 5.
/// Displays language flag, horizontal level cards with selection circle (left),
/// level name + description (middle), CEFR pill badge (right).
struct ProficiencyView: View {
    let onboardingState: OnboardingState
    let onNext: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let levels: [(code: String, name: String, description: String)] = [
        ("A1", "Just starting out", "I know a few words and basic phrases."),
        ("A2", "I know the basics", "I can understand simple sentences about familiar topics."),
        ("B1", "Getting comfortable", "I can read straightforward texts about everyday things."),
        ("B2", "Fairly confident", "I can read articles and stories with some effort."),
    ]

    private var languageName: String {
        if let code = onboardingState.selectedLanguage {
            return FlagMapper.languageName(for: code)
        }
        return "a language"
    }

    private var languageFlag: String {
        if let code = onboardingState.selectedLanguage {
            return FlagMapper.flag(for: code)
        }
        return "🌐"
    }

    private var canProceed: Bool {
        onboardingState.selectedLevel != nil
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
                OnboardingProgress(progress: 0.4)
                    .padding(.bottom, LBTheme.Spacing.xl)

                VStack(spacing: 0) {
                    // Step indicator
                    Text("Step 2 of 5 \u{00B7} \(languageName)")
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG400)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    // Large flag
                    Text(languageFlag)
                        .font(.system(size: 40))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    // Title
                    Text("How much \(languageName)\ndo you know?")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.xs)

                    // Subtitle
                    Text("Pick the level that feels closest.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.lg)

                    // Level cards
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(levels, id: \.code) { level in
                                LevelCardRow(
                                    code: level.code,
                                    name: level.name,
                                    description: level.description,
                                    isSelected: onboardingState.selectedLevel == level.code
                                ) {
                                    onboardingState.selectedLevel = level.code
                                }
                            }
                        }
                        .padding(.horizontal, LBTheme.Spacing.xl)
                    }
                }

                // Reassurance text
                Text("Don't worry \u{2014} we'll adjust as we learn what you know.")
                    .font(LBTheme.Typography.caption)
                    .foregroundStyle(Color.lbG400)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.vertical, LBTheme.Spacing.sm)
                    .padding(.horizontal, LBTheme.Spacing.xl)

                // CTA
                OnboardingCTA("Continue", isEnabled: canProceed, action: onNext)
                    .padding(.horizontal, LBTheme.Spacing.xl)
                    .padding(.bottom, LBTheme.Spacing.md)
            }
        }
    }
}

// MARK: - Level Card Row

private struct LevelCardRow: View {
    let code: String
    let name: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                // Selection circle
                SelectionCircle(isSelected: isSelected)
                    .padding(.top, 2)

                // Level text
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.lbBlack)

                    Text(description)
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG500)
                        .lineSpacing(2)
                }

                Spacer()

                // CEFR pill
                Text(code)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.lbG500)
                    .padding(.horizontal, LBTheme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Color.lbG100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(LBTheme.Spacing.lg)
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
    }
}

#Preview {
    ProficiencyView(onboardingState: OnboardingState()) {}
}
