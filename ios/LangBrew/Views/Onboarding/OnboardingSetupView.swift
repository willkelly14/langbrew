import SwiftUI
import UIKit
import UserNotifications

/// O2-O6 -- Single container for the 5 setup steps (language, proficiency,
/// interests, daily goal, account). Content slides horizontally while the
/// progress bar, nav bar, and CTA button stay mounted outside the sliding
/// area so that progress animates smoothly instead of jumping between screens.
struct OnboardingSetupView: View {
    let onboardingState: OnboardingState
    let authManager: AuthManager
    let coordinator: AppCoordinator?
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    // Account setup state (step 4)
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showVerification = false
    @State private var showLogin = false

    private let totalSetupSteps = 5
    private var progress: Double {
        Double(currentStep + 1) / Double(totalSetupSteps)
    }

    /// Whether the Continue button should be enabled for the current step.
    private var canProceed: Bool {
        switch currentStep {
        case 0: onboardingState.selectedLanguage != nil
        case 1: onboardingState.selectedLevel != nil
        case 2: onboardingState.selectedInterests.count >= 3
        case 3: true // Daily goal always has a default
        case 4: true // Account setup has its own CTA
        default: false
        }
    }

    /// CTA label for the current step.
    private var ctaLabel: String {
        currentStep == 4 ? "Create Account" : "Continue"
    }

    // MARK: - Step metadata

    private var stepIndicator: String {
        switch currentStep {
        case 0: "Step 1 of 5"
        case 1:
            if let code = onboardingState.selectedLanguage {
                "Step 2 of 5 \u{00B7} \(FlagMapper.languageName(for: code))"
            } else {
                "Step 2 of 5"
            }
        case 2: "Step 3 of 5"
        case 3: "Step 4 of 5"
        case 4: "Step 5 of 5 \u{00B7} Almost done"
        default: ""
        }
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: "What do you want\nto read in?"
        case 1:
            if let code = onboardingState.selectedLanguage {
                "How much \(FlagMapper.languageName(for: code))\ndo you know?"
            } else {
                "How much do you know?"
            }
        case 2: "What do you like\nto read about?"
        case 3: "Set a daily goal."
        case 4: "Create your\naccount."
        default: ""
        }
    }

    private var stepSubtitle: String {
        switch currentStep {
        case 0: "Choose a language to get started."
        case 1: "Pick the level that feels closest."
        case 2: "We'll use these to personalize your passages."
        case 3: "A small habit beats a big plan."
        case 4: "Save your progress and sync across devices."
        default: ""
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar (outside sliding content)
                OnboardingNav(
                    showBack: true,
                    onBack: handleBack
                )

                // Progress bar (outside sliding content, animates smoothly)
                OnboardingProgress(progress: progress)
                    .animation(.easeInOut(duration: 0.35), value: progress)
                    .padding(.bottom, LBTheme.Spacing.xl)

                // Step header (outside sliding content)
                VStack(alignment: .leading, spacing: 0) {
                    Text(stepIndicator)
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG400)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.sm)
                        .id("indicator-\(currentStep)")

                    // Large flag for proficiency step
                    if currentStep == 1 {
                        Text(languageFlag)
                            .font(.system(size: 40))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, LBTheme.Spacing.xl)
                            .padding(.bottom, LBTheme.Spacing.sm)
                    }

                    Text(stepTitle)
                        .font(LBTheme.Typography.title)
                        .foregroundStyle(Color.lbBlack)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.xs)
                        .id("title-\(currentStep)")

                    Text(stepSubtitle)
                        .font(LBTheme.Typography.body)
                        .foregroundStyle(Color.lbG500)
                        .padding(.horizontal, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.lg)
                        .id("subtitle-\(currentStep)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Sliding content area
                TabView(selection: $currentStep) {
                    LanguageSelectionContent(onboardingState: onboardingState)
                        .tag(0)
                    ProficiencyContent(onboardingState: onboardingState)
                        .tag(1)
                    InterestsContent(onboardingState: onboardingState)
                        .tag(2)
                    DailyGoalContent(onboardingState: onboardingState)
                        .tag(3)
                    AccountSetupContent(
                        authManager: authManager,
                        name: $name,
                        email: $email,
                        password: $password,
                        errorMessage: $errorMessage,
                        isLoading: $isLoading,
                        onApple: { Task { await handleAppleSignIn() } },
                        onGoogle: { Task { await handleGoogleSignIn() } }
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Disable swipe navigation -- user must use Continue
                .disabled(false)
                .gesture(DragGesture())

                // Bottom section (outside sliding content)
                bottomSection
            }
        }
        .ignoresSafeArea(.keyboard)
        .overlay {
            // Verification flow overlays the whole container
            if showVerification {
                VerifyCodeView(
                    email: authManager.pendingEmail ?? email,
                    onVerify: { code in
                        try await handleCodeVerification(code: code)
                    },
                    onResend: {
                        await handleResendCode()
                    },
                    onBack: {
                        authManager.clearPendingConfirmation()
                        showVerification = false
                        errorMessage = nil
                    }
                )
                .background(Color.lbLinen)
            }

            // Login flow overlays the whole container
            if showLogin {
                LoginView(authManager: authManager) {
                    Task {
                        await coordinator?.handlePostAuthentication()
                        if coordinator?.phase != .main {
                            onComplete()
                        }
                    }
                }
                .background(Color.lbLinen)
            }
        }
        .onAppear {
            restoreStep()
        }
    }

    // MARK: - Bottom section

    @ViewBuilder
    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Interests counter
            if currentStep == 2 {
                Text("\(onboardingState.selectedInterests.count) selected \u{00B7} 3 minimum")
                    .font(LBTheme.Typography.caption)
                    .foregroundStyle(Color.lbG400)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LBTheme.Spacing.lg)
                    .transition(.opacity)
            }

            // Proficiency reassurance text
            if currentStep == 1 {
                Text("Don't worry \u{2014} we'll adjust as we learn what you know.")
                    .font(LBTheme.Typography.caption)
                    .foregroundStyle(Color.lbG400)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.vertical, LBTheme.Spacing.sm)
                    .padding(.horizontal, LBTheme.Spacing.xl)
                    .transition(.opacity)
            }

            // Account setup: terms + sign in link above CTA
            if currentStep == 4 {
                // Terms
                (Text("By continuing, you agree to langbrew's\n")
                    .font(.system(size: 12))
                    .foregroundColor(Color.lbG400)
                 + Text("Terms of Service")
                    .font(.system(size: 12))
                    .foregroundColor(Color.lbG400)
                 + Text(" and ")
                    .font(.system(size: 12))
                    .foregroundColor(Color.lbG400)
                 + Text("Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundColor(Color.lbG400)
                 + Text(".")
                    .font(.system(size: 12))
                    .foregroundColor(Color.lbG400))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
                .padding(.bottom, LBTheme.Spacing.xs)

                // Sign in link
                (Text("Already have an account? ")
                    .font(.system(size: 13))
                    .foregroundColor(Color.lbG400)
                 + Text("Sign in")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.lbNearBlack))
                .frame(maxWidth: .infinity)
                .padding(.bottom, LBTheme.Spacing.sm)
                .onTapGesture { showLogin = true }
            }

            // CTA button (same position for all steps)
            if currentStep == 4 {
                OnboardingCTA(ctaLabel, isLoading: isLoading) {
                    Task { await handleEmailSignUp() }
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.bottom, LBTheme.Spacing.md)
            } else {
                OnboardingCTA(ctaLabel, isEnabled: canProceed, action: handleContinue)
                    .padding(.horizontal, LBTheme.Spacing.xl)
                    .padding(.bottom, LBTheme.Spacing.md)
            }
        }
    }

    // MARK: - Helpers

    private var languageFlag: String {
        if let code = onboardingState.selectedLanguage {
            return FlagMapper.flag(for: code)
        }
        return "\u{1F310}"
    }

    // MARK: - Actions

    private func handleContinue() {
        if currentStep < totalSetupSteps - 1 {
            // Save progress and advance
            persistStep(currentStep + 1)
            withAnimation(.easeInOut(duration: 0.35)) {
                currentStep += 1
            }
        } else {
            // Last setup step: proceed to account setup
            persistStep(totalSetupSteps)
            onComplete()
        }
    }

    private func handleBack() {
        if currentStep > 0 {
            persistStep(currentStep - 1)
            withAnimation(.easeInOut(duration: 0.35)) {
                currentStep -= 1
            }
        } else {
            dismiss()
        }
    }

    /// Persist the setup sub-step so it can be restored on relaunch.
    private func persistStep(_ setupStep: Int) {
        switch setupStep {
        case 0: onboardingState.currentStep = .languageSelection
        case 1: onboardingState.currentStep = .proficiency
        case 2: onboardingState.currentStep = .interests
        case 3: onboardingState.currentStep = .dailyGoal
        case 4: onboardingState.currentStep = .accountSetup
        default: break
        }
    }

    /// Restore the sub-step from persisted state.
    private func restoreStep() {
        switch onboardingState.currentStep {
        case .proficiency: currentStep = 1
        case .interests: currentStep = 2
        case .dailyGoal: currentStep = 3
        case .accountSetup: currentStep = 4
        default: currentStep = 0
        }
    }

    // MARK: - Auth Actions

    private func handleAppleSignIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.signInWithApple()
            await postAuthFlow()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleGoogleSignIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.signInWithGoogle()
            await postAuthFlow()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleEmailSignUp() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your first name."
            return
        }
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter a password."
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authManager.signUpWithEmail(email: email, password: password)
            if authManager.pendingEmailConfirmation {
                isLoading = false
                showVerification = true
            } else {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                if !trimmedName.isEmpty {
                    _ = try? await UserService.shared.updateMe(UserUpdate(firstName: trimmedName))
                }
                await postAuthFlow()
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleCodeVerification(code: String) async throws {
        try await authManager.verifySignUpCode(
            email: authManager.pendingEmail ?? email,
            code: code
        )
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            _ = try? await UserService.shared.updateMe(UserUpdate(firstName: trimmedName))
        }
        await postAuthFlow()
    }

    private func handleResendCode() async {
        do {
            try await authManager.signUpWithEmail(email: email, password: password)
        } catch {
            // Silently fail
        }
    }

    private func postAuthFlow() async {
        if let coordinator {
            await coordinator.handlePostAuthentication()
            if coordinator.phase == .main {
                isLoading = false
                return
            }
        }
        await requestNotificationPermission()
        isLoading = false
        onComplete()
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            await UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

// MARK: - Step 0: Language Selection Content

/// Just the scrollable language card list, without nav/progress/header/CTA.
private struct LanguageSelectionContent: View {
    let onboardingState: OnboardingState

    private let languages: [(code: String, flag: String, name: String, native: String)] = [
        ("es", "\u{1F1EA}\u{1F1F8}", "Spanish", "Espa\u{00F1}ol"),
        ("fr", "\u{1F1EB}\u{1F1F7}", "French", "Fran\u{00E7}ais"),
        ("de", "\u{1F1E9}\u{1F1EA}", "German", "Deutsch"),
        ("it", "\u{1F1EE}\u{1F1F9}", "Italian", "Italiano"),
        ("pt", "\u{1F1E7}\u{1F1F7}", "Portuguese", "Portugu\u{00EA}s"),
        ("nl", "\u{1F1F3}\u{1F1F1}", "Dutch", "Nederlands"),
        ("ja", "\u{1F1EF}\u{1F1F5}", "Japanese", "\u{65E5}\u{672C}\u{8A9E}"),
        ("ko", "\u{1F1F0}\u{1F1F7}", "Korean", "\u{D55C}\u{AD6D}\u{C5B4}"),
        ("zh", "\u{1F1E8}\u{1F1F3}", "Chinese", "\u{4E2D}\u{6587}"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: LBTheme.Spacing.sm) {
                ForEach(languages, id: \.code) { lang in
                    LanguageCardRow(
                        flag: lang.flag,
                        name: lang.name,
                        native: lang.native,
                        isSelected: onboardingState.selectedLanguage == lang.code
                    ) {
                        onboardingState.selectedLanguage = lang.code
                    }
                }

                // "More languages" dimmed card
                LanguageCardRow(
                    flag: "\u{1F30D}",
                    name: "More languages",
                    native: "Coming soon",
                    isSelected: false,
                    isDimmed: true
                ) {}
            }
            .padding(.horizontal, LBTheme.Spacing.xl)
            .padding(.bottom, LBTheme.Spacing.md)
        }
    }
}

// MARK: - Step 1: Proficiency Content

/// Just the scrollable level card list, without nav/progress/header/CTA.
private struct ProficiencyContent: View {
    let onboardingState: OnboardingState

    private let levels: [(code: String, name: String, description: String)] = [
        ("A1", "Just starting out", "I know a few words and basic phrases."),
        ("A2", "I know the basics", "I can understand simple sentences about familiar topics."),
        ("B1", "Getting comfortable", "I can read straightforward texts about everyday things."),
        ("B2", "Fairly confident", "I can read articles and stories with some effort."),
        ("C1", "Advanced", "I can understand complex texts and express myself fluently."),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(levels, id: \.code) { level in
                    LevelCardRow(
                        code: level.code,
                        name: level.name,
                        description: level.description,
                        isSelected: onboardingState.selectedLevel == level.code
                    ) {
                        onboardingState.selectedLevel = level.code
                    }
                }
            }
            .padding(.horizontal, LBTheme.Spacing.xl)
        }
    }
}

// MARK: - Step 2: Interests Content

/// Just the scrollable interest pills, without nav/progress/header/CTA.
private struct InterestsContent: View {
    let onboardingState: OnboardingState

    private let groups: [(title: String, topics: [(emoji: String, name: String)])] = [
        ("Lifestyle", [
            ("\u{2708}\u{FE0F}", "Travel"),
            ("\u{1F373}", "Food & Cooking"),
            ("\u{2600}\u{FE0F}", "Daily Life"),
            ("\u{1F4AA}", "Health"),
            ("\u{1F457}", "Fashion"),
            ("\u{1F495}", "Relationships"),
            ("\u{1F3E1}", "Home & Garden"),
        ]),
        ("Knowledge", [
            ("\u{1F52C}", "Science"),
            ("\u{1F3DB}\u{FE0F}", "History"),
            ("\u{1F3A8}", "Design"),
            ("\u{1F4BB}", "Technology"),
            ("\u{1F4C8}", "Business"),
            ("\u{1F914}", "Philosophy"),
            ("\u{1F4F0}", "News"),
            ("\u{1F30D}", "Politics"),
        ]),
        ("Entertainment", [
            ("\u{1F4D6}", "Fiction"),
            ("\u{1F3AD}", "Culture"),
            ("\u{26BD}", "Sports"),
            ("\u{1F3B5}", "Music & Art"),
            ("\u{1F33F}", "Nature"),
            ("\u{1F602}", "Humor"),
            ("\u{1F3AE}", "Gaming"),
        ]),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.element.title) { index, group in
                    // Section label
                    Text(group.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.lbG400)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.top, index == 0 ? 0 : LBTheme.Spacing.lg)
                        .padding(.bottom, LBTheme.Spacing.sm)

                    // Topic pills
                    OnboardingFlowLayout(spacing: LBTheme.Spacing.sm) {
                        ForEach(group.topics, id: \.name) { topic in
                            InterestTopicPill(
                                emoji: topic.emoji,
                                name: topic.name,
                                isSelected: onboardingState.selectedInterests.contains(topic.name)
                            ) {
                                toggleTopic(topic.name)
                            }
                        }
                    }
                    .padding(.bottom, LBTheme.Spacing.lg)
                }
            }
            .padding(.horizontal, LBTheme.Spacing.xl)
        }
    }

    private func toggleTopic(_ topic: String) {
        if onboardingState.selectedInterests.contains(topic) {
            onboardingState.selectedInterests.remove(topic)
        } else {
            onboardingState.selectedInterests.insert(topic)
        }
    }
}

// MARK: - Step 3: Daily Goal Content

/// Just the scrollable goal cards + streak preview, without nav/progress/header/CTA.
private struct DailyGoalContent: View {
    let onboardingState: OnboardingState

    private let goals: [(minutes: Int, detail: String, label: String, badge: String?)] = [
        (5, "1 passage", "Casual", nil),
        (10, "2 passages", "Steady", "Popular"),
        (20, "4 passages", "Committed", nil),
        (30, "6 passages", "Ambitious", nil),
    ]

    private let weekDays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(goals, id: \.minutes) { goal in
                    GoalCardRow(
                        minutes: goal.minutes,
                        detail: goal.detail,
                        label: goal.label,
                        badge: goal.badge,
                        isSelected: onboardingState.dailyGoalMinutes == goal.minutes
                    ) {
                        onboardingState.dailyGoalMinutes = goal.minutes
                    }
                }
            }
            .padding(.horizontal, LBTheme.Spacing.xl)

            // Streak preview
            VStack(spacing: LBTheme.Spacing.sm) {
                HStack(spacing: LBTheme.Spacing.lg) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.lbG50)
                                .frame(width: 18, height: 18)
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.lbG200, lineWidth: 2)
                                }
                            Text(weekDays[index])
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.lbG400)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, LBTheme.Spacing.xl)

                Text("Your first week starts now")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lbG400)
                    .padding(.bottom, LBTheme.Spacing.lg)
            }
        }
    }
}

// MARK: - Step 4: Account Setup Content

/// Just the scrollable auth form (Apple/Google buttons, email/password inputs),
/// without nav/progress/header/CTA.
private struct AccountSetupContent: View {
    let authManager: AuthManager
    @Binding var name: String
    @Binding var email: String
    @Binding var password: String
    @Binding var errorMessage: String?
    @Binding var isLoading: Bool
    let onApple: () -> Void
    let onGoogle: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, email, password
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Apple button
                    AuthButton(style: .apple, action: onApple)
                        .padding(.bottom, 10)

                    // Google button
                    AuthButton(style: .google, action: onGoogle)

                    // Divider
                    AuthDivider()

                    // Name input
                    OnboardingInput(
                        placeholder: "First name",
                        text: $name,
                        textContentType: .givenName
                    )
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .padding(.bottom, 10)
                    .id(Field.name)

                    // Email input
                    OnboardingInput(
                        placeholder: "Email address",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .focused($focusedField, equals: .email)
                    .padding(.bottom, 10)
                    .id(Field.email)

                    // Password input
                    OnboardingInput(
                        placeholder: "Password",
                        text: $password,
                        isSecure: true,
                        textContentType: .newPassword
                    )
                    .focused($focusedField, equals: .password)
                    .id(Field.password)

                    // Error
                    if let errorMessage {
                        Text(errorMessage)
                            .font(LBTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, LBTheme.Spacing.sm)
                    }

                    // Extra space so inputs can scroll above keyboard
                    Spacer()
                        .frame(height: 300)
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
            }
            .onChange(of: focusedField) { _, field in
                guard let field else { return }
                let anchor: UnitPoint = field == .email ? UnitPoint(x: 0.5, y: 0.35) : .center
                withAnimation {
                    proxy.scrollTo(field, anchor: anchor)
                }
            }
        }
    }
}

// MARK: - Extracted Card Components (shared between old views and new setup)

/// Language card row for the language selection step.
struct LanguageCardRow: View {
    let flag: String
    let name: String
    let native: String
    let isSelected: Bool
    var isDimmed: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Flag emoji
                Text(flag)
                    .font(.system(size: 26))
                    .frame(width: 36, alignment: .center)

                // Language info
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isDimmed ? Color.lbG400 : Color.lbBlack)

                    Text(native)
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG500)
                }

                Spacer()

                // Selection circle
                if !isDimmed {
                    SelectionCircle(isSelected: isSelected)
                }
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.vertical, 14)
            .background(isSelected ? Color.lbHighlight : Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(
                        isSelected ? Color.lbNearBlack : Color.lbG100,
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isDimmed)
        .opacity(isDimmed ? 0.45 : 1)
    }
}

/// Level card row for the proficiency step.
struct LevelCardRow: View {
    let code: String
    let name: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                // Selection circle
                SelectionCircle(isSelected: isSelected)
                    .padding(.top, 2)

                // Level text
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.lbBlack)

                    Text(description)
                        .font(LBTheme.Typography.caption)
                        .foregroundStyle(Color.lbG500)
                        .lineSpacing(2)
                }

                Spacer()

                // CEFR pill
                Text(code)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.lbG500)
                    .padding(.horizontal, LBTheme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Color.lbG100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(LBTheme.Spacing.lg)
            .background(isSelected ? Color.lbHighlight : Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(
                        isSelected ? Color.lbNearBlack : Color.lbG100,
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

/// Interest topic pill for the interests step.
struct InterestTopicPill: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(emoji) \(name)")
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundStyle(Color.lbNearBlack)
                .padding(.horizontal, LBTheme.Spacing.lg)
                .padding(.vertical, 10)
                .background(isSelected ? Color.lbHighlight : Color.lbG50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? Color.lbNearBlack : Color.lbG100,
                            lineWidth: 1.5
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

/// Goal card row for the daily goal step.
struct GoalCardRow: View {
    let minutes: Int
    let detail: String
    let label: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Time
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(minutes)")
                        .font(LBTheme.serifFont(size: 26))
                        .foregroundStyle(Color.lbBlack)
                    Text("min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.lbG500)
                }
                .frame(width: 76, alignment: .leading)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(detail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lbNearBlack)
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG400)
                }

                Spacer()

                // Selection circle
                SelectionCircle(isSelected: isSelected)
            }
            .padding(.horizontal, LBTheme.Spacing.lg)
            .padding(.vertical, 14)
            .frame(minHeight: 56)
            .background(isSelected ? Color.lbHighlight : Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(
                        isSelected ? Color.lbNearBlack : Color.lbG100,
                        lineWidth: 1.5
                    )
            }
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.lbWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.lbBlack)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .offset(y: -9)
                        .padding(.trailing, LBTheme.Spacing.lg)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingSetupView(
        onboardingState: OnboardingState(),
        authManager: .shared,
        coordinator: nil
    ) {}
}
