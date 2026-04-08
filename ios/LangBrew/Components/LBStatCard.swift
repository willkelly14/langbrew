import SwiftUI

/// A compact stat display card showing a large number with a label.
/// Matches the mockup: white bg, 10px radius, 10px padding, 24px serif number, 11px label.
struct LBStatCard: View {
    let value: String
    let label: String

    init(value: String, label: String) {
        self.value = value
        self.label = label
    }

    /// Convenience initializer for integer values.
    init(value: Int, label: String) {
        self.value = "\(value)"
        self.label = label
    }

    var body: some View {
        VStack(spacing: LBTheme.Spacing.xs) {
            Text(value)
                .font(LBTheme.serifFont(size: 24))
                .foregroundStyle(Color.lbBlack)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.lbG500)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
        .lbShadow(LBTheme.Shadow.card)
    }
}

#Preview {
    HStack(spacing: LBTheme.Spacing.md) {
        LBStatCard(value: 247, label: "Words")
        LBStatCard(value: 38, label: "Learning")
        LBStatCard(value: 53, label: "Mastered")
    }
    .padding()
    .background(Color.lbLinen)
}
