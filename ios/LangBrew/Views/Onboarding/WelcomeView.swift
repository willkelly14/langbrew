import SwiftUI

/// O1 -- Welcome screen with numbered steps showing the three pillars of LangBrew.
/// Matches the d5-steps variant from the HTML mockup.
struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: LBTheme.Spacing.xxl)

                        // Logo
                        RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                            .fill(Color.lbBlack)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text("lb")
                                    .font(LBTheme.serifFont(size: 30))
                                    .foregroundStyle(Color.lbLinen)
                            }
                            .padding(.bottom, LBTheme.Spacing.md)

                        // Tag
                        Text("LANGBREW")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.lbG500)
                            .padding(.bottom, LBTheme.Spacing.lg)

                        // Headline
                        Text("Learn by\nunderstanding.")
                            .font(LBTheme.serifFont(size: 32))
                            .foregroundStyle(Color.lbBlack)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.bottom, 6)

                        // Subtitle
                        Text("Read, talk, and revise \u{2014} all matched to your level.")
                            .font(LBTheme.Typography.body)
                            .foregroundStyle(Color.lbG500)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 28)

                        // Numbered steps
                        WelcomeSteps()
                            .padding(.horizontal, 30)

                        Spacer(minLength: LBTheme.Spacing.xl)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Bottom section
                VStack(spacing: LBTheme.Spacing.sm) {
                    OnboardingCTA("Get Started", action: onGetStarted)

                    Button(action: onSignIn) {
                        Text("Already have an account? ")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbG400)
                        + Text("Sign in")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.lbG400)
                    }
                    .padding(.bottom, LBTheme.Spacing.sm)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, LBTheme.Spacing.md)
            }
        }
    }
}

// MARK: - Numbered Steps

private struct WelcomeSteps: View {
    var body: some View {
        VStack(spacing: 0) {
            // Step 1: Read
            WelcomeStep(number: 1, title: "Read at your level", showLine: true) {
                WelcomeReadPreview()
            }

            // Step 2: Talk
            WelcomeStep(number: 2, title: "Talk about what interests you", showLine: true) {
                WelcomeChatPreview()
            }

            // Step 3: Revise
            WelcomeStep(number: 3, title: "Revise what's tricky", showLine: false) {
                WelcomeFlashcardPreview()
            }
        }
    }
}

// MARK: - Single Step

private struct WelcomeStep<Content: View>: View {
    let number: Int
    let title: String
    let showLine: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: number circle + connecting line
            VStack(spacing: 0) {
                // Number circle
                ZStack {
                    Circle()
                        .fill(Color.lbBlack)
                        .frame(width: 30, height: 30)

                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.lbWhite)
                }

                // Connecting line
                if showLine {
                    Rectangle()
                        .fill(Color.lbG200)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 30)

            // Right: title + content
            VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.lbBlack)

                content()
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 1: Read Preview

private struct WelcomeReadPreview: View {
    var body: some View {
        HStack(alignment: .top, spacing: LBTheme.Spacing.md) {
            // Mini book cover placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.lbG200)
                .frame(width: 48, height: 68)
                .lbShadow(LBTheme.Shadow.elevated)

            // Passage text with vocab highlights
            passageText
                .font(.custom("Georgia", size: 13))
                .foregroundStyle(Color.lbNearBlack)
                .lineSpacing(4)
                .lineLimit(3)
        }
    }

    private var passageText: Text {
        let a: Text = Text("Mar\u{00ED}a se despierta ")
        let b: Text = Text(highlightedWord("temprano"))
            .foregroundColor(Color.lbNearBlack)
        let c: Text = Text(" cada s\u{00E1}bado. Ella camina al ")
        let d: Text = Text(highlightedWord("mercado"))
            .foregroundColor(Color.lbNearBlack)
        let e: Text = Text(" con su bolsa grande\u{2026}")
        return a + b + c + d + e
    }

    private func highlightedWord(_ word: String) -> AttributedString {
        var attr = AttributedString(word)
        attr.backgroundColor = Color.lbHighlight
        return attr
    }
}

// MARK: - Step 2: Chat Preview

private struct WelcomeChatPreview: View {
    var body: some View {
        VStack(spacing: 6) {
            // AI bubble
            HStack {
                Text("\u{00BF}Qu\u{00E9} compr\u{00F3} Mar\u{00ED}a en el mercado?")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbNearBlack)
                    .lineSpacing(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.lbWhite)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 4,
                            bottomTrailingRadius: 12,
                            topTrailingRadius: 12
                        )
                    )
                Spacer(minLength: 0)
            }

            // User bubble
            HStack {
                Spacer(minLength: 0)
                Text("Ella compr\u{00F3} tomates rojos.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbWhite)
                    .lineSpacing(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.lbBlack)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: 12,
                            bottomTrailingRadius: 4,
                            topTrailingRadius: 12
                        )
                    )
            }
        }
    }
}

// MARK: - Step 3: Flashcard Preview

private struct WelcomeFlashcardPreview: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("mercado")
                    .font(.custom("Georgia", size: 22).italic())
                    .foregroundStyle(Color.lbBlack)

                Text("market")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG400)
            }

            Spacer()

            // Progress dots
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < 3 ? Color.lbBlack : Color.lbG200)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

#Preview {
    WelcomeView(onGetStarted: {}, onSignIn: {})
}
