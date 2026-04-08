import SwiftUI

// MARK: - Text Options Sheet

/// A bottom sheet for customizing reading display settings.
/// Changes apply live to the reader behind the sheet.
struct TextOptionsSheet: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LBBottomSheet {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.xl) {
                // Header
                sheetHeader

                // Font size slider
                fontSizeSection

                // Line spacing options
                lineSpacingSection

                // Font family toggle
                fontFamilySection

                // Theme selector
                themeSection
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Text("Text Options")
                .font(LBTheme.Typography.title2)
                .foregroundStyle(Color.lbBlack)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.lbG300)
            }
        }
    }

    // MARK: - Font Size

    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text("Font Size")
                .font(LBTheme.Typography.bodyMedium)
                .foregroundStyle(Color.lbBlack)

            HStack(spacing: LBTheme.Spacing.md) {
                Text("A")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.lbG400)

                Slider(
                    value: $viewModel.fontSize,
                    in: 14...24,
                    step: 1
                )
                .tint(Color.lbBlack)

                Text("A")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.lbG400)
            }

            // Live preview
            Text("El sol entraba por las ventanas.")
                .font(viewModel.bodyFont)
                .foregroundStyle(Color.lbBlack)
                .padding(LBTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.lbG50)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))
        }
    }

    // MARK: - Line Spacing

    private var lineSpacingSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text("Line Spacing")
                .font(LBTheme.Typography.bodyMedium)
                .foregroundStyle(Color.lbBlack)

            HStack(spacing: LBTheme.Spacing.sm) {
                ForEach(LineSpacingOption.allCases) { option in
                    lineSpacingButton(option)
                }
            }
        }
    }

    private func lineSpacingButton(_ option: LineSpacingOption) -> some View {
        Button {
            viewModel.lineSpacing = option
        } label: {
            VStack(spacing: LBTheme.Spacing.xs) {
                // Visual representation of line spacing
                VStack(spacing: option.multiplier * 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                viewModel.lineSpacing == option
                                    ? Color.lbBlack
                                    : Color.lbG300
                            )
                            .frame(height: 2)
                    }
                }
                .frame(width: 32, height: 28)

                Text(option.displayName)
                    .font(LBTheme.Typography.caption)
            }
            .foregroundStyle(
                viewModel.lineSpacing == option
                    ? Color.lbBlack
                    : Color.lbG400
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, LBTheme.Spacing.md)
            .background(
                viewModel.lineSpacing == option
                    ? Color.lbHighlight
                    : Color.lbG50
            )
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Font Family

    private var fontFamilySection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text("Font")
                .font(LBTheme.Typography.bodyMedium)
                .foregroundStyle(Color.lbBlack)

            HStack(spacing: LBTheme.Spacing.sm) {
                ForEach(ReadingFont.allCases) { font in
                    fontButton(font)
                }
            }
        }
    }

    private func fontButton(_ font: ReadingFont) -> some View {
        Button {
            viewModel.readingFont = font
        } label: {
            VStack(spacing: LBTheme.Spacing.xs) {
                Text("Aa")
                    .font(
                        font == .serif
                            ? LBTheme.serifFont(size: 20)
                            : .system(size: 20)
                    )

                Text(font.displayName)
                    .font(LBTheme.Typography.caption)
            }
            .foregroundStyle(
                viewModel.readingFont == font
                    ? Color.lbBlack
                    : Color.lbG400
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, LBTheme.Spacing.md)
            .background(
                viewModel.readingFont == font
                    ? Color.lbHighlight
                    : Color.lbG50
            )
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.medium))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Theme

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text("Theme")
                .font(LBTheme.Typography.bodyMedium)
                .foregroundStyle(Color.lbBlack)

            HStack(spacing: LBTheme.Spacing.sm) {
                ForEach(ReadingTheme.allCases) { theme in
                    themeButton(theme)
                }
            }
        }
    }

    private func themeButton(_ theme: ReadingTheme) -> some View {
        Button {
            viewModel.readingTheme = theme
        } label: {
            VStack(spacing: LBTheme.Spacing.sm) {
                Circle()
                    .fill(theme.backgroundColor)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                viewModel.readingTheme == theme
                                    ? Color.lbBlack
                                    : Color.lbG200,
                                lineWidth: viewModel.readingTheme == theme ? 2 : 1
                            )
                    }
                    .overlay {
                        Text("A")
                            .font(LBTheme.serifFont(size: 16))
                            .foregroundStyle(theme.textColor)
                    }

                Text(theme.displayName)
                    .font(LBTheme.Typography.caption)
                    .foregroundStyle(
                        viewModel.readingTheme == theme
                            ? Color.lbBlack
                            : Color.lbG400
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    TextOptionsSheet(
        viewModel: ReaderViewModel(
            passage: MockData.samplePassage,
            vocabulary: MockData.sampleVocabulary
        )
    )
}
