import SwiftUI

/// O7 -- Celebration screen after completing onboarding.
/// No nav bar. "You're all set." large celebratory text, subtitle,
/// passage preview card with A2 pill + "For you" badge + language label,
/// "Start Learning" CTA, "Explore the app first" secondary link.
struct FirstPassageView: View {
    let onboardingState: OnboardingState
    let onStartLearning: () -> Void

    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16

    private var languageName: String {
        if let code = onboardingState.selectedLanguage {
            return FlagMapper.languageName(for: code)
        }
        return "French"
    }

    private var level: String {
        onboardingState.selectedLevel ?? "A2"
    }

    private var sampleExcerpt: String {
        guard let code = onboardingState.selectedLanguage else {
            return frenchSample
        }
        return sampleText(for: code)
    }

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Celebration title
                VStack(spacing: 6) {
                    Text("You're all set.")
                        .font(LBTheme.serifFont(size: 34))
                        .foregroundStyle(Color.lbBlack)

                    Text("Here's your first passage, picked just for you.")
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.bottom, LBTheme.Spacing.xl)

                // Passage preview card
                VStack(alignment: .leading, spacing: 0) {
                    // Top badges
                    HStack(spacing: LBTheme.Spacing.sm) {
                        // Level pill
                        Text(level)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.lbNearBlack)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.lbG100)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        // AI badge
                        Text("For you")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.lbNearBlack)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.lbHighlight)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Spacer()

                        // Language label
                        Text(languageName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.lbG400)
                    }
                    .padding(.bottom, LBTheme.Spacing.md)

                    // Title
                    Text("A Day in the Park")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.lbBlack)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    // Meta
                    Text("~4 min \u{00B7} 12 new words \u{00B7} 96% known")
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG500)
                        .padding(.bottom, LBTheme.Spacing.lg)

                    // Passage text with fade
                    ZStack(alignment: .bottom) {
                        Text(sampleExcerpt)
                            .font(LBTheme.Typography.body)
                            .foregroundStyle(Color.lbG500)
                            .lineSpacing(5)

                        // Fade overlay
                        LinearGradient(
                            colors: [Color.lbWhite.opacity(0), Color.lbWhite],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                    }

                    // Progress bar
                    Rectangle()
                        .fill(Color.lbG200)
                        .frame(height: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .padding(.top, LBTheme.Spacing.lg)
                }
                .padding(LBTheme.Spacing.xl)
                .background(Color.lbWhite)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                .opacity(cardOpacity)
                .scaleEffect(cardScale)
                .padding(.horizontal, LBTheme.Spacing.xl)

                Spacer()

                // Sync error
                if let syncError = onboardingState.syncError {
                    Text(syncError)
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.sm)
                }

                // Buttons
                VStack(spacing: LBTheme.Spacing.md) {
                    OnboardingCTA(
                        "Start Learning",
                        isLoading: onboardingState.isSyncing
                    ) {
                        Task {
                            await handleStartLearning()
                        }
                    }

                    Button {
                        Task {
                            await handleStartLearning()
                        }
                    } label: {
                        Text("Explore the app first")
                            .font(LBTheme.Typography.body)
                            .foregroundStyle(Color.lbG500)
                    }
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.bottom, LBTheme.Spacing.md)
            }
        }
        .task {
            // Animate title
            withAnimation(.easeOut(duration: 0.5)) {
                titleOpacity = 1
                titleOffset = 0
            }

            try? await Task.sleep(for: .milliseconds(200))

            // Animate card
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                cardOpacity = 1
                cardScale = 1.0
            }
        }
    }

    // MARK: - Actions

    private func handleStartLearning() async {
        await onboardingState.syncToBackend()
        onStartLearning()
    }

    // MARK: - Sample Texts

    private var frenchSample: String {
        "Ce matin, Marie se r\u{00E9}veille t\u{00F4}t. Le soleil brille d\u{00E9}j\u{00E0} par la fen\u{00EA}tre de sa chambre. Elle d\u{00E9}cide d'aller au parc avec son chien, un petit bouledogue fran\u{00E7}ais qui s'appelle L\u{00E9}o. Elle met ses chaussures\u{2026}"
    }

    private func sampleText(for code: String) -> String {
        switch code {
        case "es": return "El parque estaba tranquilo esa ma\u{00F1}ana. Los \u{00E1}rboles se mov\u{00ED}an suavemente con el viento mientras los p\u{00E1}jaros cantaban entre las ramas."
        case "fr": return frenchSample
        case "pt": return "O parque estava tranquilo naquela manh\u{00E3}. As \u{00E1}rvores balan\u{00E7}avam suavemente com o vento enquanto os p\u{00E1}ssaros cantavam entre os galhos."
        case "it": return "Il parco era tranquillo quella mattina. Gli alberi si muovevano dolcemente con il vento mentre gli uccelli cantavano tra i rami."
        case "de": return "Der Park war an diesem Morgen ruhig. Die B\u{00E4}ume wiegten sich sanft im Wind, w\u{00E4}hrend die V\u{00F6}gel in den \u{00C4}sten sangen."
        case "ja": return "\u{305D}\u{306E}\u{671D}\u{3001}\u{516C}\u{5712}\u{306F}\u{9759}\u{304B}\u{3060}\u{3063}\u{305F}\u{3002}\u{6728}\u{3005}\u{306F}\u{98A8}\u{306B}\u{3086}\u{3063}\u{304F}\u{308A}\u{63FA}\u{308C}\u{3001}\u{9CE5}\u{305F}\u{3061}\u{306F}\u{679D}\u{306E}\u{9593}\u{3067}\u{6B4C}\u{3063}\u{3066}\u{3044}\u{305F}\u{3002}"
        case "ko": return "\u{ADF8}\u{B0A0} \u{C544}\u{CE68} \u{ACF5}\u{C6D0}\u{C740} \u{C870}\u{C6A9}\u{D588}\u{B2E4}. \u{B098}\u{BB34}\u{B4E4}\u{C740} \u{BC14}\u{B78C}\u{C5D0} \u{BD80}\u{B4DC}\u{B7FD}\u{AC8C} \u{D754}\u{B4E4}\u{B9AC}\u{ACE0} \u{C0C8}\u{B4E4}\u{C740} \u{B098}\u{BB47}\u{AC00}\u{C9C0} \u{C0AC}\u{C774}\u{C5D0}\u{C11C} \u{B178}\u{B798}\u{D558}\u{ACE0} \u{C788}\u{C5C8}\u{B2E4}."
        case "zh": return "\u{90A3}\u{5929}\u{65E9}\u{4E0A}\u{FF0C}\u{516C}\u{56ED}\u{5F88}\u{5B89}\u{9759}\u{3002}\u{6811}\u{6728}\u{5728}\u{98CE}\u{4E2D}\u{8F7B}\u{8F7B}\u{6447}\u{66F3}\u{FF0C}\u{9E1F}\u{513F}\u{5728}\u{679D}\u{5934}\u{4E4B}\u{95F4}\u{6B4C}\u{5531}\u{3002}"
        default: return frenchSample
        }
    }
}

#Preview {
    FirstPassageView(onboardingState: OnboardingState()) {}
}
