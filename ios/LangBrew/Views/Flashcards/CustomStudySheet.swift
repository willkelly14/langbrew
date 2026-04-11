import SwiftUI

// MARK: - Custom Study Sheet

/// Bottom sheet for configuring a custom study session.
/// Allows selecting mode, card limit, and card type before starting.
struct CustomStudySheet: View {
    @Bindable var viewModel: FlashcardViewModel
    var onDismiss: (() -> Void)?
    var onStart: () -> Void

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("Custom Study")
                    .font(LBTheme.Typography.title2)
                    .foregroundStyle(Color.lbBlack)
                    .padding(.bottom, 16)

                // Mode list
                VStack(spacing: 6) {
                    ForEach(CustomStudyMode.allCases) { mode in
                        modeRow(mode)
                    }
                }

                // Card limit section
                Text("CARD LIMIT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.lbG500)
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                HStack(spacing: 8) {
                    ForEach(CardLimit.allCases) { limit in
                        limitPill(limit)
                    }
                }

                // Card type section
                Text("CARD TYPE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.lbG500)
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                HStack(spacing: 8) {
                    ForEach(CardTypeFilter.allCases) { type in
                        typePill(type)
                    }
                }

                // Start button
                Button(action: onStart) {
                    Text("Start Session")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.lbBlack)
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
        }
    }

    // MARK: - Mode Row

    private func modeRow(_ mode: CustomStudyMode) -> some View {
        let isSelected = viewModel.selectedMode == mode

        return Button {
            viewModel.selectedMode = mode
        } label: {
            HStack(spacing: 12) {
                // Icon container
                Image(systemName: mode.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.lbBlack)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color.lbBlack : Color.lbG50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.lbNearBlack)

                    Text(mode.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG400)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.lbBlack)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? Color.lbG50 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: LBTheme.Radius.card)
                    .strokeBorder(isSelected ? Color.lbG200 : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Limit Pill

    private func limitPill(_ limit: CardLimit) -> some View {
        let isSelected = viewModel.selectedLimit == limit

        return Button {
            viewModel.selectedLimit = limit
        } label: {
            Text(limit.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.lbNearBlack : Color.lbG500)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.lbBlack : Color.lbG200, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Type Pill

    private func typePill(_ type: CardTypeFilter) -> some View {
        let isSelected = viewModel.selectedType == type

        return Button {
            viewModel.selectedType = type
        } label: {
            Text(type.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.lbNearBlack : Color.lbG500)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.lbBlack : Color.lbG200, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack(alignment: .bottom) {
        Color.lbLinen.ignoresSafeArea()

        CustomStudySheet(
            viewModel: FlashcardViewModel(),
            onDismiss: {},
            onStart: {}
        )
    }
}
