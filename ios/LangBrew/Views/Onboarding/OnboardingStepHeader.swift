import SwiftUI

/// Reusable header showing "Step X of Y" with a progress indicator.
struct OnboardingStepHeader: View {
    let step: Int
    let totalSteps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            Text("Step \(step) of \(totalSteps)")
                .lbSmallStyle()
                .foregroundStyle(Color.lbG400)

            LBProgressBar(
                progress: Double(step) / Double(totalSteps),
                height: 4
            )
        }
    }
}

#Preview {
    VStack(spacing: LBTheme.Spacing.xl) {
        OnboardingStepHeader(step: 1, totalSteps: 5)
        OnboardingStepHeader(step: 3, totalSteps: 5)
        OnboardingStepHeader(step: 5, totalSteps: 5)
    }
    .padding()
    .background(Color.lbLinen)
}
