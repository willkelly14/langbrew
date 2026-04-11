import SwiftUI

// MARK: - Past Sessions View

/// A list of previous flashcard review sessions grouped by date.
struct PastSessionsView: View {
    @Bindable var viewModel: FlashcardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hideTabBar) private var hideTabBar

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                pastSessionsNavBar
                filterPill
                sessionsList
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if viewModel.isSessionDetailPresented, let session = viewModel.selectedSession {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.isSessionDetailPresented = false
                        }
                        .transition(.opacity)

                    SessionDetailSheet(
                        session: session,
                        onDismiss: { viewModel.isSessionDetailPresented = false },
                        onRestudy: {
                            viewModel.isSessionDetailPresented = false
                            // Re-study would navigate to review with missed cards
                        }
                    )
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isSessionDetailPresented)
        .onAppear {
            hideTabBar.wrappedValue = true
        }
        .onDisappear {
            hideTabBar.wrappedValue = false
        }
    }

    // MARK: - Nav Bar

    private var pastSessionsNavBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.lbBlack)
                    .frame(width: 32, height: 32)
                    .background(Color.lbG50)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Past Sessions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.lbBlack)

            Spacer()

            // Spacer for symmetry
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Pill

    private var filterPill: some View {
        HStack {
            Button {} label: {
                HStack(spacing: 6) {
                    Text("Last 30 days")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.lbBlack)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.lbG400)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.lbG200, lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.groupedSessions, id: \.0) { label, sessions in
                    sectionGroup(label: label, sessions: sessions)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }

    private func sectionGroup(label: String, sessions: [SessionRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.lbG400)
                .textCase(.uppercase)
                .kerning(1.5)
                .padding(.bottom, 2)

            ForEach(sessions) { session in
                sessionCard(session)
            }
        }
    }

    private func sessionCard(_ session: SessionRecord) -> some View {
        Button {
            viewModel.selectSession(session)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: type + tag + chevron
                HStack {
                    HStack(spacing: 0) {
                        Text(session.type)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.lbBlack)

                        if let tag = session.tag {
                            Text(" \u{00B7} \(tag)")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color.lbG400)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lbG400)
                }

                // Stats row
                Text("\(session.correct)/\(session.total) correct \u{00B7} \(session.durationMinutes) min")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)

                // Progress bar with percentage
                HStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.lbG100)
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.lbNearBlack)
                                .frame(width: geometry.size.width * session.accuracy, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(Int(session.accuracy * 100))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.lbBlack)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
            .lbShadow(LBTheme.Shadow.card)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Detail Sheet

/// Bottom sheet showing detailed breakdown of a past review session.
struct SessionDetailSheet: View {
    let session: SessionRecord
    var onDismiss: (() -> Void)?
    var onRestudy: () -> Void

    private var missed: Int { session.total - session.correct }

    var body: some View {
        LBBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(session.type)
                    .font(LBTheme.Typography.title2)
                    .foregroundStyle(Color.lbBlack)

                // Subtitle
                Text(sessionTimeLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG400)
                    .padding(.top, 4)

                // Stats row
                HStack(spacing: 8) {
                    detailStatCard(label: "Correct", value: "\(session.correct)")
                    detailStatCard(label: "Missed", value: "\(missed)")
                    detailStatCard(label: "Time", value: "\(session.durationMinutes)m")
                }
                .padding(.top, 16)

                // Breakdown card
                VStack(spacing: 0) {
                    breakdownRow(color: Color(hex: "5a9a5a"), label: "Correct", count: session.correct, showBorder: true)
                    breakdownRow(color: Color(hex: "c45c5c"), label: "Missed", count: missed, showBorder: true)
                    breakdownRow(color: Color(hex: "c9a84c"), label: "New", count: max(0, missed / 2), showBorder: true)
                    breakdownRow(color: Color.lbG300, label: "Review", count: session.correct / 2, showBorder: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.lbG50)
                .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
                .padding(.top, 16)

                // Accuracy section
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACCURACY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.lbG400)
                        .textCase(.uppercase)
                        .kerning(0.8)

                    LBProgressBar(
                        progress: session.accuracy,
                        foregroundColor: .lbNearBlack,
                        height: 8,
                        label: "\(Int(session.accuracy * 100))%"
                    )

                    Text("vs 94% yesterday")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lbG400)
                }
                .padding(.top, 16)

                // Re-study button
                if missed > 0 {
                    Button(action: onRestudy) {
                        Text("Re-study Missed (\(missed))")
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
    }

    private var sessionTimeLabel: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(session.date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInYesterday(session.date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        return formatter.string(from: session.date)
    }

    private func detailStatCard(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(LBTheme.serifFont(size: 22))
                .foregroundStyle(Color.lbBlack)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.lbG500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
    }

    private func breakdownRow(color: Color, label: String, count: Int, showBorder: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbBlack)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lbBlack)
            }
            .padding(.vertical, 10)

            if showBorder {
                Rectangle()
                    .fill(Color.lbG100)
                    .frame(height: 0.5)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PastSessionsView(viewModel: FlashcardViewModel())
    }
}
