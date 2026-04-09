import SwiftUI

// MARK: - Passages Grid View

/// Displays the passages in sections: Generate CTA, Search+Sort,
/// Recommended (featured card), In Progress (grid), Other Passages (grid).
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
            VStack(spacing: LBTheme.Spacing.xl) {
                // Generate CTA card
                GenerateCTACard {
                    viewModel.showGenerateSheet()
                }

                // Search bar + Sort button row
                SearchSortRow(query: $viewModel.searchQuery)

                // Recommended section
                if let featured = viewModel.recommendedPassage {
                    SectionHeader(title: "Recommended")
                    NavigationLink(value: featured) {
                        FeaturedPassageCard(passage: featured)
                    }
                    .buttonStyle(.plain)
                }

                // In Progress section
                if !viewModel.inProgressPassages.isEmpty {
                    SectionHeader(
                        title: "In Progress",
                        trailing: "\(viewModel.inProgressPassages.count) passages"
                    )
                    LazyVGrid(columns: columns, spacing: LBTheme.Spacing.md) {
                        ForEach(viewModel.inProgressPassages) { passage in
                            NavigationLink(value: passage) {
                                PassageCardView(passage: passage)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Other Passages section
                if !viewModel.otherPassages.isEmpty {
                    SectionHeader(
                        title: "Other Passages",
                        trailing: "See all \u{2192}"
                    )
                    LazyVGrid(columns: columns, spacing: LBTheme.Spacing.md) {
                        ForEach(viewModel.otherPassages) { passage in
                            NavigationLink(value: passage) {
                                PassageCardView(passage: passage)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Fallback: if search is active, show filtered results
                if !viewModel.searchQuery.isEmpty {
                    if viewModel.filteredPassages.isEmpty {
                        noResultsView
                    } else {
                        LazyVGrid(columns: columns, spacing: LBTheme.Spacing.md) {
                            ForEach(viewModel.filteredPassages) { passage in
                                NavigationLink(value: passage) {
                                    PassageCardView(passage: passage)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.top, LBTheme.Spacing.md)
            .padding(.bottom, 100)
        }
        .navigationDestination(for: PassageResponse.self) { passage in
            ReaderView(
                passage: passage,
                vocabulary: MockPassageData.sampleVocabulary.filter { $0.passageId == passage.id }
            )
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

// MARK: - Section Header

/// Section header with serif title and optional trailing link text.
private struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(LBTheme.Typography.title2)
                .foregroundStyle(Color.lbBlack)

            Spacer()

            if let trailing {
                Button {} label: {
                    Text(trailing)
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG500)
                }
            }
        }
    }
}

// MARK: - Search + Sort Row

/// Search bar (g50 bg) + Sort button (g50 bg, sort icon).
private struct SearchSortRow: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: LBTheme.Spacing.sm) {
            // Search bar
            HStack(spacing: LBTheme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.lbG400)

                TextField("Search passages...", text: $query)
                    .font(.system(size: 14))
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
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.vertical, LBTheme.Spacing.md)
            .background(Color.lbG50)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))

            // Sort button
            Button {} label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.lbG500)
                    .frame(width: 42, height: 42)
                    .background(Color.lbG50)
                    .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            }
        }
    }
}

// MARK: - Generate CTA Card

/// A prominent dark card prompting users to generate a new passage.
/// Left: icon box with plus. Right: title + subtitle.
private struct GenerateCTACard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LBTheme.Spacing.lg) {
                // Icon box
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate Passage")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white)

                    Text("AI creates a text matched to your level")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lbBlack)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Featured Passage Card

/// A large dark card for the recommended passage.
/// Shows: level badge, AI Pick badge, title, meta, excerpt.
private struct FeaturedPassageCard: View {
    let passage: PassageResponse

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            // Badges row
            HStack(spacing: LBTheme.Spacing.sm) {
                // CEFR badge
                Text(passage.cefrLevel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // AI Pick badge
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("AI Pick")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()
            }

            // Title
            Text(passage.title)
                .font(LBTheme.Typography.title2)
                .foregroundStyle(Color.white)

            // Meta
            Text("\(passage.newWordCountLabel) \u{00B7} \(passage.knownPercentageLabel) \u{00B7} \(passage.readingTimeLabel)")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))

            // Excerpt
            Text(passage.excerpt)
                .font(LBTheme.serifFont(size: 13))
                .italic()
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbBlack)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
