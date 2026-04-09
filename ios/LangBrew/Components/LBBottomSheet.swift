import SwiftUI

// MARK: - Bottom Sheet Wrapper

/// A reusable bottom sheet container with a drag indicator handle.
/// Supports drag-to-dismiss when `onDismiss` is provided — drag anywhere on the sheet.
/// Extends into the bottom safe area to avoid gaps.
struct LBBottomSheet<Content: View>: View {
    var onDismiss: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing: Bool = false

    init(onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.onDismiss = onDismiss
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator handle
            Capsule()
                .fill(Color.lbG200)
                .frame(width: 36, height: 5)
                .padding(.top, LBTheme.Spacing.md)
                .padding(.bottom, LBTheme.Spacing.lg)

            content()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, LBTheme.Spacing.md)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                topTrailingRadius: 12
            )
            .fill(Color.lbWhite)
            .ignoresSafeArea(edges: .bottom)
        )
        .lbShadow(LBTheme.Shadow.sheet)
        .ignoresSafeArea(edges: .bottom)
        .offset(y: dragOffset)
        .gesture(sheetDragGesture)
    }

    private var sheetDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow dragging downward
                let translation = value.translation.height
                if translation > 0 {
                    // Apply rubber-band resistance
                    dragOffset = translation
                } else {
                    // Slight resistance going upward
                    dragOffset = translation * 0.1
                }
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height
                let translation = value.translation.height

                if translation > 120 || velocity > 500 {
                    // Dismiss: slide off screen
                    isDismissing = true
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset = UIScreen.main.bounds.height
                    }
                    // Call dismiss after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        // Disable animations so the exit transition doesn't
                        // flash the sheet back on screen at offset 0.
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            onDismiss?()
                        }
                        dragOffset = 0
                        isDismissing = false
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dragOffset = 0
                    }
                }
            }
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
