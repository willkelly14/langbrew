import SwiftUI

// MARK: - Language Bank View

/// Screen 6: Saved vocabulary browser with Words, Phrases, and Sentences tabs.
/// Accessible from the Flashcards tab via NavigationLink.
struct LanguageBankView: View {
    @State private var viewModel = LanguageBankViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Navigation bar
                LanguageBankNavBar(
                    activeFlag: viewModel.activeFlag,
                    onBack: { dismiss() }
                )

                ScrollView {
                    VStack(spacing: 0) {
                        // 2. Content type tabs (Words / Phrases / Sentences)
                        LanguageBankTabPicker(selectedTab: $viewModel.selectedTab)

                        // 3. Stats row
                        LanguageBankStatsRow(stats: viewModel.stats)

                        // 4. Search bar
                        LanguageBankSearchBar(
                            searchText: $viewModel.searchText,
                            placeholder: viewModel.selectedTab.searchPlaceholder
                        )

                        // 5. Filter pills
                        LanguageBankFilterRow(selectedFilter: $viewModel.selectedFilter)

                        // 6. Word list
                        LanguageBankList(
                            items: viewModel.filteredItems,
                            onSelect: { item in
                                viewModel.selectedItem = item
                            }
                        )
                    }
                }
            }

            // Detail sheet overlay
            if viewModel.selectedItem != nil {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.selectedItem = nil
                    }
                    .transition(.opacity)

                VStack {
                    Spacer()
                    LanguageBankDetailSheet(
                        viewModel: viewModel,
                        onDismiss: { viewModel.selectedItem = nil }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedItem != nil)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.reloadForCurrentTab()
        }
        .onChange(of: viewModel.selectedTab) { _, _ in
            Task {
                await viewModel.reloadForCurrentTab()
            }
        }
        .onChange(of: viewModel.selectedFilter) { _, _ in
            Task {
                await viewModel.reloadForCurrentTab()
            }
        }
    }
}

// MARK: - Navigation Bar

/// Back button | Title "Language Bank" | Language flag button.
/// Matches mockup: padding 10px 24px, back button 32x32, title 15px 600 weight.
private struct LanguageBankNavBar: View {
    let activeFlag: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: LBTheme.Spacing.sm) {
            // Back button (32x32)
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.lbBlack)
                    .frame(width: 32, height: 32)
            }

            // Title
            Text("Language Bank")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.lbNearBlack)

            Spacer()

            // Language flag button
            Button {} label: {
                Text(activeFlag)
                    .font(.system(size: 22))
                    .frame(width: 36, height: 36)
                    .background(Color.lbG50)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
}

// MARK: - Tab Picker

/// Segmented control for Words / Phrases / Sentences.
/// Matches mockup: margin 8px 30px, bg lbG50, borderRadius 12, padding 3px.
/// Active tab: white bg, shadow (0 1px 3px rgba(0,0,0,0.08)), near-black, borderRadius 10.
/// Inactive: lbG500, no background.
private struct LanguageBankTabPicker: View {
    @Binding var selectedTab: LanguageBankTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LanguageBankTab.allCases) { tab in
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
                        .padding(.vertical, 9)
                        .background(
                            selectedTab == tab ? Color.lbWhite : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(
                            color: selectedTab == tab ? .black.opacity(0.08) : .clear,
                            radius: 1.5, y: 1
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        .padding(.horizontal, 30)
        .padding(.top, 8)
    }
}

// MARK: - Stats Row

/// 4-column grid showing Total, New, Known, Mastered counts.
/// Matches mockup: gap 8px, padding 12px 30px.
/// Each card: white bg, borderRadius 10, padding 10px, serif 24pt number, 11px label.
private struct LanguageBankStatsRow: View {
    let stats: LanguageBankStats

    var body: some View {
        HStack(spacing: 8) {
            LBStatCard(value: stats.total, label: "Total")
            LBStatCard(value: stats.new, label: "New")
            LBStatCard(value: stats.known, label: "Known")
            LBStatCard(value: stats.mastered, label: "Mastered")
        }
        .padding(.horizontal, 30)
        .padding(.top, 12)
    }
}

// MARK: - Search Bar

/// Search input with magnifying glass icon.
/// Matches mockup: margin 16px 30px, bg lbG50, borderRadius 12, padding 12px 16px.
/// Search icon 16px, 2px stroke. Placeholder 14px, lbG400.
private struct LanguageBankSearchBar: View {
    @Binding var searchText: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.lbG400)

            if searchText.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.lbG400)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        TextField("", text: $searchText)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbBlack)
                    }
            } else {
                TextField("", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.lbBlack)

                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbG400)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }
}

// MARK: - Filter Row

/// Horizontal scroll of filter pills: All, New, Known, Mastered.
/// Matches mockup: padding 14px 30px, gap 8px.
/// Inactive pill: bg lbG50, color lbG500, padding 4px 12px, borderRadius 10, font 13px.
/// Active pill: bg black, color white.
private struct LanguageBankFilterRow: View {
    @Binding var selectedFilter: VocabFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VocabFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 13))
                            .foregroundStyle(
                                selectedFilter == filter ? Color.lbWhite : Color.lbG500
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                selectedFilter == filter ? Color.lbBlack : Color.lbG50
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 30)
        }
        .padding(.top, 14)
    }
}

// MARK: - Word List

/// Vertical list of vocabulary items with word, translation, and status pill.
/// Matches mockup: padding 0 30px.
private struct LanguageBankList: View {
    let items: [LanguageBankItem]
    let onSelect: (LanguageBankItem) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                LanguageBankRow(
                    item: item,
                    isLast: index == items.count - 1,
                    onTap: { onSelect(item) }
                )
            }
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Word Row

/// A single row in the vocabulary list.
/// Matches mockup: padding 14px 0, border-bottom 0.5px lbG100, gap 12px.
/// Word: 16px 600 weight. Translation: 12px lbG500.
/// Status pill: 11px, padding 3px 10px, borderRadius 8.
private struct LanguageBankRow: View {
    let item: LanguageBankItem
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Word info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.lbBlack)
                        .lineLimit(1)

                    Text(item.translation)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG500)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Status pill
                Text(item.status.displayName.lowercased())
                    .font(.system(size: 11))
                    .foregroundStyle(Color.lbG500)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(item.status.pillBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle()
                        .fill(Color.lbG100)
                        .frame(height: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LanguageBankView()
    }
}

