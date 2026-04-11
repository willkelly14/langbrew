import SwiftUI

// MARK: - Passage Loading View

/// Full-screen overlay shown during passage generation.
/// Displays floating words rising like steam, with rotating status messages.
/// Matches the L0 loading screen from the mockup.
struct PassageLoadingView: View {
    @State private var currentMessageIndex: Int = 0
    @State private var messageOpacity: Double = 1.0

    private let messages = MockPassageData.loadingMessages
    private let messageTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background
            Color.lbLinen
                .ignoresSafeArea()

            // Floating words layer
            FloatingWordsView()

            // Center content
            VStack(spacing: LBTheme.Spacing.lg) {
                Spacer()

                // Status message
                Text(messages[currentMessageIndex])
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.lbNearBlack)
                    .opacity(messageOpacity)
                    .animation(.easeInOut(duration: 0.4), value: messageOpacity)

                // Bouncing dots
                BouncingDots()

                Spacer()
                Spacer()
            }
        }
        .onReceive(messageTimer) { _ in
            cycleMessage()
        }
    }

    private func cycleMessage() {
        withAnimation(.easeOut(duration: 0.3)) {
            messageOpacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            currentMessageIndex = (currentMessageIndex + 1) % messages.count
            withAnimation(.easeIn(duration: 0.3)) {
                messageOpacity = 1
            }
        }
    }
}

// MARK: - Floating Words View

/// Animates words floating upward like steam, fading in and out.
/// Words use Instrument Serif italic, color g300.
struct FloatingWordsView: View {
    @State private var particles: [FloatingWord] = []

    private let words = MockPassageData.floatingWords
    private let spawnTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.text)
                        .font(LBTheme.serifFont(size: particle.fontSize))
                        .italic()
                        .foregroundStyle(Color.lbG300)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onReceive(spawnTimer) { _ in
                spawnWord(in: geometry.size)
                removeOldWords()
            }
        }
    }

    private func spawnWord(in size: CGSize) {
        guard !words.isEmpty else { return }

        let word = words.randomElement() ?? "hola"
        let fontSize = CGFloat.random(in: 11...19)
        let startX = CGFloat.random(in: 40...(size.width - 40))
        let startY = size.height + 20

        let particle = FloatingWord(
            text: word,
            fontSize: fontSize,
            x: startX,
            y: startY,
            opacity: 0,
            createdAt: Date()
        )

        particles.append(particle)

        // Animate the word floating up and fading in/out
        let index = particles.count - 1
        guard index < particles.count else { return }

        withAnimation(.easeOut(duration: 0.8)) {
            particles[index].opacity = 0.6
        }

        withAnimation(.linear(duration: CGFloat.random(in: 6...9))) {
            particles[index].y = -30
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard index < particles.count else { return }
            withAnimation(.easeIn(duration: 1.5)) {
                particles[index].opacity = 0
            }
        }
    }

    private func removeOldWords() {
        let cutoff = Date().addingTimeInterval(-10)
        particles.removeAll { $0.createdAt < cutoff }
    }
}

// MARK: - Floating Word Model

/// Represents a single floating word particle in the loading animation.
struct FloatingWord: Identifiable {
    let id = UUID()
    let text: String
    let fontSize: CGFloat
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
    let createdAt: Date
}

// MARK: - Bouncing Dots

/// Three dots that bounce sequentially below the status message.
struct BouncingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.lbG400)
                    .frame(width: 6, height: 6)
                    .offset(y: animating ? -8 : 0)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    PassageLoadingView()
}
