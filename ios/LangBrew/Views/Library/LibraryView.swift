import SwiftUI

// MARK: - Library Sub-Tab

/// The two sections within the Library tab.
enum LibrarySubTab: String, CaseIterable, Identifiable, Sendable {
    case passages = "Passages"
    case myBooks = "My Books"

    var id: String { rawValue }
}

// MARK: - Library View

/// Main Library tab view with sub-tabs for Passages and My Books.
/// Wraps content in a NavigationStack for drill-down to the Reader.
struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    @State private var selectedSubTab: LibrarySubTab = .passages

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lbLinen
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    LibraryHeader(selectedSubTab: $selectedSubTab, activeFlag: viewModel.activeFlag)

                    // Content
                    switch selectedSubTab {
                    case .passages:
                        PassagesGridView(viewModel: viewModel)
                    case .myBooks:
                        MyBooksPlaceholderView()
                    }
                }

                // Generation loading overlay
                if viewModel.isGenerating {
                    PassageLoadingView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isGenerating)
            .task {
                if viewModel.passages.isEmpty {
                    await viewModel.loadPassages()
                }
            }
        }
    }
}

// MARK: - Library Header

/// Top section of the Library with title, language switcher, and segmented control.
private struct LibraryHeader: View {
    @Binding var selectedSubTab: LibrarySubTab
    var activeFlag: String

    var body: some View {
        VStack(spacing: LBTheme.Spacing.lg) {
            // Title row
            HStack {
                Text("Library")
                    .font(LBTheme.Typography.largeTitle)
                    .foregroundStyle(Color.lbBlack)

                Spacer()

                // Language switcher (flag emoji circle)
                Button {} label: {
                    Text(activeFlag)
                        .font(.system(size: 24))
                        .frame(width: 36, height: 36)
                        .background(Color.lbG50)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.top, LBTheme.Spacing.md)

            // Segmented control
            SegmentedControl(selectedTab: $selectedSubTab)
                .padding(.horizontal, LBTheme.Spacing.lg)
        }
    }
}

// MARK: - Segmented Control

/// Mockup-style segmented control: g50 bg, rounded 12px, padding 3px.
/// Active tab: white bg, near-black text, shadow. Inactive: g500 text.
private struct SegmentedControl: View {
    @Binding var selectedTab: LibrarySubTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LibrarySubTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            selectedTab == tab ? Color.lbNearBlack : Color.lbG500
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab ? Color.lbWhite : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(
                            color: selectedTab == tab ? .black.opacity(0.08) : .clear,
                            radius: 2, y: 1
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
    }
}

// MARK: - My Books Placeholder

/// Placeholder view for the My Books tab, which will be built in a future milestone.
private struct MyBooksPlaceholderView: View {
    var body: some View {
        VStack {
            Spacer()

            LBEmptyState(
                icon: "book.closed",
                title: "My Books",
                subtitle: "Book imports are coming in a future update. Stay tuned!"
            )

            Spacer()
            Spacer()
        }
        .padding(.bottom, 80)
    }
}

#Preview {
    LibraryView(viewModel: LibraryViewModel())
}
