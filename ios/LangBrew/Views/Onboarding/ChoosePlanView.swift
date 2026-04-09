import SwiftUI

/// O6b -- Plan selection screen.
/// Back nav (no skip), billing toggle (Monthly / Yearly with "Save 33%" badge),
/// Fluency card (selected, "Recommended" badge), Free card, "Start Free Trial" CTA.
struct ChoosePlanView: View {
    let onboardingState: OnboardingState
    let onNext: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isYearly = true
    @State private var selectedPlan: PlanOption = .fluency

    private enum PlanOption: String {
        case fluency
        case free
    }

    private var fluencyPrice: String {
        isYearly ? "$72" : "$9"
    }

    private var fluencyPeriod: String {
        isYearly ? "/year" : "/month"
    }

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav (back only, no skip)
                OnboardingNav(
                    showBack: true,
                    onBack: { dismiss() }
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title
                        Text("Choose your\nplan.")
                            .font(LBTheme.Typography.title)
                            .foregroundStyle(Color.lbBlack)
                            .padding(.bottom, LBTheme.Spacing.xs)

                        // Subtitle
                        Text("Start with a 7-day free trial of Fluency. Cancel anytime.")
                            .font(LBTheme.Typography.body)
                            .foregroundStyle(Color.lbG500)
                            .padding(.bottom, LBTheme.Spacing.lg)

                        // Billing toggle
                        BillingToggleView(isYearly: $isYearly)
                            .padding(.bottom, LBTheme.Spacing.lg)

                        // Fluency card
                        SubscriptionCard(
                            name: "Fluency",
                            price: fluencyPrice,
                            period: fluencyPeriod,
                            badge: "Recommended",
                            features: [
                                "1,000 passages per month",
                                "30 hours of talk practice per month",
                                "15 book uploads per month",
                                "Unlimited listening hours",
                                "Unlimited context aware translations",
                            ],
                            isSelected: selectedPlan == .fluency
                        ) {
                            selectedPlan = .fluency
                        }
                        .padding(.bottom, LBTheme.Spacing.md)

                        // Free card
                        SubscriptionCard(
                            name: "Free",
                            price: "$0",
                            period: nil,
                            badge: nil,
                            features: [
                                "10 passages per month",
                                "1 hour of talk practice per month",
                                "1 book",
                                "1 listening hour per month",
                                "200 context aware translations per month",
                            ],
                            isSelected: selectedPlan == .free
                        ) {
                            selectedPlan = .free
                        }

                        // CTA
                        OnboardingCTA("Start Free Trial") {
                            onboardingState.selectedPlan = selectedPlan.rawValue
                            onNext()
                        }
                        .padding(.top, LBTheme.Spacing.xl)
                        .padding(.bottom, LBTheme.Spacing.md)
                    }
                    .padding(.horizontal, LBTheme.Spacing.xl)
                    .padding(.top, LBTheme.Spacing.xl)
                }
            }
        }
    }
}

// MARK: - Billing Toggle

private struct BillingToggleView: View {
    @Binding var isYearly: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Monthly
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isYearly = false }
            } label: {
                Text("Monthly")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(!isYearly ? Color.lbNearBlack : Color.lbG500)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(!isYearly ? Color.lbWhite : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: !isYearly ? .black.opacity(0.08) : .clear, radius: 3, y: 1)
            }

            // Yearly
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isYearly = true }
            } label: {
                HStack(spacing: 6) {
                    Text("Yearly")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isYearly ? Color.lbNearBlack : Color.lbG500)

                    Text("Save 33%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.lbWhite)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.lbBlack)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isYearly ? Color.lbWhite : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: isYearly ? .black.opacity(0.08) : .clear, radius: 3, y: 1)
            }
        }
        .padding(3)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.large))
    }
}

// MARK: - Subscription Card

private struct SubscriptionCard: View {
    let name: String
    let price: String
    let period: String?
    let badge: String?
    let features: [String]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: LBTheme.Spacing.md) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.lbNearBlack)

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: LBTheme.Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(price)
                                .font(LBTheme.serifFont(size: 24))
                                .foregroundStyle(Color.lbBlack)
                            if let period {
                                Text(period)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.lbG500)
                            }
                        }

                        SelectionCircle(isSelected: isSelected)
                    }
                }

                // Features list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: LBTheme.Spacing.sm) {
                            // Checkmark
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.lbNearBlack)
                                .frame(width: 13)

                            Text(feature)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.lbG500)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)
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
    ChoosePlanView(onboardingState: OnboardingState()) {}
}
