import SwiftUI

/// Main app shell with the 4-tab navigation bar.
/// Home tab uses a NavigationStack for push navigation to Settings.
/// Other tabs remain as placeholders for now.
struct MainTabView: View {
    let coordinator: AppCoordinator
    @State private var selectedTab: LBTab = .home
    @State private var hideTabBar: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        HomeView(coordinator: coordinator)
                    }
                case .library:
                    LibraryView()
                case .talk:
                    PlaceholderTabView(title: "Talk", icon: "bubble.left.and.bubble.right", subtitle: "AI conversation partners coming soon.")
                case .flashcards:
                    PlaceholderTabView(title: "Flashcards", icon: "rectangle.on.rectangle", subtitle: "Spaced repetition review sessions coming soon.")
                }
            }
            .frame(maxHeight: .infinity)

            // Tab bar pinned to bottom (hidden when reader is active)
            if !hideTabBar {
                LBTabBar(selectedTab: $selectedTab)
            }
        }
        .environment(\.hideTabBar, $hideTabBar)
        .ignoresSafeArea(.keyboard)
        .edgesIgnoringSafeArea(.bottom)
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
