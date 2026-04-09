import SwiftUI

// MARK: - Daily Goal Editor View

/// A vertical list of goal rows (5/10/20/30 min) for selecting the daily goal.
/// Each row shows time on left, detail + label in middle, selection circle on right.
struct DailyGoalEditorView: View {
    let viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    private let goals: [(minutes: Int, detail: String, label: String)] = [
        (5, "1 passage", "Casual"),
        (10, "2 passages", "Steady"),
        (20, "4 passages", "Committed"),
        (30, "6 passages", "Ambitious"),
    ]

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: LBTheme.Spacing.xl) {
                // Subtitle
                VStack(spacing: LBTheme.Spacing.sm) {
                    Text("A small habit beats a big plan.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .multilineTextAlignment(.center)
                }

                // Vertical goal rows
                VStack(spacing: LBTheme.Spacing.md) {
                    ForEach(goals, id: \.minutes) { goal in
                        GoalRow(
                            minutes: goal.minutes,
                            detail: goal.detail,
                            label: goal.label,
                            isSelected: viewModel.dailyGoalMinutes == goal.minutes
                        ) {
                            viewModel.updateDailyGoal(goal.minutes)
                        }
                    }
                }
                .padding(.horizontal, LBTheme.Spacing.xl)

                Spacer()

                // Save button
                LBButton("Save", variant: .primary, fullWidth: true) {
                    dismiss()
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.bottom, LBTheme.Spacing.xl)
            }
            .padding(.top, LBTheme.Spacing.xl)
        }
        .navigationTitle("Daily Goal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Goal Row

private struct GoalRow: View {
    let minutes: Int
    let detail: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LBTheme.Spacing.lg) {
                // Time on left
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(minutes)")
                        .font(LBTheme.serifFont(size: 26))
                        .foregroundStyle(Color.lbBlack)
                    Text("min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.lbG500)
                }
                .frame(width: 70, alignment: .leading)

                // Detail + label in middle
                VStack(alignment: .leading, spacing: 2) {
                    Text(detail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lbNearBlack)

                    Text(label)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG400)
                }

                Spacer()

                // Selection circle on right
                Circle()
                    .strokeBorder(
                        isSelected ? Color.lbBlack : Color.lbG200,
                        lineWidth: isSelected ? 6 : 1.5
                    )
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.vertical, LBTheme.Spacing.lg)
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
    NavigationStack {
        DailyGoalEditorView(viewModel: SettingsViewModel(coordinator: AppCoordinator()))
    }
}
