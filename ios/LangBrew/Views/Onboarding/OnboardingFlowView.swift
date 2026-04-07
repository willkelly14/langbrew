import SwiftUI

/// Manages the NavigationStack path for the entire onboarding flow.
/// Routes: S1 -> O1 -> C0-C5 -> O2 -> O3 -> O4 -> O5 -> O6 -> O6b -> O7 -> Home
struct OnboardingFlowView: View {
    let onboardingState: OnboardingState
    let authManager: AuthManager
    let coordinator: AppCoordinator

    @State private var path: [OnboardingStep] = []
    @State private var showSplash = true

    var body: some View {
        if showSplash {
            SplashView {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        } else {
            NavigationStack(path: $path) {
                WelcomeView(
                    onGetStarted: { path.append(.carousel) },
                    onSignIn: { path.append(.login) }
                )
                .navigationBarBackButtonHidden()
                .navigationDestination(for: OnboardingStep.self) { step in
                    destinationView(for: step)
                        .navigationBarBackButtonHidden()
                }
            }
            .onAppear {
                resumeIfNeeded()
            }
        }
    }

    // MARK: - Onboarding Resume

    /// If the user has a saved onboarding step beyond the welcome screen,
    /// rebuild the navigation path so they resume where they left off.
    private func resumeIfNeeded() {
        guard onboardingState.currentStep.rawValue > OnboardingStep.welcome.rawValue else {
            return
        }

        // Build the path from the start up to (and including) the saved step.
        var resumePath: [OnboardingStep] = []
        let targetRaw = onboardingState.currentStep.rawValue

        // Walk through the ordered steps, adding each to the path.
        let orderedSteps: [OnboardingStep] = [
            .carousel, .languageSelection, .proficiency, .interests,
            .dailyGoal, .accountSetup, .choosePlan, .firstPassage
        ]

        for step in orderedSteps {
            resumePath.append(step)
            if step.rawValue >= targetRaw {
                break
            }
        }

        path = resumePath
    }

    @ViewBuilder
    private func destinationView(for step: OnboardingStep) -> some View {
        switch step {
        case .carousel:
            CarouselView(
                onComplete: { path.append(.languageSelection) },
                onSkip: { path.append(.languageSelection) }
            )
        case .languageSelection:
            LanguageSelectionView(onboardingState: onboardingState) {
                path.append(.proficiency)
            }
        case .proficiency:
            ProficiencyView(onboardingState: onboardingState) {
                path.append(.interests)
            }
        case .interests:
            InterestsView(onboardingState: onboardingState) {
                path.append(.dailyGoal)
            }
        case .dailyGoal:
            DailyGoalView(onboardingState: onboardingState) {
                path.append(.accountSetup)
            }
        case .accountSetup:
            AccountSetupView(authManager: authManager, coordinator: coordinator) {
                path.append(.choosePlan)
            }
        case .choosePlan:
            ChoosePlanView(onboardingState: onboardingState) {
                path.append(.firstPassage)
            }
        case .firstPassage:
            FirstPassageView(onboardingState: onboardingState) {
                coordinator.transitionToMain()
            }
        case .login:
            LoginView(authManager: authManager) {
                // Returning user: check backend and transition.
                Task {
                    await coordinator.handlePostAuthentication()
                    if coordinator.phase != .main {
                        // Backend didn't confirm onboarding complete.
                        // Fall back to local complete.
                        onboardingState.completeOnboarding()
                        coordinator.transitionToMain()
                    }
                }
            }
        default:
            EmptyView()
        }
    }
}
