import SwiftUI

// MARK: - Upgrade Sheet

/// Bottom sheet shown when the user hits their free tier passage generation limit.
/// Prompts the user to upgrade their subscription.
struct UpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: LBTheme.Spacing.xl) {
            // Handle
            Capsule()
                .fill(Color.lbG300)
                .frame(width: 36, height: 4)
                .padding(.top, LBTheme.Spacing.md)

            Spacer()

            // Icon
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.lbBlack)

            // Title
            Text("Upgrade to Fluency")
                .font(LBTheme.Typography.title2)
                .foregroundStyle(Color.lbBlack)
                .multilineTextAlignment(.center)

            // Description
            Text("You have reached your monthly passage limit on the free plan. Upgrade to Fluency for up to 1,000 passages per month and unlimited conversation practice.")
                .font(LBTheme.Typography.body)
                .foregroundStyle(Color.lbG500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LBTheme.Spacing.lg)

            Spacer()

            // Buttons
            VStack(spacing: LBTheme.Spacing.md) {
                LBButton("View Plans", variant: .primary, fullWidth: true) {
                    // Navigate to subscription / plans screen.
                    // Placeholder for now; will be wired when Settings is built.
                    dismiss()
                }

                Button {
                    dismiss()
                } label: {
                    Text("Not Now")
                        .font(LBTheme.Typography.bodyMedium)
                        .foregroundStyle(Color.lbG500)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.bottom, LBTheme.Spacing.xl)
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            UpgradeSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.lbWhite)
        }
}
