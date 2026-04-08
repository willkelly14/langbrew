import SwiftUI

/// Root view for the app. Routes to onboarding or the main tab view
/// based on authentication and onboarding completion state.
///
/// On launch, `AppCoordinator.checkInitialState()` fetches the user
/// profile from the backend and determines the correct phase.
struct ContentView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        Group {
            switch coordinator.phase {
            case .loading:
                launchLoadingView
            case .onboarding:
                OnboardingFlowView(
                    onboardingState: coordinator.onboardingState,
                    authManager: coordinator.authManager,
                    coordinator: coordinator
                )
            case .main:
                MainTabView(coordinator: coordinator)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.phase)
        .task {
            await coordinator.checkInitialState()
        }
    }

    /// A minimal loading screen shown while the initial state check runs.
    /// Matches the app's linen background to feel like a seamless splash.
    private var launchLoadingView: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            ProgressView()
                .tint(Color.lbBlack)
        }
    }
}

#Preview {
    ContentView()
}
