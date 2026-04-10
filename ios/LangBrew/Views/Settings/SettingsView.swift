import SwiftUI

// MARK: - Settings View

/// Full settings screen with profile, language, learning, reading, talk,
/// flashcard, notification, subscription, support, and account sections.
/// Uses a ScrollView with custom section styling to match the mockup.
struct SettingsView: View {
    let coordinator: AppCoordinator
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self._viewModel = State(initialValue: SettingsViewModel(coordinator: coordinator))
    }

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHeader
                    settingsSectionLabel("LANGUAGES")
                    languagesSection
                    settingsSectionLabel("LEARNING")
                    learningSection
                    settingsSectionLabel("READING")
                    readingSection
                    settingsSectionLabel("TALK")
                    talkSection
                    settingsSectionLabel("FLASHCARDS")
                    flashcardsSection
                    settingsSectionLabel("NOTIFICATIONS")
                    notificationsSection
                    settingsSectionLabel("SUBSCRIPTION")
                    subscriptionSection
                    settingsSectionLabel("SUPPORT")
                    supportSection
                    settingsSectionLabel("ACCOUNT")
                    accountSection
                    footerView
                }
                .padding(.horizontal, LBTheme.Spacing.lg)
                .padding(.bottom, LBTheme.Spacing.xxxl)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadFromCoordinator()
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $viewModel.showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await viewModel.performSignOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .overlay {
            if viewModel.showDeleteAccountConfirmation {
                DeleteAccountOverlay(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showDeleteAccountConfirmation)
    }

    // MARK: - Section Label

    private func settingsSectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.lbG400)
                .kerning(1.5)
            Spacer()
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Profile Header (centered)

    private var profileHeader: some View {
        VStack(spacing: LBTheme.Spacing.sm) {
            LBAvatarCircle(
                imageURL: viewModel.avatarUrl.flatMap { URL(string: $0) },
                name: viewModel.userName,
                size: 72,
                style: .dark,
                initialsFontSize: 28
            )

            Text(viewModel.userName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.lbBlack)

            Text(viewModel.email)
                .font(.system(size: 13))
                .foregroundStyle(Color.lbG400)

            NavigationLink(destination: EditAccountView(viewModel: viewModel)) {
                Text("Edit Account")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lbBlack)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, LBTheme.Spacing.lg)
        .padding(.bottom, LBTheme.Spacing.xl)
    }

    // MARK: - Languages Section

    private var languagesSection: some View {
        SettingsSectionContainer {
            NavigationLink(destination: LanguageDetailView(viewModel: viewModel)) {
                SettingsRow {
                    HStack(spacing: LBTheme.Spacing.md) {
                        Text(viewModel.activeFlag)
                            .font(.system(size: 20))

                        Text(viewModel.activeLanguageName)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbNearBlack)

                        Spacer()

                        Text("\(viewModel.activeLanguageLevel) \u{00B7} Beginner")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.lbG400)

                        SettingsChevron()
                    }
                }
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Button {
                // Add language placeholder
            } label: {
                SettingsRow {
                    HStack(spacing: LBTheme.Spacing.md) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.lbG400)

                        Text("Add Language")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbNearBlack)

                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Learning Section

    private var learningSection: some View {
        SettingsSectionContainer {
            NavigationLink(destination: DailyGoalEditorView(viewModel: viewModel)) {
                SettingsRow {
                    HStack {
                        Text("Daily Goal")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbNearBlack)
                        Spacer()
                        Text("\(viewModel.dailyGoalMinutes) min")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.lbG400)
                        SettingsChevron()
                    }
                }
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsRow {
                HStack {
                    Text("New Words Per Day")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                    Spacer()
                    Stepper(
                        "\(viewModel.newWordsPerDay)",
                        value: $viewModel.newWordsPerDay,
                        in: 1...20
                    )
                    .labelsHidden()
                    .onChange(of: viewModel.newWordsPerDay) { _, newValue in
                        viewModel.updateNewWordsPerDay(newValue)
                    }

                    Text("\(viewModel.newWordsPerDay)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lbG400)
                        .frame(width: 24, alignment: .trailing)
                }
            }

            SettingsDivider()

            SettingsRow {
                Toggle(isOn: $viewModel.autoAdjustDifficulty) {
                    Text("Auto-adjust Difficulty")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                }
                .tint(Color.lbBlack)
                .onChange(of: viewModel.autoAdjustDifficulty) { _, newValue in
                    viewModel.updateAutoAdjustDifficulty(newValue)
                }
            }
        }
    }

    // MARK: - Reading Section

    private var readingSection: some View {
        SettingsSectionContainer {
            SettingsRow {
                Toggle(isOn: $viewModel.vocabularyHighlights) {
                    Text("Vocabulary Highlights")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                }
                .tint(Color.lbBlack)
                .onChange(of: viewModel.vocabularyHighlights) { _, newValue in
                    viewModel.updateVocabularyHighlights(newValue)
                }
            }

            SettingsDivider()

            SettingsRow {
                Toggle(isOn: $viewModel.autoPlayAudio) {
                    Text("Auto-play Audio")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                }
                .tint(Color.lbBlack)
                .onChange(of: viewModel.autoPlayAudio) { _, newValue in
                    viewModel.updateAutoPlayAudio(newValue)
                }
            }

            SettingsDivider()

            SettingsRow {
                Toggle(isOn: $viewModel.highlightFollowing) {
                    Text("Highlight Following")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                }
                .tint(Color.lbBlack)
                .onChange(of: viewModel.highlightFollowing) { _, newValue in
                    viewModel.updateHighlightFollowing(newValue)
                }
            }
        }
    }

    // MARK: - Talk Section

    private var talkSection: some View {
        SettingsSectionContainer {
            SettingsRow {
                HStack {
                    Text("Voice Style")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                    Spacer()
                    Text(viewModel.talkVoiceStyle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lbG400)
                    SettingsChevron()
                }
            }

            SettingsDivider()

            SettingsRow {
                HStack {
                    Text("Correction Style")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                    Spacer()
                    Text(viewModel.talkCorrectionStyle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lbG400)
                    SettingsChevron()
                }
            }
        }
    }

    // MARK: - Flashcards Section

    private var flashcardsSection: some View {
        SettingsSectionContainer {
            SettingsRow {
                HStack {
                    Text("Reviews per Session")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                    Spacer()
                    Text("\(viewModel.reviewsPerSession)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lbG400)
                    SettingsChevron()
                }
            }

            SettingsDivider()

            SettingsRow {
                Toggle(isOn: $viewModel.showExampleSentence) {
                    Text("Show Example Sentence")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                }
                .tint(Color.lbBlack)
                .onChange(of: viewModel.showExampleSentence) { _, newValue in
                    viewModel.updateShowExampleSentence(newValue)
                }
            }

            SettingsDivider()

            SettingsRow {
                Toggle(isOn: $viewModel.audioOnReveal) {
                    Text("Audio on Reveal")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                }
                .tint(Color.lbBlack)
                .onChange(of: viewModel.audioOnReveal) { _, newValue in
                    viewModel.updateAudioOnReveal(newValue)
                }
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        SettingsSectionContainer {
            SettingsRow {
                Toggle(isOn: $viewModel.notificationsEnabled) {
                    Text("Daily Reminder")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                }
                .tint(Color.lbBlack)
                .onChange(of: viewModel.notificationsEnabled) { _, newValue in
                    viewModel.updateNotificationsEnabled(newValue)
                }
            }

            if viewModel.notificationsEnabled {
                SettingsDivider()

                SettingsRow {
                    HStack {
                        Text("Reminder Time")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.lbNearBlack)
                        Spacer()
                        Text(viewModel.reminderTimeDisplay)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.lbG400)
                        SettingsChevron()
                    }
                }
            }
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        SettingsSectionContainer {
            SettingsRow {
                HStack {
                    Text("Plan")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lbNearBlack)
                    Spacer()
                    Text(viewModel.subscriptionDisplay)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lbG400)
                    SettingsChevron()
                }
            }
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        SettingsSectionContainer {
            ForEach(
                ["Help Center", "Send Feedback", "Privacy Policy", "Terms of Service"],
                id: \.self
            ) { item in
                if item != "Help Center" {
                    SettingsDivider()
                }

                Button {
                    // Placeholder
                } label: {
                    SettingsRow {
                        HStack {
                            Text(item)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.lbNearBlack)
                            Spacer()
                            SettingsChevron()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Account Section (danger)

    private var accountSection: some View {
        SettingsSectionContainer {
            Button {
                viewModel.showSignOutConfirmation = true
            } label: {
                SettingsRow {
                    HStack {
                        Text("Sign Out")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Button {
                viewModel.showDeleteAccount()
            } label: {
                SettingsRow {
                    HStack {
                        Text("Delete Account")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        Text("langbrew v1.0.0")
            .font(.system(size: 12))
            .foregroundStyle(Color.lbG300)
            .frame(maxWidth: .infinity)
            .padding(.top, LBTheme.Spacing.xl)
            .padding(.bottom, LBTheme.Spacing.lg)
    }
}

// MARK: - Settings Section Container

/// White rounded container for a group of settings rows.
private struct SettingsSectionContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
    }
}

// MARK: - Settings Row

/// A single row inside a settings section container.
private struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
    }
}

// MARK: - Settings Divider

/// A 1px separator between settings rows.
private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.lbG100)
            .frame(height: 1)
            .padding(.leading, 14)
    }
}

// MARK: - Settings Chevron

/// A ">" chevron indicator for navigable settings rows.
private struct SettingsChevron: View {
    var body: some View {
        Text("\u{203A}")
            .font(.system(size: 16))
            .foregroundStyle(Color.lbG300)
    }
}

// MARK: - Delete Account Overlay

/// Full-screen overlay with a centered confirmation dialog for account deletion.
/// Matches the app's overlay pattern (dimmed scrim + centered card).
private struct DeleteAccountOverlay: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        ZStack {
            // Scrim
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    if !viewModel.isDeletingAccount {
                        viewModel.dismissDeleteAccount()
                    }
                }
                .transition(.opacity)

            // Dialog card
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("Delete Account?")
                    .font(LBTheme.serifFont(size: 24))
                    .foregroundStyle(Color.lbBlack)
                    .padding(.bottom, 8)

                // Warning message
                Text("This action cannot be undone. All your data will be permanently deleted.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.lbG500)
                    .lineSpacing(4)
                    .padding(.bottom, 18)

                // Confirmation prompt
                Text("Type \(Text(viewModel.expectedConfirmation).bold()) to confirm:")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG400)
                    .padding(.bottom, 10)

                // Text field
                TextField(viewModel.expectedConfirmation, text: $viewModel.deleteAccountConfirmationText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.lbNearBlack)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Color.lbG50)
                    .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                    .overlay {
                        RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                            .strokeBorder(Color.lbG100, lineWidth: 1.5)
                    }
                    .padding(.bottom, 8)

                // Error message
                if let error = viewModel.deleteAccountError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }

                // Buttons
                HStack(spacing: LBTheme.Spacing.md) {
                    // Cancel
                    Button {
                        viewModel.dismissDeleteAccount()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.lbNearBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.lbG50)
                            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                            .overlay {
                                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                                    .strokeBorder(Color.lbG200, lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isDeletingAccount)

                    // Delete
                    Button {
                        Task {
                            await viewModel.performDeleteAccount()
                        }
                    } label: {
                        HStack(spacing: LBTheme.Spacing.sm) {
                            if viewModel.isDeletingAccount {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Delete")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            viewModel.canConfirmDeletion && !viewModel.isDeletingAccount
                                ? Color.red
                                : Color.red.opacity(0.4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canConfirmDeletion || viewModel.isDeletingAccount)
                }
                .padding(.top, 10)
            }
            .padding(24)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .lbShadow(LBTheme.Shadow.elevated)
            .padding(.horizontal, LBTheme.Spacing.xl)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(coordinator: AppCoordinator())
    }
}
