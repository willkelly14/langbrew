import SwiftUI

/// A shimmering loading placeholder used while content is being fetched.
struct LBLoadingSkeleton: View {
    let width: CGFloat?
    let height: CGFloat

    @State private var isAnimating = false

    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: LBTheme.Radius.medium)
            .fill(Color.lbG100)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.medium)
                    .fill(shimmerGradient)
                    .offset(x: isAnimating ? 200 : -200)
            }
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                .clear,
                Color.lbWhite.opacity(0.4),
                .clear,
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// A preset skeleton layout simulating a card with multiple text lines.
struct LBCardSkeleton: View {
    var body: some View {
        LBCard {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
                LBLoadingSkeleton(width: 80, height: 14)
                LBLoadingSkeleton(height: 20)
                LBLoadingSkeleton(height: 14)
                LBLoadingSkeleton(width: 150, height: 14)
            }
        }
    }
}

#Preview {
    VStack(spacing: LBTheme.Spacing.lg) {
        LBLoadingSkeleton(height: 24)
        LBLoadingSkeleton(width: 200, height: 16)
        LBCardSkeleton()
        LBCardSkeleton()
    }
    .padding()
    .background(Color.lbLinen)
}
