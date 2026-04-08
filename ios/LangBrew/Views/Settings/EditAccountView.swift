import SwiftUI

// MARK: - Edit Account View

/// Allows editing the user's profile: avatar, name, and email (read-only).
/// Photo change is non-functional for Milestone 2.
struct EditAccountView: View {
    let viewModel: SettingsViewModel
    @State private var editedName: String = ""
    @State private var hasChanges: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: LBTheme.Spacing.xl) {
                    // Avatar section
                    avatarSection

                    // Fields section in a white container
                    fieldsSection

                    // Save button
                    LBButton(
                        "Save Changes",
                        variant: .primary,
                        fullWidth: true
                    ) {
                        viewModel.updateProfile(name: editedName)
                        dismiss()
                    }
                    .opacity(hasChanges ? 1 : 0.5)
                    .disabled(!hasChanges)
                }
                .padding(.horizontal, LBTheme.Spacing.xl)
                .padding(.top, LBTheme.Spacing.xl)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editedName = viewModel.userName
        }
        .onChange(of: editedName) { _, newValue in
            hasChanges = newValue != viewModel.userName && !newValue.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: LBTheme.Spacing.sm) {
            LBAvatarCircle(
                imageURL: viewModel.avatarUrl.flatMap { URL(string: $0) },
                name: viewModel.userName,
                size: 88,
                style: .dark,
                initialsFontSize: 34
            )

            Text("Change Photo")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.lbBlack)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LBTheme.Spacing.lg)
    }

    // MARK: - Fields Section (in white container)

    private var fieldsSection: some View {
        VStack(spacing: 0) {
            // Name field
            VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                Text("NAME")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lbG400)
                    .kerning(0.5)

                TextField("Your name", text: $editedName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lbNearBlack)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            // Divider
            Rectangle()
                .fill(Color.lbG100)
                .frame(height: 1)
                .padding(.leading, 14)

            // Email field (read-only)
            VStack(alignment: .leading, spacing: LBTheme.Spacing.xs) {
                Text("EMAIL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lbG400)
                    .kerning(0.5)

                Text(viewModel.email)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lbG400)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
    }
}

#Preview {
    NavigationStack {
        EditAccountView(viewModel: SettingsViewModel(coordinator: AppCoordinator()))
    }
}
