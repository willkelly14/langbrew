import SwiftUI

// MARK: - Hide Tab Bar Environment Key

/// Environment key to allow child views (e.g. ReaderView) to hide the tab bar.
private struct HideTabBarKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var hideTabBar: Binding<Bool> {
        get { self[HideTabBarKey.self] }
        set { self[HideTabBarKey.self] = newValue }
    }
}

// MARK: - Tab Definition

enum LBTab: String, CaseIterable, Identifiable, Sendable {
    case home = "Home"
    case library = "Library"
    case talk = "Talk"
    case flashcards = "Flashcards"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - Custom Tab Bar

/// A custom bottom tab bar with 4 tabs: Home, Library, Talk, Flashcards.
/// Uses custom drawn icons matching the mockup's Feather/Lucide stroke style.
/// Background: linen, top border: 0.5px g100 line.
struct LBTabBar: View {
    @Binding var selectedTab: LBTab

    var body: some View {
        VStack(spacing: 0) {
            // Top border line
            Rectangle()
                .fill(Color.lbG100)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(LBTab.allCases) { tab in
                    tabItem(tab)
                }
            }
            .padding(.top, 15)
            .padding(.bottom, 35)
        }
        .background(Color.lbLinen)
    }

    private func tabItem(_ tab: LBTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                tabIcon(for: tab)
                    .frame(width: 22, height: 22)

                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? Color.lbBlack : Color.lbG400)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Tab Icons (matching mockup SVG paths)

    @ViewBuilder
    private func tabIcon(for tab: LBTab) -> some View {
        let color = selectedTab == tab ? Color.lbBlack : Color.lbG400
        switch tab {
        case .home:
            HomeTabIcon()
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        case .library:
            BookTabIcon()
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        case .talk:
            ChatTabIcon()
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        case .flashcards:
            CardsTabIcon()
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Custom Icon Shapes (from mockup SVG paths)

/// Home icon: M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z
private struct HomeTabIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24.0
        var path = Path()
        // Roof: M3 9 L12 2 L21 9
        path.move(to: CGPoint(x: 3 * s, y: 9 * s))
        path.addLine(to: CGPoint(x: 12 * s, y: 2 * s))
        path.addLine(to: CGPoint(x: 21 * s, y: 9 * s))
        // Walls: v11 with rounded bottom corners
        path.addLine(to: CGPoint(x: 21 * s, y: 18 * s))
        // Bottom-right corner (radius 2)
        path.addQuadCurve(
            to: CGPoint(x: 19 * s, y: 20 * s),
            control: CGPoint(x: 21 * s, y: 20 * s)
        )
        path.addLine(to: CGPoint(x: 5 * s, y: 20 * s))
        // Bottom-left corner (radius 2)
        path.addQuadCurve(
            to: CGPoint(x: 3 * s, y: 18 * s),
            control: CGPoint(x: 3 * s, y: 20 * s)
        )
        path.closeSubpath()
        return path
    }
}

/// Library/Book icon: open book shape
private struct BookTabIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24.0
        var path = Path()
        // Bottom shelf: M4 19.5 A2.5 2.5 0 0 1 6.5 17 H20
        path.move(to: CGPoint(x: 4 * s, y: 19.5 * s))
        path.addQuadCurve(
            to: CGPoint(x: 6.5 * s, y: 17 * s),
            control: CGPoint(x: 4 * s, y: 17 * s)
        )
        path.addLine(to: CGPoint(x: 20 * s, y: 17 * s))

        // Book body: M6.5 2 H20 V22 H6.5 A2.5 2.5 0 0 1 4 19.5 V4.5 A2.5 2.5 0 0 1 6.5 2
        path.move(to: CGPoint(x: 6.5 * s, y: 2 * s))
        path.addLine(to: CGPoint(x: 20 * s, y: 2 * s))
        path.addLine(to: CGPoint(x: 20 * s, y: 22 * s))
        path.addLine(to: CGPoint(x: 6.5 * s, y: 22 * s))
        path.addQuadCurve(
            to: CGPoint(x: 4 * s, y: 19.5 * s),
            control: CGPoint(x: 4 * s, y: 22 * s)
        )
        path.addLine(to: CGPoint(x: 4 * s, y: 4.5 * s))
        path.addQuadCurve(
            to: CGPoint(x: 6.5 * s, y: 2 * s),
            control: CGPoint(x: 4 * s, y: 2 * s)
        )
        return path
    }
}

/// Talk/Chat icon: M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z
private struct ChatTabIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24.0
        var path = Path()
        // Start at top-right area
        path.move(to: CGPoint(x: 21 * s, y: 15 * s))
        // Top-right to bottom-right curve
        path.addQuadCurve(
            to: CGPoint(x: 19 * s, y: 17 * s),
            control: CGPoint(x: 21 * s, y: 17 * s)
        )
        // Bottom edge to tail
        path.addLine(to: CGPoint(x: 7 * s, y: 17 * s))
        // Tail going down-left
        path.addLine(to: CGPoint(x: 3 * s, y: 21 * s))
        // Up the left side
        path.addLine(to: CGPoint(x: 3 * s, y: 5 * s))
        // Top-left corner
        path.addQuadCurve(
            to: CGPoint(x: 5 * s, y: 3 * s),
            control: CGPoint(x: 3 * s, y: 3 * s)
        )
        // Top edge
        path.addLine(to: CGPoint(x: 19 * s, y: 3 * s))
        // Top-right corner
        path.addQuadCurve(
            to: CGPoint(x: 21 * s, y: 5 * s),
            control: CGPoint(x: 21 * s, y: 3 * s)
        )
        path.closeSubpath()
        return path
    }
}

/// Flashcards icon: two overlapping rounded rectangles
private struct CardsTabIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24.0
        var path = Path()
        // Back card: rect x=2 y=4 width=16 height=14 rx=2
        path.addRoundedRect(
            in: CGRect(x: 2 * s, y: 4 * s, width: 16 * s, height: 14 * s),
            cornerSize: CGSize(width: 2 * s, height: 2 * s)
        )
        // Front card: rect x=6 y=8 width=16 height=14 rx=2
        path.addRoundedRect(
            in: CGRect(x: 6 * s, y: 8 * s, width: 16 * s, height: 14 * s),
            cornerSize: CGSize(width: 2 * s, height: 2 * s)
        )
        return path
    }
}

#Preview {
    VStack {
        Spacer()
        LBTabBar(selectedTab: .constant(.home))
    }
    .background(Color.lbLinen)
}
