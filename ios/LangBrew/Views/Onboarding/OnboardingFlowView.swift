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
    ///
    /// The 4 setup steps (language, proficiency, interests, daily goal) now
    /// live in a single `OnboardingSetupView` container. The nav path only
    /// needs `.languageSelection` as entry point; the container reads
    /// `onboardingState.currentStep` to restore the correct sub-step.
    private func resumeIfNeeded() {
        guard onboardingState.currentStep.rawValue > OnboardingStep.welcome.rawValue else {
            return
        }

        var resumePath: [OnboardingStep] = []
        let saved = onboardingState.currentStep

        // The ordered navigation destinations (collapsed setup steps).
        // .languageSelection is the single entry for all 5 setup sub-steps.
        let navSteps: [OnboardingStep] = [
            .carousel, .languageSelection, .choosePlan, .firstPassage
        ]

        // Map saved sub-steps to the container entry point for comparison.
        let setupSteps: Set<OnboardingStep> = [
            .languageSelection, .proficiency, .interests, .dailyGoal, .accountSetup
        ]
        let effectiveSaved: OnboardingStep = setupSteps.contains(saved) ? .languageSelection : saved

        for step in navSteps {
            resumePath.append(step)
            if step == effectiveSaved {
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
        case .languageSelection, .proficiency, .interests, .dailyGoal, .accountSetup:
            // All 5 setup steps live in a single sliding container.
            // The container reads onboardingState.currentStep to determine
            // which sub-step to show, so resume-on-restart works.
            OnboardingSetupView(
                onboardingState: onboardingState,
                authManager: authManager,
                coordinator: coordinator
            ) {
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
