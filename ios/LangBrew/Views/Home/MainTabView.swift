import SwiftUI

/// Main app shell with the 4-tab navigation bar.
/// Each tab shows a placeholder view for now.
struct MainTabView: View {
    @State private var selectedTab: LBTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomePlaceholderView()
                case .library:
                    PlaceholderTabView(title: "Library", icon: "books.vertical", subtitle: "Your passages and books will appear here.")
                case .talk:
                    PlaceholderTabView(title: "Talk", icon: "bubble.left.and.bubble.right", subtitle: "AI conversation partners coming soon.")
                case .flashcards:
                    PlaceholderTabView(title: "Flashcards", icon: "rectangle.on.rectangle", subtitle: "Spaced repetition review sessions coming soon.")
                }
            }

            LBTabBar(selectedTab: $selectedTab)
        }
    }
}

// MARK: - Home Placeholder

private struct HomePlaceholderView: View {
    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.xl) {
                    // Greeting
                    HStack {
                        VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                            Text("Good morning")
                                .font(LBTheme.Typography.title)
                                .foregroundStyle(Color.lbBlack)

                            Text("Welcome to LangBrew")
                                .font(LBTheme.Typography.body)
                                .foregroundStyle(Color.lbG500)
                        }

                        Spacer()

                        LBAvatarCircle(name: "User", size: 40, showBorder: true)
                    }

                    // Streak preview
                    LBCard {
                        VStack(spacing: LBTheme.Spacing.md) {
                            HStack(spacing: LBTheme.Spacing.sm) {
                                Text("0 day streak")
                                    .font(LBTheme.Typography.bodyMedium)
                                    .foregroundStyle(Color.lbBlack)
                            }

                            LBStreakDots(days: [false, false, false, false, false, false, false])
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Placeholder content
                    LBEmptyState(
                        icon: "book",
                        title: "Ready to start",
                        subtitle: "Your personalized passages and learning content will appear here once you begin reading.",
                        buttonTitle: nil
                    )
                }
                .padding(.horizontal, LBTheme.Spacing.lg)
                .padding(.top, LBTheme.Spacing.lg)
                .padding(.bottom, 100)
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
            .padding(.bottom, 80)
        }
    }
}

#Preview {
    MainTabView()
}
