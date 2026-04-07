import SwiftUI

/// A compact stat display card showing a large number with a label.
struct LBStatCard: View {
    let value: String
    let label: String
    let icon: String?

    init(value: String, label: String, icon: String? = nil) {
        self.value = value
        self.label = label
        self.icon = icon
    }

    /// Convenience initializer for integer values.
    init(value: Int, label: String, icon: String? = nil) {
        self.value = "\(value)"
        self.label = label
        self.icon = icon
    }

    var body: some View {
        LBCard(padding: LBTheme.Spacing.md) {
            VStack(spacing: LBTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.lbG400)
                }

                Text(value)
                    .font(LBTheme.Typography.title)
                    .foregroundStyle(Color.lbBlack)

                Text(label)
                    .font(LBTheme.Typography.caption)
                    .foregroundStyle(Color.lbG500)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    HStack(spacing: LBTheme.Spacing.md) {
        LBStatCard(value: 247, label: "Words", icon: "textformat.abc")
        LBStatCard(value: 38, label: "Learning", icon: "brain")
        LBStatCard(value: 53, label: "Mastered", icon: "checkmark.seal")
    }
    .padding()
    .background(Color.lbLinen)
}
