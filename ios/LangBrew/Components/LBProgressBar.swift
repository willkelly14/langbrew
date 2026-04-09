import SwiftUI

/// A configurable progress bar with rounded ends and optional label.
struct LBProgressBar: View {
    /// Progress value from 0.0 to 1.0.
    let progress: Double
    /// Foreground color of the filled portion.
    let foregroundColor: Color
    /// Background track color.
    let trackColor: Color
    /// Height of the bar.
    let height: CGFloat
    /// Optional label displayed to the right.
    let label: String?

    init(
        progress: Double,
        foregroundColor: Color = .lbBlack,
        trackColor: Color = .lbG100,
        height: CGFloat = 8,
        label: String? = nil
    ) {
        self.progress = min(max(progress, 0), 1)
        self.foregroundColor = foregroundColor
        self.trackColor = trackColor
        self.height = height
        self.label = label
    }

    var body: some View {
        HStack(spacing: LBTheme.Spacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(trackColor)

                    // Fill
                    Capsule()
                        .fill(foregroundColor)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: height)

            if let label {
                Text(label)
                    .font(LBTheme.Typography.caption)
                    .foregroundStyle(Color.lbG500)
            }
        }
    }
}

#Preview {
    VStack(spacing: LBTheme.Spacing.lg) {
        LBProgressBar(progress: 0.34, label: "34%")
        LBProgressBar(progress: 0.72, foregroundColor: .lbNearBlack, height: 12)
        LBProgressBar(progress: 1.0, foregroundColor: .lbG500)
        LBProgressBar(progress: 0.0, label: "0%")
    }
    .padding()
    .background(Color.lbLinen)
}
