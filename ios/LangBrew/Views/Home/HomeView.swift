import SwiftUI

// MARK: - Home View

/// The main home/dashboard screen showing streak, quick actions,
/// content states, and word progress. Fetches data from `GET /v1/home`.
struct HomeView: View {
    let coordinator: AppCoordinator
    @State private var viewModel: HomeViewModel
    @State private var showComingSoonAlert = false
    @State private var comingSoonFeature = ""

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self._viewModel = State(initialValue: HomeViewModel(coordinator: coordinator))
    }

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.xl) {
                    headerRow
                    streakRow
                    quickActionButtons
                    todaysPassageCard
                    currentlyReadingCard

                    if !viewModel.recentBooks.isEmpty {
                        recentBooksSection
                    }

                    wordProgressSection
                }
                .padding(.horizontal, LBTheme.Spacing.lg)
                .padding(.top, LBTheme.Spacing.lg)
                .padding(.bottom, 100)
            }
            .refreshable {
                await viewModel.loadHome()
            }
        }
        .overlay {
            if viewModel.showLanguagePicker {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.showLanguagePicker = false
                        }
                        .transition(.opacity)

                    LanguagePickerOverlay(
                        viewModel: viewModel,
                        onDismiss: { viewModel.showLanguagePicker = false }
                    )
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showLanguagePicker)
        .alert("Coming Soon", isPresented: $showComingSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(comingSoonFeature) is coming in a future update.")
        }
        .task {
            await viewModel.loadHome()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                    // App tag: logo + "langbrew" wordmark above greeting
                    HStack(spacing: 6) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text("langbrew")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.lbG500)
                    }

                    Text("\(viewModel.greetingText), \(viewModel.userName)")
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                }

                Spacer()

                HStack(spacing: LBTheme.Spacing.sm) {
                    // Language flag in circular container
                    Button {
                        viewModel.showLanguagePicker = true
                    } label: {
                        Text(viewModel.activeFlag)
                            .font(.system(size: 20))
                            .frame(width: 40, height: 40)
                            .background(Color.lbG50)
                            .clipShape(Circle())
                    }

                    // Profile avatar -> navigates to Settings
                    NavigationLink(destination: SettingsView(coordinator: coordinator)) {
                        LBAvatarCircle(
                            imageURL: viewModel.avatarUrl.flatMap { URL(string: $0) },
                            name: viewModel.userName,
                            size: 40,
                            style: .dark,
                            initialsFontSize: 16
                        )
                    }
                }
            }
        }
    }

    // MARK: - Streak Row (no card wrapper)

    private var streakRow: some View {
        HStack(spacing: LBTheme.Spacing.sm) {
            // Streak text
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 13))
                Text("\(viewModel.currentStreak) day streak")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lbG500)
            }

            Spacer()

            // 7 small dots, no day labels
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(viewModel.streakWeek[index] ? Color.lbBlack : Color.lbG200)
                        .frame(width: 10, height: 10)
                }
            }
        }
    }

    // MARK: - Quick Action Buttons

    private var quickActionButtons: some View {
        HStack(spacing: LBTheme.Spacing.md) {
            // Talk button
            Button {
                comingSoonFeature = "Chat with Mia"
                showComingSoonAlert = true
            } label: {
                quickActionContent(
                    icon: "bubble.left.and.bubble.right",
                    title: "Talk",
                    subtitle: "Chat with Mia"
                )
            }
            .buttonStyle(.plain)

            // Flashcards button
            Button {
                comingSoonFeature = "Flashcard review"
                showComingSoonAlert = true
            } label: {
                quickActionContent(
                    icon: "rectangle.on.rectangle",
                    title: "Flashcards",
                    subtitle: "\(viewModel.cardsDue) cards due"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func quickActionContent(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: LBTheme.Spacing.md) {
            // Icon in rounded square container
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.lbNearBlack)
                .frame(width: 34, height: 34)
                .background(Color.lbG200)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lbNearBlack)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.lbG400)
            }

            Spacer(minLength: 0)
        }
        .padding(LBTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
    }

    // MARK: - Today's Passage Card (dark)

    private var todaysPassageCard: some View {
        LBCard(style: .dark, padding: 0) {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
                // Eyebrow
                Text("TODAY'S PASSAGE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .kerning(0.44)

                // Title
                Text("Generate your first passage")
                    .font(LBTheme.serifFont(size: 20))
                    .foregroundStyle(Color.white)

                // Subtitle
                Text("Tap to create a reading passage tailored to your level")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Currently Reading Card (white)

    private var currentlyReadingCard: some View {
        LBCard(padding: LBTheme.Spacing.md) {
            HStack(spacing: LBTheme.Spacing.md) {
                // Placeholder book thumbnail
                RoundedRectangle(cornerRadius: LBTheme.Radius.small)
                    .fill(Color.lbG100)
                    .frame(width: 56, height: 80)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.lbG300)
                    }

                VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                    // Eyebrow
                    Text("CURRENTLY READING")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.lbG400)
                        .kerning(0.44)

                    // Title
                    Text("Import your first book")
                        .font(LBTheme.serifFont(size: 17))
                        .foregroundStyle(Color.lbBlack)

                    // Subtitle
                    Text("Add an ebook to start reading")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG500)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Recent Books Section

    private var recentBooksSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            HStack {
                Text("Recent")
                    .font(LBTheme.Typography.bodyMedium)
                    .foregroundStyle(Color.lbBlack)
                Spacer()
                Text("See all \u{2192}")
                    .font(LBTheme.Typography.caption)
                    .foregroundStyle(Color.lbG400)
            }

            // Placeholder for future book cards
            Text("No recent books")
                .font(LBTheme.Typography.body)
                .foregroundStyle(Color.lbG500)
        }
    }

    // MARK: - Word Progress Section

    private var wordProgressSection: some View {
        VStack(spacing: LBTheme.Spacing.sm) {
            HStack {
                Text("Word Progress")
                    .font(LBTheme.Typography.title2)
                    .foregroundStyle(Color.lbBlack)
                Spacer()
            }

            HStack(spacing: LBTheme.Spacing.md) {
                LBStatCard(value: viewModel.wordStatsTotal, label: "Words")
                LBStatCard(value: viewModel.wordStatsLearning, label: "Learning")
                LBStatCard(value: viewModel.wordStatsMastered, label: "Mastered")
            }

            // "View all stats" link
            Button {
                comingSoonFeature = "Word stats"
                showComingSoonAlert = true
            } label: {
                Text("View all stats \u{2192}")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lbG400)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, LBTheme.Spacing.xs)
        }
    }
}

// MARK: - Language Picker Overlay

/// A custom overlay sheet for switching the active language,
/// using the same `LBBottomSheet` pattern as `GeneratePassageSheet`.
struct LanguagePickerOverlay: View {
    let viewModel: HomeViewModel
    var onDismiss: (() -> Void)?
    @State private var showComingSoonAlert = false

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Choose Language")
                    .font(LBTheme.Typography.title2)
                    .foregroundStyle(Color.lbBlack)
                    .padding(.bottom, LBTheme.Spacing.lg)

                VStack(spacing: LBTheme.Spacing.xs) {
                    ForEach(viewModel.languages) { language in
                        let isActive = language.language == viewModel.activeLanguage

                        Button {
                            viewModel.switchLanguage(id: language.id)
                        } label: {
                            HStack(spacing: LBTheme.Spacing.md) {
                                // Flag
                                Text(language.flag)
                                    .font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(isActive ? Color.lbHighlight : Color.lbG50)
                                    .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))

                                // Names
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(FlagMapper.languageName(for: language.language))
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.lbBlack)

                                    Text(FlagMapper.nativeName(for: language.language))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.lbG400)
                                }

                                Spacer()

                                // CEFR badge
                                Text(language.cefrLevel)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.lbG500)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.lbG50)
                                    .clipShape(Capsule())

                                // Active indicator
                                if isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.lbBlack)
                                }
                            }
                            .padding(.horizontal, LBTheme.Spacing.md)
                            .padding(.vertical, LBTheme.Spacing.sm)
                            .background(isActive ? Color.lbHighlight.opacity(0.3) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Add Language button
                Button {
                    showComingSoonAlert = true
                } label: {
                    HStack(spacing: LBTheme.Spacing.md) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.lbG400)
                            .frame(width: 44, height: 44)
                            .background(Color.lbG50)
                            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))

                        Text("Add Language")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.lbG400)

                        Spacer()
                    }
                    .padding(.horizontal, LBTheme.Spacing.md)
                    .padding(.vertical, LBTheme.Spacing.sm)
                }
                .buttonStyle(.plain)
                .padding(.top, LBTheme.Spacing.sm)
            }
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Adding new languages will be available in a future update.")
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(coordinator: AppCoordinator())
    }
}
