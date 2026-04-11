import SwiftUI

/// Main app shell with the 4-tab navigation bar.
/// Home tab uses a NavigationStack for push navigation to Settings.
/// Other tabs remain as placeholders for now.
struct MainTabView: View {
    let coordinator: AppCoordinator
    @State private var selectedTab: LBTab = .home
    @State private var hideTabBar: Bool = false
    @State private var libraryViewModel = LibraryViewModel()
    @State private var flashcardViewModel = FlashcardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        HomeView(coordinator: coordinator, selectedTab: $selectedTab)
                    }
                case .library:
                    LibraryView(viewModel: libraryViewModel)
                case .talk:
                    PlaceholderTabView(title: "Talk", icon: "bubble.left.and.bubble.right", subtitle: "AI conversation partners coming soon.")
                case .flashcards:
                    NavigationStack {
                        FlashcardHubView(viewModel: flashcardViewModel)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Tab bar pinned to bottom (hidden when reader is active)
            if !hideTabBar {
                LBTabBar(selectedTab: $selectedTab)
            }
        }
        .overlay {
            if libraryViewModel.isGenerateSheetPresented {
                ZStack(alignment: .bottom) {
                    // Scrim
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            libraryViewModel.isGenerateSheetPresented = false
                        }
                        .transition(.opacity)

                    // Sheet content — extra bottom padding to account for
                    // MainTabView's .edgesIgnoringSafeArea(.bottom) removing
                    // the safe area that LBBottomSheet normally relies on.
                    GeneratePassageSheet(
                        viewModel: libraryViewModel,
                        onDismiss: { libraryViewModel.isGenerateSheetPresented = false }
                    )
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: libraryViewModel.isGenerateSheetPresented)
        .environment(\.hideTabBar, $hideTabBar)
        .ignoresSafeArea(.keyboard)
        .edgesIgnoringSafeArea(.bottom)
        .task {
            // Populate the library and flashcard flags from the coordinator's
            // cached user, falling back to onboarding UserDefaults.
            if let lang = coordinator.currentUser?.activeLanguage {
                let flag = FlagMapper.flag(for: lang.targetLanguage)
                libraryViewModel.activeFlag = flag
                flashcardViewModel.activeFlag = flag
            } else if let code = coordinator.onboardingState.selectedLanguage {
                let flag = FlagMapper.flag(for: code)
                libraryViewModel.activeFlag = flag
                flashcardViewModel.activeFlag = flag
            }
        }
        .onChange(of: coordinator.currentUser?.activeLanguage?.targetLanguage) { _, newLang in
            if let lang = newLang {
                let flag = FlagMapper.flag(for: lang)
                libraryViewModel.activeFlag = flag
                flashcardViewModel.activeFlag = flag
            }
        }
    }
}

// MARK: - Generic Placeholder Tab

private struct PlaceholderTabView: View {
    let title: String
    let icon: String
    let subtitle: String

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack {
                Spacer()

                LBEmptyState(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    buttonTitle: nil
                )

                Spacer()
                Spacer()
            }
        }
    }
}

#Preview {
    MainTabView(coordinator: AppCoordinator())
}
