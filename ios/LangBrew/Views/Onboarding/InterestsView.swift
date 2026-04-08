import SwiftUI

/// O4 -- Interests selection. Step 3 of 5.
/// Multi-select topic pills with emojis grouped by section.
/// Pills: unselected = g50 bg + g100 border. Selected = highlight bg + near-black border + medium weight.
struct InterestsView: View {
    let onboardingState: OnboardingState
    let onNext: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let minimumRequired = 3

    private let groups: [(title: String, topics: [(emoji: String, name: String)])] = [
        ("Lifestyle", [
            ("\u{2708}\u{FE0F}", "Travel"),
            ("\u{1F373}", "Food & Cooking"),
            ("\u{2600}\u{FE0F}", "Daily Life"),
            ("\u{1F4AA}", "Health"),
            ("\u{1F457}", "Fashion"),
            ("\u{1F495}", "Relationships"),
            ("\u{1F3E1}", "Home & Garden"),
        ]),
        ("Knowledge", [
            ("\u{1F52C}", "Science"),
            ("\u{1F3DB}\u{FE0F}", "History"),
            ("\u{1F3A8}", "Design"),
            ("\u{1F4BB}", "Technology"),
            ("\u{1F4C8}", "Business"),
            ("\u{1F914}", "Philosophy"),
            ("\u{1F4F0}", "News"),
            ("\u{1F30D}", "Politics"),
        ]),
        ("Entertainment", [
            ("\u{1F4D6}", "Fiction"),
            ("\u{1F3AD}", "Culture"),
            ("\u{26BD}", "Sports"),
            ("\u{1F3B5}", "Music & Art"),
            ("\u{1F33F}", "Nature"),
            ("\u{1F602}", "Humor"),
            ("\u{1F3AE}", "Gaming"),
        ]),
    ]

    private var selectionCount: Int {
        onboardingState.selectedInterests.count
    }

    private var canProceed: Bool {
        selectionCount >= minimumRequired
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
                OnboardingProgress(progress: 0.6)
                    .padding(.bottom, LBTheme.Spacing.xl)

                VStack(alignment: .leading, spacing: 0) {
                    // Step indicator
                    Text("Step 3 of 5")
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG400)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    // Title
                    Text("What do you like\nto read about?")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.xs)

                    // Subtitle
                    Text("We'll use these to personalize your passages.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.lg)

                    // Topic sections
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(groups.enumerated()), id: \.element.title) { index, group in
                                // Section label
                                Text(group.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.lbG400)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .padding(.top, index == 0 ? 0 : LBTheme.Spacing.lg)
                                    .padding(.bottom, LBTheme.Spacing.sm)

                                // Topic pills
                                OnboardingFlowLayout(spacing: LBTheme.Spacing.sm) {
                                    ForEach(group.topics, id: \.name) { topic in
                                        InterestTopicPill(
                                            emoji: topic.emoji,
                                            name: topic.name,
                                            isSelected: onboardingState.selectedInterests.contains(topic.name)
                                        ) {
                                            toggleTopic(topic.name)
                                        }
                                    }
                                }
                                .padding(.bottom, LBTheme.Spacing.lg)
                            }
                        }
                        .padding(.horizontal, LBTheme.Spacing.xl)
                    }
                }

                // Counter
                Text("\(selectionCount) selected \u{00B7} \(minimumRequired) minimum")
                    .font(LBTheme.Typography.caption)
                    .foregroundStyle(Color.lbG400)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LBTheme.Spacing.lg)

                // CTA
                OnboardingCTA("Continue", isEnabled: canProceed, action: onNext)
                    .padding(.horizontal, LBTheme.Spacing.xl)
                    .padding(.bottom, LBTheme.Spacing.md)
            }
        }
    }

    private func toggleTopic(_ topic: String) {
        if onboardingState.selectedInterests.contains(topic) {
            onboardingState.selectedInterests.remove(topic)
        } else {
            onboardingState.selectedInterests.insert(topic)
        }
    }
}

// InterestTopicPill is defined in OnboardingSetupView.swift as a shared component.

#Preview {
    InterestsView(onboardingState: OnboardingState()) {}
}
