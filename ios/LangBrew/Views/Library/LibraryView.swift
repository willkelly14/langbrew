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
    @State private var viewModel = LibraryViewModel()
    @State private var selectedSubTab: LibrarySubTab = .passages

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lbLinen
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    LibraryHeader(selectedSubTab: $selectedSubTab)

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
            .sheet(isPresented: $viewModel.isGenerateSheetPresented) {
                GeneratePassageSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(Color.lbWhite)
            }
            .task {
                if viewModel.passages.isEmpty {
                    await viewModel.loadPassages()
                }
            }
        }
    }
}

// MARK: - Library Header

/// Top section of the Library with title and sub-tab selector.
private struct LibraryHeader: View {
    @Binding var selectedSubTab: LibrarySubTab

    var body: some View {
        VStack(spacing: LBTheme.Spacing.lg) {
            // Title
            HStack {
                Text("Library")
                    .font(LBTheme.Typography.title)
                    .foregroundStyle(Color.lbBlack)

                Spacer()
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.top, LBTheme.Spacing.md)

            // Sub-tabs
            HStack(spacing: 0) {
                ForEach(LibrarySubTab.allCases) { tab in
                    SubTabButton(
                        title: tab.rawValue,
                        isSelected: selectedSubTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSubTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
        }
    }
}

/// An individual sub-tab button with underline indicator.
private struct SubTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: LBTheme.Spacing.sm) {
                Text(title)
                    .font(LBTheme.Typography.bodyMedium)
                    .foregroundStyle(isSelected ? Color.lbBlack : Color.lbG400)

                Rectangle()
                    .fill(isSelected ? Color.lbBlack : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
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
    LibraryView()
}
