import SwiftUI

/// O5 -- Daily goal selection. Step 4 of 5.
/// Goal cards (horizontal rows) with time, detail, label, selection circle.
/// "Popular" badge on 10 min card. Streak preview dots below.
struct DailyGoalView: View {
    let onboardingState: OnboardingState
    let onNext: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let goals: [(minutes: Int, detail: String, label: String, badge: String?)] = [
        (5, "1 passage", "Casual", nil),
        (10, "2 passages", "Steady", "Popular"),
        (20, "4 passages", "Committed", nil),
        (30, "6 passages", "Ambitious", nil),
    ]

    private let weekDays = ["M", "T", "W", "T", "F", "S", "S"]

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
                OnboardingProgress(progress: 0.8)
                    .padding(.bottom, LBTheme.Spacing.xl)

                VStack(alignment: .leading, spacing: 0) {
                    // Step indicator
                    Text("Step 4 of 5")
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG400)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    // Title
                    Text("Set a daily goal.")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.xs)

                    // Subtitle
                    Text("A small habit beats a big plan.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.lg)

                    // Goal cards
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(goals, id: \.minutes) { goal in
                                GoalCardRow(
                                    minutes: goal.minutes,
                                    detail: goal.detail,
                                    label: goal.label,
                                    badge: goal.badge,
                                    isSelected: onboardingState.dailyGoalMinutes == goal.minutes
                                ) {
                                    onboardingState.dailyGoalMinutes = goal.minutes
                                }
                            }
                        }
                        .padding(.horizontal, LBTheme.Spacing.xl)

                        // Streak preview
                        VStack(spacing: LBTheme.Spacing.sm) {
                            HStack(spacing: LBTheme.Spacing.lg) {
                                ForEach(0..<7, id: \.self) { index in
                                    VStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.lbG50)
                                            .frame(width: 18, height: 18)
                                            .overlay {
                                                Circle()
                                                    .strokeBorder(Color.lbG200, lineWidth: 2)
                                            }
                                        Text(weekDays[index])
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.lbG400)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, LBTheme.Spacing.xl)

                            Text("Your first week starts now")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.lbG400)
                                .padding(.bottom, LBTheme.Spacing.lg)
                        }
                    }
                }

                // CTA
                OnboardingCTA("Continue", action: onNext)
                    .padding(.horizontal, LBTheme.Spacing.xl)
                    .padding(.bottom, LBTheme.Spacing.md)
            }
        }
    }
}

// GoalCardRow is defined in OnboardingSetupView.swift as a shared component.

#Preview {
    DailyGoalView(onboardingState: OnboardingState()) {}
}
