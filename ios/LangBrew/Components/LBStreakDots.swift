import SwiftUI

/// Displays a 7-day streak indicator with filled/empty circles and day labels.
struct LBStreakDots: View {
    /// Array of 7 bools indicating completion for each day (Monday through Sunday).
    let days: [Bool]

    private static let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    init(days: [Bool]) {
        // Ensure exactly 7 entries; pad or truncate as needed.
        if days.count >= 7 {
            self.days = Array(days.prefix(7))
        } else {
            self.days = days + Array(repeating: false, count: 7 - days.count)
        }
    }

    var body: some View {
        HStack(spacing: LBTheme.Spacing.md) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: LBTheme.Spacing.xs) {
                    Circle()
                        .fill(days[index] ? Color.lbBlack : Color.lbG200)
                        .frame(width: 10, height: 10)

                    Text(Self.dayLabels[index])
                        .font(LBTheme.Typography.small)
                        .foregroundStyle(days[index] ? Color.lbBlack : Color.lbG400)
                        .textCase(.uppercase)
                        .kerning(0.5)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: LBTheme.Spacing.lg) {
        LBStreakDots(days: [true, true, true, true, false, false, false])
        LBStreakDots(days: [true, true, true, true, true, true, true])
        LBStreakDots(days: [false, false, false, false, false, false, false])
    }
    .padding()
    .background(Color.lbLinen)
}
