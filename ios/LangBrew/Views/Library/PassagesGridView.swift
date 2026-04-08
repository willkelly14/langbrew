import SwiftUI

// MARK: - Passages Grid View

/// Displays the passages grid with search, filter pills, sort options,
/// and a generate CTA card. Handles both empty and populated states.
struct PassagesGridView: View {
    @Bindable var viewModel: LibraryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: LBTheme.Spacing.md),
        GridItem(.flexible(), spacing: LBTheme.Spacing.md),
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingState
            } else if viewModel.hasNoPassages {
                emptyState
            } else {
                populatedState
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()

            LBEmptyState(
                icon: "text.book.closed",
                title: "No passages yet",
                subtitle: "Generate your first passage to start reading and learning new vocabulary.",
                buttonTitle: "Generate a Passage"
            ) {
                viewModel.showGenerateSheet()
            }

            Spacer()
            Spacer()
        }
        .padding(.bottom, 80)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        ScrollView {
            VStack(spacing: LBTheme.Spacing.lg) {
                LBCardSkeleton()
                LazyVGrid(columns: columns, spacing: LBTheme.Spacing.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        LBCardSkeleton()
                    }
                }
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.top, LBTheme.Spacing.lg)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Populated State

    private var populatedState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: LBTheme.Spacing.lg) {
                // Search bar
                SearchBar(query: $viewModel.searchQuery)

                // Filter pills
                FilterPills(
                    selectedLevel: $viewModel.selectedLevel,
                    sortOption: $viewModel.sortOption
                )

                // Generate CTA card
                GenerateCTACard {
                    viewModel.showGenerateSheet()
                }

                // Passages grid
                if viewModel.filteredPassages.isEmpty {
                    noResultsView
                } else {
                    LazyVGrid(columns: columns, spacing: LBTheme.Spacing.md) {
                        ForEach(viewModel.filteredPassages) { passage in
                            NavigationLink(value: passage.id) {
                                PassageCardView(passage: passage)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.top, LBTheme.Spacing.md)
            .padding(.bottom, 100)
        }
        .navigationDestination(for: String.self) { passageId in
            ReaderPlaceholderView(passageId: passageId)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: LBTheme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.lbG300)
                .padding(.top, LBTheme.Spacing.xxl)

            Text("No passages found")
                .font(LBTheme.Typography.bodyMedium)
                .foregroundStyle(Color.lbG500)

            Text("Try adjusting your search or filters.")
                .font(LBTheme.Typography.caption)
                .foregroundStyle(Color.lbG400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LBTheme.Spacing.xxxl)
    }
}

// MARK: - Search Bar

/// A styled search input for filtering passages by title, content, or topic.
private struct SearchBar: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: LBTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Color.lbG400)

            TextField("Search passages...", text: $query)
                .font(LBTheme.Typography.body)
                .foregroundStyle(Color.lbBlack)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.lbG300)
                }
            }
        }
        .padding(.horizontal, LBTheme.Spacing.md)
        .padding(.vertical, LBTheme.Spacing.md)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                .strokeBorder(Color.lbG100, lineWidth: 1)
        }
    }
}

// MARK: - Filter Pills

/// Horizontal scrolling filter pills for CEFR levels and sort options.
private struct FilterPills: View {
    @Binding var selectedLevel: CEFRLevel?
    @Binding var sortOption: PassageSortOption

    var body: some View {
        VStack(spacing: LBTheme.Spacing.sm) {
            // Level filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LBTheme.Spacing.sm) {
                    // "All" pill
                    FilterPillButton(
                        title: "All",
                        isSelected: selectedLevel == nil
                    ) {
                        selectedLevel = nil
                    }

                    // CEFR level pills
                    ForEach(CEFRLevel.allCases) { level in
                        FilterPillButton(
                            title: level.rawValue,
                            isSelected: selectedLevel == level
                        ) {
                            if selectedLevel == level {
                                selectedLevel = nil
                            } else {
                                selectedLevel = level
                            }
                        }
                    }

                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, LBTheme.Spacing.xs)

                    // Sort pills
                    ForEach(PassageSortOption.allCases) { option in
                        FilterPillButton(
                            title: option.rawValue,
                            icon: sortIcon(for: option),
                            isSelected: sortOption == option
                        ) {
                            sortOption = option
                        }
                    }
                }
            }
        }
    }

    private func sortIcon(for option: PassageSortOption) -> String? {
        switch option {
        case .date: "calendar"
        case .difficulty: "chart.bar"
        case .topic: "tag"
        }
    }
}

/// An individual filter pill button.
private struct FilterPillButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: LBTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(LBTheme.Typography.caption)
            }
            .padding(.horizontal, LBTheme.Spacing.md)
            .padding(.vertical, LBTheme.Spacing.sm)
            .background(isSelected ? Color.lbBlack : Color.clear)
            .foregroundStyle(isSelected ? Color.lbWhite : Color.lbBlack)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(Color.lbG200, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Generate CTA Card

/// A prominent dark card prompting users to generate a new passage.
/// Placed at the top of the passages grid.
private struct GenerateCTACard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LBTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                    Text("Generate a Passage")
                        .font(LBTheme.Typography.title2)
                        .foregroundStyle(Color.lbWhite)

                    Text("Create unlimited stories from any topic.")
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG300)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.lbG300)
            }
            .padding(LBTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lbBlack)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .lbShadow(LBTheme.Shadow.elevated)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Populated") {
    NavigationStack {
        PassagesGridView(viewModel: {
            let vm = LibraryViewModel()
            return vm
        }())
    }
}
