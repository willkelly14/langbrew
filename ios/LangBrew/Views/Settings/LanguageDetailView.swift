import SwiftUI

// MARK: - Language Detail View

/// Shows language details: centered header with flag/name, proficiency display,
/// interest topic pills with emojis, 6 stat cards, and danger zone actions.
struct LanguageDetailView: View {
    let viewModel: SettingsViewModel

    /// Maps interest names to emoji prefixes for display.
    private static let interestEmojis: [String: String] = [
        "Food & Cooking": "🍽",
        "Sports": "⚽",
        "Travel": "✈️",
        "Music": "🎵",
        "Movies & TV": "🎬",
        "Technology": "💻",
        "Business": "💼",
        "Science": "🔬",
        "Art & Design": "🎨",
        "History": "🏛️",
        "Nature": "🌿",
        "Literature": "📚",
        "Fashion": "👜",
        "Health & Fitness": "🏋️",
        "Politics": "🏛️",
        "Gaming": "🎮",
        "Daily Life": "☕",
    ]

    /// Returns the CEFR level label.
    private var cefrLabel: String {
        switch viewModel.activeLanguageLevel {
        case "A1": return "Beginner"
        case "A2": return "Elementary"
        case "B1": return "Intermediate"
        case "B2": return "Upper Intermediate"
        case "C1": return "Advanced"
        default: return "Elementary"
        }
    }

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: LBTheme.Spacing.xl) {
                    languageHeader
                    proficiencySection
                    interestsSection
                    statsSection
                    dangerZoneSection
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.top, LBTheme.Spacing.lg)
                .padding(.bottom, LBTheme.Spacing.xxxl)
            }
        }
        .navigationTitle(viewModel.activeLanguageName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Language Header (centered)

    private var languageHeader: some View {
        VStack(spacing: LBTheme.Spacing.sm) {
            Text(viewModel.activeFlag)
                .font(.system(size: 56))

            Text(viewModel.activeLanguageName)
                .font(LBTheme.Typography.title)
                .foregroundStyle(Color.lbBlack)

            Text(FlagMapper.nativeName(for: viewModel.activeLanguage))
                .font(LBTheme.Typography.body)
                .foregroundStyle(Color.lbG500)

            Text("Learning since Jan 2026")
                .font(.system(size: 12))
                .foregroundStyle(Color.lbG300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LBTheme.Spacing.lg)
    }

    // MARK: - Proficiency Section (read-only display)

    private var proficiencySection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            sectionLabel("PROFICIENCY")

            VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
                // Level badge + label
                HStack(spacing: LBTheme.Spacing.md) {
                    LBPill(viewModel.activeLanguageLevel, variant: .filled)

                    Text(cefrLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lbNearBlack)
                }

                // Description
                Text("Based on your reading activity")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lbG400)

                // Recalibrate link
                Button {
                    // Recalibrate placeholder
                } label: {
                    HStack(spacing: LBTheme.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                        Text("Recalibrate")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.lbBlack)
                }
                .padding(.top, LBTheme.Spacing.xs)
            }
            .padding(LBTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        }
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            sectionLabel("INTERESTS")

            OnboardingFlowLayout(spacing: LBTheme.Spacing.sm) {
                ForEach(viewModel.activeLanguageInterests, id: \.self) { interest in
                    let emoji = Self.interestEmojis[interest] ?? ""
                    LBPill(
                        emoji.isEmpty ? interest : "\(emoji) \(interest)",
                        variant: .highlight
                    )
                }

                // Add pill
                Button {
                    // Add interest placeholder
                } label: {
                    HStack(spacing: LBTheme.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add")
                            .font(LBTheme.Typography.caption)
                    }
                    .padding(.horizontal, LBTheme.Spacing.md)
                    .padding(.vertical, LBTheme.Spacing.sm)
                    .foregroundStyle(Color.lbG400)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.lbG200, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                .buttonStyle(.plain)
            }

            if viewModel.activeLanguageInterests.isEmpty {
                Text("No interests selected")
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbG400)
            }
        }
    }

    // MARK: - Stats Section (6 cards in 2 rows of 3)

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            sectionLabel("STATS")

            // Row 1
            HStack(spacing: LBTheme.Spacing.md) {
                LBStatCard(value: 0, label: "Total Words")
                LBStatCard(value: 0, label: "Mastered")
                LBStatCard(value: 0, label: "Passages Read")
            }

            // Row 2
            HStack(spacing: LBTheme.Spacing.md) {
                LBStatCard(value: 0, label: "Conversations")
                LBStatCard(value: 0, label: "Cards Due")
                LBStatCard(value: "0h", label: "Time Spent")
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        VStack(spacing: 0) {
            Button {
                // Reset progress placeholder
            } label: {
                HStack {
                    Text("Reset Progress")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.lbG100)
                .frame(height: 1)
                .padding(.leading, 14)

            Button {
                // Remove language placeholder
            } label: {
                HStack {
                    Text("Remove Language")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
        .padding(.top, LBTheme.Spacing.sm)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.lbG400)
            .kerning(1.5)
    }
}

#Preview {
    NavigationStack {
        LanguageDetailView(viewModel: SettingsViewModel(coordinator: AppCoordinator()))
    }
}
