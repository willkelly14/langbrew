import SwiftUI

// MARK: - Generate Passage Sheet

/// Bottom sheet for configuring and triggering passage generation.
/// Offers two modes: Auto (topic pills from interests) and Custom
/// (topic input, style, length, difficulty pickers).
struct GeneratePassageSheet: View {
    @Bindable var viewModel: LibraryViewModel

    var body: some View {
        LBBottomSheet {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.xl) {
                // Title
                Text("Generate a Passage")
                    .font(LBTheme.Typography.title2)
                    .foregroundStyle(Color.lbBlack)

                // Mode picker
                ModePicker(selectedMode: $viewModel.generateMode)

                // Mode content
                switch viewModel.generateMode {
                case .auto:
                    AutoModeContent(
                        selectedTopics: viewModel.selectedAutoTopics,
                        onToggle: { viewModel.toggleAutoTopic($0) }
                    )
                case .custom:
                    CustomModeContent(
                        topic: $viewModel.customTopic,
                        selectedStyle: $viewModel.selectedStyle,
                        selectedLength: $viewModel.selectedLength,
                        selectedDifficulty: $viewModel.selectedDifficulty
                    )
                }

                // Generate button
                LBButton(
                    "Generate",
                    variant: .primary,
                    icon: "sparkles",
                    fullWidth: true
                ) {
                    Task {
                        await viewModel.generatePassage()
                    }
                }
                .opacity(viewModel.canGenerate ? 1 : 0.5)
                .disabled(!viewModel.canGenerate)
            }
        }
    }
}

// MARK: - Mode Picker

/// Segmented control toggling between Auto and Custom generation modes.
private struct ModePicker: View {
    @Binding var selectedMode: GenerateMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GenerateMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.displayName)
                        .font(LBTheme.Typography.bodyMedium)
                        .foregroundStyle(
                            selectedMode == mode ? Color.lbBlack : Color.lbG400
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LBTheme.Spacing.md)
                        .background(
                            selectedMode == mode ? Color.lbWhite : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
    }
}

// MARK: - Auto Mode Content

/// Auto mode: shows suggested topic pills from user interests.
private struct AutoModeContent: View {
    let selectedTopics: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text("Pick a topic")
                .font(LBTheme.Typography.bodyMedium)
                .foregroundStyle(Color.lbBlack)

            Text("We'll create a passage based on your interests.")
                .font(LBTheme.Typography.caption)
                .foregroundStyle(Color.lbG500)

            OnboardingFlowLayout(spacing: LBTheme.Spacing.sm) {
                ForEach(MockPassageData.suggestedTopics, id: \.self) { topic in
                    TopicPill(
                        title: topic,
                        isSelected: selectedTopics.contains(topic)
                    ) {
                        onToggle(topic)
                    }
                }
            }
        }
    }
}

// MARK: - Custom Mode Content

/// Custom mode: topic input, style picker, length picker, difficulty picker.
private struct CustomModeContent: View {
    @Binding var topic: String
    @Binding var selectedStyle: PassageStyle
    @Binding var selectedLength: PassageLength
    @Binding var selectedDifficulty: CEFRLevel

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.xl) {
            // Topic input
            VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
                Text("Topic")
                    .font(LBTheme.Typography.bodyMedium)
                    .foregroundStyle(Color.lbBlack)

                TextField("What should the passage be about?", text: $topic)
                    .font(LBTheme.Typography.body)
                    .foregroundStyle(Color.lbNearBlack)
                    .padding(.horizontal, LBTheme.Spacing.md)
                    .padding(.vertical, LBTheme.Spacing.md)
                    .background(Color.lbG50)
                    .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                    .overlay {
                        RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                            .strokeBorder(Color.lbG100, lineWidth: 1)
                    }
            }

            // Style picker
            OptionPicker(
                title: "Style",
                options: PassageStyle.allCases,
                selected: $selectedStyle,
                label: \.displayName
            )

            // Length picker
            OptionPicker(
                title: "Length",
                options: PassageLength.allCases,
                selected: $selectedLength,
                label: \.displayName
            )

            // Difficulty picker
            OptionPicker(
                title: "Difficulty",
                options: CEFRLevel.allCases,
                selected: $selectedDifficulty,
                label: \.rawValue
            )
        }
    }
}

// MARK: - Option Picker

/// A horizontal pill picker for selecting from an array of options.
private struct OptionPicker<T: Identifiable & Equatable & Sendable>: View {
    let title: String
    let options: [T]
    @Binding var selected: T
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.sm) {
            Text(title)
                .font(LBTheme.Typography.bodyMedium)
                .foregroundStyle(Color.lbBlack)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LBTheme.Spacing.sm) {
                    ForEach(options) { option in
                        Button {
                            selected = option
                        } label: {
                            Text(label(option))
                                .font(LBTheme.Typography.caption)
                                .padding(.horizontal, LBTheme.Spacing.md)
                                .padding(.vertical, LBTheme.Spacing.sm)
                                .background(
                                    selected == option ? Color.lbBlack : Color.clear
                                )
                                .foregroundStyle(
                                    selected == option ? Color.lbWhite : Color.lbBlack
                                )
                                .clipShape(Capsule())
                                .overlay {
                                    if selected != option {
                                        Capsule()
                                            .strokeBorder(Color.lbG200, lineWidth: 1)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Topic Pill

/// A selectable topic pill for auto mode.
private struct TopicPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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

#Preview {
    GeneratePassageSheet(viewModel: LibraryViewModel())
        .background(Color.lbLinen)
}
