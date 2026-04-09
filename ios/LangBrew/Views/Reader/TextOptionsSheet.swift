import SwiftUI

// MARK: - Text Options Sheet

/// A bottom sheet for customizing reading display settings.
/// Mockup (4e): Font Size with slider, Line Spacing pills (Compact/Default/Relaxed),
/// Font family options (Sans/Serif/Mono), and a "Save Options" button.
/// No theme section.
struct TextOptionsSheet: View {
    @Bindable var viewModel: ReaderViewModel
    var onDismiss: (() -> Void)?

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.xl) {
                // Title
                Text("Text Options")
                    .font(LBTheme.serifFont(size: 22))
                    .foregroundStyle(Color.lbBlack)

                // Font size section
                fontSizeSection

                // Line spacing section
                lineSpacingSection

                // Font family section
                fontFamilySection

                // Save Options button
                Button {
                    viewModel.showTextOptions = false
                } label: {
                    Text("Save Options")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.lbBlack)
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
                }
                .buttonStyle(.plain)
                .padding(.top, LBTheme.Spacing.sm)
            }
        }
    }

    // MARK: - Font Size

    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            // Label
            Text("FONT SIZE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.lbG500)
                .kerning(0.8)

            // Current size display
            Text("\(Int(viewModel.fontSize))px")
                .font(LBTheme.serifFont(size: 22))
                .foregroundStyle(Color.lbBlack)

            // Slider row: small A -- slider -- large A
            HStack(spacing: LBTheme.Spacing.md) {
                Text("A")
                    .font(LBTheme.serifFont(size: 14))
                    .foregroundStyle(Color.lbG400)

                Slider(
                    value: $viewModel.fontSize,
                    in: 14...26,
                    step: 1
                )
                .tint(Color.lbBlack)

                Text("A")
                    .font(LBTheme.serifFont(size: 22))
                    .foregroundStyle(Color.lbG400)
            }
        }
    }

    // MARK: - Line Spacing

    private var lineSpacingSection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text("LINE SPACING")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.lbG500)
                .kerning(0.8)

            HStack(spacing: LBTheme.Spacing.sm) {
                ForEach(LineSpacingOption.allCases) { option in
                    lineSpacingPill(option)
                }
            }
        }
    }

    private func lineSpacingPill(_ option: LineSpacingOption) -> some View {
        Button {
            viewModel.lineSpacing = option
        } label: {
            Text(option.displayName)
                .font(.system(
                    size: 13,
                    weight: viewModel.lineSpacing == option ? .semibold : .medium
                ))
                .foregroundStyle(
                    viewModel.lineSpacing == option ? Color.lbNearBlack : Color.lbG500
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.lbWhite)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            viewModel.lineSpacing == option ? Color.lbBlack : Color.lbG200,
                            lineWidth: 1.5
                        )
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Font Family

    private var fontFamilySection: some View {
        VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
            Text("FONT")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.lbG500)
                .kerning(0.8)

            HStack(spacing: LBTheme.Spacing.sm) {
                ForEach(ReadingFont.allCases) { font in
                    fontOptionBox(font)
                }
            }
        }
    }

    private func fontOptionBox(_ font: ReadingFont) -> some View {
        let isSelected = viewModel.readingFont == font

        return Button {
            viewModel.readingFont = font
        } label: {
            VStack(spacing: LBTheme.Spacing.sm) {
                // Sample "Aa"
                Text("Aa")
                    .font(font.sampleFont(size: 22))
                    .foregroundStyle(
                        isSelected ? Color.lbNearBlack : Color.lbG400
                    )

                // Label
                Text(font.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        isSelected ? Color.lbNearBlack : Color.lbG500
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color.lbBlack : Color.lbG200,
                        lineWidth: 1.5
                    )
            }
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
