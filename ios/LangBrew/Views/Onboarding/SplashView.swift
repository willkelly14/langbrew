import SwiftUI

/// S1 -- Splash screen showing the LangBrew logo with a fade-in animation.
/// Auto-transitions to the next screen after a brief pause.
///
/// Mockup: Logo image (120x120, placeholder rounded rect with "lb" text),
/// centered vertically. Below it: "langbrew" in Instrument Serif 28pt.
/// Linen background. Fade-in animation with subtle pulse on logo.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.96
    @State private var logoOffsetY: CGFloat = 8
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkScale: CGFloat = 0.96
    @State private var wordmarkOffsetY: CGFloat = 8
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: LBTheme.Spacing.lg) {
                // Logo image (120x120)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                    .opacity(logoOpacity * (isPulsing ? 0.7 : 1.0))
                    .scaleEffect(logoScale)
                    .offset(y: logoOffsetY)

                // Wordmark
                Text("langbrew")
                    .font(LBTheme.serifFont(size: 28))
                    .foregroundStyle(Color.lbBlack)
                    .opacity(wordmarkOpacity)
                    .scaleEffect(wordmarkScale)
                    .offset(y: wordmarkOffsetY)
            }
        }
        .task {
            // Fade in logo
            withAnimation(.easeOut(duration: 1.0)) {
                logoOpacity = 1
                logoScale = 1
                logoOffsetY = 0
            }

            try? await Task.sleep(for: .milliseconds(500))

            // Fade in wordmark
            withAnimation(.easeOut(duration: 0.8)) {
                wordmarkOpacity = 1
                wordmarkScale = 1
                wordmarkOffsetY = 0
            }

            // Start pulse after 1.2s
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }

            // Auto-transition after viewing splash
            try? await Task.sleep(for: .seconds(1))
            onFinished()
        }
    }
}

#Preview {
    SplashView {}
}
