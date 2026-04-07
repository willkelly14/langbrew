import SwiftUI

// MARK: - Bottom Sheet Wrapper

/// A reusable bottom sheet container with a drag indicator handle.
/// Wraps content in a styled container suitable for `.sheet` presentation.
struct LBBottomSheet<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.lbG200)
                .frame(width: 36, height: 5)
                .padding(.top, LBTheme.Spacing.md)
                .padding(.bottom, LBTheme.Spacing.lg)

            content()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, LBTheme.Spacing.lg)
        .padding(.bottom, LBTheme.Spacing.xxl)
        .background(Color.lbWhite)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: LBTheme.Spacing.xl,
                topTrailingRadius: LBTheme.Spacing.xl
            )
        )
        .lbShadow(LBTheme.Shadow.sheet)
    }
}

// MARK: - Sheet Presentation Modifier

extension View {
    /// Presents a LangBrew-styled bottom sheet.
    func lbSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            LBBottomSheet(content: content)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden) // We use our own
                .presentationBackground(Color.lbWhite)
        }
    }
}

#Preview {
    LBBottomSheet {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text("Sheet Title")
                .font(LBTheme.Typography.title2)
            Text("This is content inside a bottom sheet.")
                .font(LBTheme.Typography.body)
                .foregroundStyle(Color.lbG500)
            LBButton("Confirm", variant: .primary, fullWidth: true) {}
        }
    }
    .background(Color.lbLinen)
}
