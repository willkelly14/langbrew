import SwiftUI

// MARK: - Generate Passage Sheet

/// Bottom sheet for configuring and triggering passage generation.
/// Offers two modes: Auto (fully automatic) and Custom (suggested topic,
/// custom input, style pills, length pills).
struct GeneratePassageSheet: View {
    @Bindable var viewModel: LibraryViewModel
    var onDismiss: (() -> Void)?

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("Generate Passage")
                    .font(LBTheme.serifFont(size: 24))
                    .foregroundStyle(Color.lbBlack)
                    .padding(.bottom, 4)

                // Subtitle
                Text("We\u{2019}ll create a passage matched to your level.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)
                    .padding(.bottom, 18)

                // Mode toggle
                ModeToggle(selectedMode: $viewModel.generateMode)
                    .padding(.bottom, 18)

                // Mode content
                switch viewModel.generateMode {
                case .auto:
                    AutoModeContent()
                        .padding(.bottom, 18)
                case .custom:
                    CustomModeContent(
                        suggestedTopic: $viewModel.suggestedTopic,
                        customTopic: $viewModel.customTopic,
                        selectedStyle: $viewModel.selectedStyle,
                        selectedLength: $viewModel.selectedLength,
                        onRefreshTopic: { viewModel.refreshSuggestedTopic() }
                    )
                }

                // Generate button
                Button {
                    Task {
                        await viewModel.generatePassage()
                    }
                } label: {
                    Text("Generate Passage")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.lbBlack)
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                }
                .buttonStyle(.plain)
                .opacity(viewModel.canGenerate ? 1 : 0.5)
                .disabled(!viewModel.canGenerate)
            }
        }
    }
}

// MARK: - Mode Toggle

/// Segmented control for Auto | Custom, matching the content-type tabs style.
private struct ModeToggle: View {
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            selectedMode == mode ? Color.lbNearBlack : Color.lbG500
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedMode == mode ? Color.lbWhite : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(
                            color: selectedMode == mode ? .black.opacity(0.08) : .clear,
                            radius: 2, y: 1
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Auto Mode Content

/// Auto mode: centered description text, no topic pills.
private struct AutoModeContent: View {
    var body: some View {
        Text("We\u{2019}ll pick the topic, style, and length based on your interests and level.")
            .font(.system(size: 14))
            .foregroundStyle(Color.lbG500)
            .multilineTextAlignment(.center)
            .lineSpacing(14 * 0.5)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Custom Mode Content

/// Custom mode: suggested topic box, "or" divider, custom input,
/// style pills, length pills.
private struct CustomModeContent: View {
    @Binding var suggestedTopic: String
    @Binding var customTopic: String
    @Binding var selectedStyle: PassageStyle
    @Binding var selectedLength: PassageLength
    let onRefreshTopic: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Suggested topic label
            Text("SUGGESTED TOPIC")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.lbG400)
                .kerning(0.66)
                .padding(.bottom, 10)

            // Suggestion box
            HStack {
                Text(suggestedTopic)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.lbNearBlack)

                Spacer()

                // Refresh button
                Button(action: onRefreshTopic) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lbG500)
                        .frame(width: 32, height: 32)
                        .background(Color.lbWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.lbG200, lineWidth: 1.5)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.lbG50)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                    .strokeBorder(Color.lbG100, lineWidth: 1.5)
            }
            .padding(.bottom, 12)

            // "or" divider
            Text("or")
                .font(.system(size: 12))
                .foregroundStyle(Color.lbG400)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)

            // Custom input
            TextField("Describe your own topic...", text: $customTopic)
                .font(.system(size: 14))
                .foregroundStyle(Color.lbNearBlack)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.lbG50)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: LBTheme.Radius.large)
                        .strokeBorder(Color.lbG100, lineWidth: 1.5)
                }
                .padding(.bottom, 18)

            // Style pills
            PillSection(title: "STYLE") {
                PillRow(
                    options: PassageStyle.allCases,
                    selected: $selectedStyle,
                    label: \.displayName
                )
            }
            .padding(.bottom, 18)

            // Length pills
            PillSection(title: "LENGTH") {
                PillRow(
                    options: PassageLength.allCases,
                    selected: $selectedLength,
                    label: \.displayName
                )
            }
            .padding(.bottom, 18)
        }
    }
}

// MARK: - Pill Section

/// A labeled section with uppercase heading and content.
private struct PillSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.lbG400)
                .kerning(0.66)

            content()
        }
    }
}

// MARK: - Pill Row

/// A horizontal row of selectable pills matching the mockup style:
/// 1.5px g200 border, white bg, rounded 10px, 13px weight 500 g500.
/// Active: black border, near-black text, weight 600.
private struct PillRow<T: Identifiable & Equatable & Sendable>: View {
    let options: [T]
    @Binding var selected: T
    let label: (T) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LBTheme.Spacing.sm) {
                ForEach(options) { option in
                    Button {
                        selected = option
                    } label: {
                        Text(label(option))
                            .font(.system(
                                size: 13,
                                weight: selected == option ? .semibold : .medium
                            ))
                            .foregroundStyle(
                                selected == option ? Color.lbNearBlack : Color.lbG500
                            )
                            .padding(.horizontal, LBTheme.Spacing.md)
                            .padding(.vertical, 10)
                            .background(Color.lbWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        selected == option ? Color.lbBlack : Color.lbG200,
                                        lineWidth: 1.5
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    GeneratePassageSheet(viewModel: LibraryViewModel())
        .background(Color.lbLinen)
}
