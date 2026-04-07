import SwiftUI

/// An error display with icon, message, and retry button.
struct LBErrorState: View {
    let message: String
    let retryAction: (() -> Void)?

    init(message: String = "Something went wrong.", retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: LBTheme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.lbG400)

            Text(message)
                .font(LBTheme.Typography.body)
                .foregroundStyle(Color.lbG500)
                .multilineTextAlignment(.center)

            if let retryAction {
                LBButton("Try Again", variant: .secondary, icon: "arrow.clockwise", action: retryAction)
            }
        }
        .padding(LBTheme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: LBTheme.Spacing.xxl) {
        LBErrorState(message: "Unable to load passages. Check your connection.") {}
        LBErrorState(message: "Something went wrong.")
    }
    .background(Color.lbLinen)
}
