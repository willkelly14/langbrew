import SwiftUI

// MARK: - Tab Definition

enum LBTab: String, CaseIterable, Identifiable, Sendable {
    case home = "Home"
    case library = "Library"
    case talk = "Talk"
    case flashcards = "Flashcards"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house"
        case .library: "books.vertical"
        case .talk: "bubble.left.and.bubble.right"
        case .flashcards: "rectangle.on.rectangle"
        }
    }

    var label: String { rawValue }
}

// MARK: - Custom Tab Bar

/// A custom bottom tab bar with 4 tabs: Home, Library, Talk, Flashcards.
/// Matches the LangBrew warm design system.
struct LBTabBar: View {
    @Binding var selectedTab: LBTab

    var body: some View {
        HStack {
            ForEach(LBTab.allCases) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, LBTheme.Spacing.lg)
        .padding(.top, LBTheme.Spacing.sm)
        .padding(.bottom, LBTheme.Spacing.sm)
        .background(
            Color.lbWhite
                .lbShadow(LBTheme.Shadow.sheet)
        )
    }

    private func tabItem(_ tab: LBTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: LBTheme.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .symbolVariant(selectedTab == tab ? .fill : .none)

                Text(tab.label)
                    .font(LBTheme.Typography.small)
                    .textCase(.uppercase)
                    .kerning(0.5)
            }
            .foregroundStyle(selectedTab == tab ? Color.lbBlack : Color.lbG400)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        LBTabBar(selectedTab: .constant(.home))
    }
    .background(Color.lbLinen)
}
