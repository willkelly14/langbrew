import SwiftUI

// MARK: - Flashcard Hub View

/// The main Flashcards tab screen showing statistics, due cards,
/// and navigation to review sessions, past sessions, and Language Bank.
struct FlashcardHubView: View {
    @Bindable var viewModel: FlashcardViewModel
    @State private var navigateToReview = false
    @State private var navigateToPastSessions = false

    var body: some View {
        ZStack {
            Color.lbLinen
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    hubHeader
                    statsRow
                    practiceCard
                    studyStreakSection
                    learningVelocitySection
                    accuracySection
                    timeSpentSection
                    masteryBreakdownSection
                    reviewForecastSection
                    languageBankLink
                    pastSessionsLink
                }
                .padding(.bottom, 100)
            }
        }
        .overlay {
            if viewModel.isCustomStudyPresented {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.isCustomStudyPresented = false
                        }
                        .transition(.opacity)

                    CustomStudySheet(
                        viewModel: viewModel,
                        onDismiss: { viewModel.isCustomStudyPresented = false },
                        onStart: {
                            viewModel.isCustomStudyPresented = false
                            viewModel.startReview()
                            navigateToReview = true
                        }
                    )
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isCustomStudyPresented)
        .navigationDestination(isPresented: $navigateToReview) {
            FlashcardReviewView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $navigateToPastSessions) {
            PastSessionsView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadAllData()
        }
        .refreshable {
            await viewModel.loadAllData()
        }
    }

    // MARK: - Header

    private var hubHeader: some View {
        HStack {
            Text("Flashcards")
                .font(LBTheme.Typography.largeTitle)
                .foregroundStyle(Color.lbBlack)

            Spacer()

            Text(viewModel.activeFlag)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(Color.lbG50)
                .clipShape(Circle())
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 0)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 8) {
            LBStatCard(value: viewModel.wordCount, label: "Words")
            LBStatCard(value: viewModel.phraseCount, label: "Phrases")
            LBStatCard(value: viewModel.sentenceCount, label: "Sentences")
        }
        .padding(.horizontal, 30)
        .padding(.top, 12)
    }

    // MARK: - Practice Card

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(viewModel.dueTotal) cards due today")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white)

            Text("\(viewModel.dueWords) words \u{00B7} \(viewModel.duePhrases) phrases \u{00B7} \(viewModel.dueSentences) sentences")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.top, 4)

            HStack(spacing: 10) {
                Button {
                    viewModel.startReview()
                    navigateToReview = true
                } label: {
                    Text("Start Practice")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.lbBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.isCustomStudyPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.white)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbBlack)
        .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
        .padding(.horizontal, 30)
        .padding(.top, 12)
    }

    // MARK: - Study Streak

    private var studyStreakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STUDY STREAK")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.lbG400)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(viewModel.streakDays)")
                    .font(LBTheme.serifFont(size: 34))
                    .foregroundStyle(Color.lbNearBlack)

                Text("day streak")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.lbNearBlack)
            }

            ActivityGridView(grid: viewModel.activityGrid)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .lbShadow(LBTheme.Shadow.card)
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - Learning Velocity

    private var learningVelocitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEARNING VELOCITY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.lbG400)
                .textCase(.uppercase)
                .kerning(0.5)

            Text(viewModel.velocityHeadline)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.lbBlack)
                .lineSpacing(15 * 0.35)

            VelocityChartView(dataPoints: viewModel.velocityDataPoints)
                .frame(height: 60)

            Text(viewModel.velocityInsight)
                .font(.system(size: 12))
                .foregroundStyle(Color.lbG500)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .lbShadow(LBTheme.Shadow.card)
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - Accuracy

    private var accuracySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCURACY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.lbG400)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(viewModel.accuracyPercentage)%")
                    .font(LBTheme.serifFont(size: 38))
                    .foregroundStyle(Color.lbNearBlack)

                Text("correct this week")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)
            }

            Text("\u{25B2} \(viewModel.accuracyTrend)")
                .font(.system(size: 12))
                .foregroundStyle(Color.lbG400)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.recentAccuracySessions.enumerated()), id: \.element.id) { index, session in
                    HStack {
                        Text(session.date)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.lbG500)
                            .frame(width: 75, alignment: .leading)

                        Text(session.details)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.lbNearBlack)

                        Spacer()

                        Text("\(session.percentage)%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.lbNearBlack)
                    }
                    .padding(.vertical, 10)

                    if index < viewModel.recentAccuracySessions.count - 1 {
                        Rectangle()
                            .fill(Color.lbG100)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .lbShadow(LBTheme.Shadow.card)
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - Time Spent

    private var timeSpentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME SPENT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.lbG400)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(viewModel.timeSpentMinutes) min")
                    .font(LBTheme.serifFont(size: 34))
                    .foregroundStyle(Color.lbNearBlack)

                Text("this week")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)
            }

            Text(viewModel.timeAverage)
                .font(.system(size: 12))
                .foregroundStyle(Color.lbG400)

            WeeklyBarChart(data: viewModel.weeklyTimeData)
                .frame(height: 80)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .lbShadow(LBTheme.Shadow.card)
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - Mastery Breakdown

    private var masteryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MASTERY BREAKDOWN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.lbG400)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(viewModel.masteryPercentage)%")
                    .font(LBTheme.serifFont(size: 34))
                    .foregroundStyle(Color.lbBlack)

                Text("mastered or known")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lbG500)
            }

            // Mastery bar
            MasteryBar(
                mastered: viewModel.masteredFraction,
                known: viewModel.knownFraction,
                learning: viewModel.learningFraction,
                new: viewModel.newFraction
            )

            // Legend grid (2 columns)
            let legendItems: [(Color, String, Int)] = [
                (Color.lbNearBlack, "Mastered", viewModel.masteredCount),
                (Color.lbG400, "Known", viewModel.knownCount),
                (Color.lbG200, "Learning", viewModel.learningCount),
                (Color.lbG100, "New", viewModel.newCount),
            ]

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 8) {
                ForEach(Array(legendItems.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.0)
                            .frame(width: 10, height: 10)

                        Text(item.1)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.lbG500)

                        Spacer()

                        Text("\(item.2)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.lbBlack)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .lbShadow(LBTheme.Shadow.card)
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - Review Forecast

    private var reviewForecastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REVIEW FORECAST")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.lbG400)
                .textCase(.uppercase)
                .kerning(0.5)

            // Month header with nav arrows
            HStack {
                Button {} label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lbG400)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(viewModel.forecastMonth)
                    .font(LBTheme.serifFont(size: 20))
                    .foregroundStyle(Color.lbBlack)

                Spacer()

                Button {} label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lbG400)
                }
                .buttonStyle(.plain)
            }

            ForecastCalendar(days: viewModel.forecastDays())

            // Legend
            HStack(spacing: 16) {
                Spacer()
                forecastLegendItem(color: Color.lbG200, label: "Low")
                forecastLegendItem(color: Color.lbG400, label: "Med")
                forecastLegendItem(color: Color.lbNearBlack, label: "High")
                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lbWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .lbShadow(LBTheme.Shadow.card)
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    private func forecastLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.lbG400)
        }
    }

    // MARK: - Language Bank Link

    private var languageBankLink: some View {
        NavigationLink {
            LanguageBankView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book.closed")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.lbBlack)

                Text("Language Bank")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.lbBlack)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lbG400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
            .lbShadow(LBTheme.Shadow.card)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
        .padding(.top, 16)
    }

    // MARK: - Past Sessions Link

    private var pastSessionsLink: some View {
        Button {
            navigateToPastSessions = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.lbBlack)

                Text("Past Sessions")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.lbBlack)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lbG400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.lbWhite)
            .clipShape(RoundedRectangle(cornerRadius: LBTheme.Radius.card))
            .lbShadow(LBTheme.Shadow.card)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
        .padding(.top, 8)
    }
}

// MARK: - Activity Grid

/// GitHub-style activity heatmap: 7 rows (M-S) x 8 columns.
private struct ActivityGridView: View {
    let grid: [[ActivityDay]]
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            // Day labels column
            VStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { row in
                    Text(dayLabels[row])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.lbG400)
                        .frame(width: 14, height: 11)
                }
            }

            // Grid columns
            ForEach(0..<8, id: \.self) { col in
                VStack(spacing: 3) {
                    ForEach(0..<min(7, grid.count), id: \.self) { row in
                        if col < grid[row].count {
                            let day = grid[row][col]
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cellColor(for: day))
                                .frame(width: 11, height: 11)
                        }
                    }
                }
            }

            Spacer()
        }
    }

    private func cellColor(for day: ActivityDay) -> Color {
        if day.isToday {
            return .lbG400
        } else if day.isActive {
            return .lbNearBlack
        } else {
            return .lbG200
        }
    }
}

// MARK: - Velocity Chart

/// A simple line chart for learning velocity data.
private struct VelocityChartView: View {
    let dataPoints: [CGFloat]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxVal = dataPoints.max() ?? 1
            let stepX = width / CGFloat(max(dataPoints.count - 1, 1))

            Path { path in
                for (index, value) in dataPoints.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (value / maxVal) * height

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.lbBlack, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Fill area under the line
            Path { path in
                for (index, value) in dataPoints.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (value / maxVal) * height

                    if index == 0 {
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color.lbBlack.opacity(0.08), Color.lbBlack.opacity(0.01)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Weekly Bar Chart

/// A bar chart showing 7 days (Mon-Sun) of time data.
private struct WeeklyBarChart: View {
    let data: [CGFloat]
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        GeometryReader { geometry in
            let maxVal = data.max() ?? 1
            let barWidth = (geometry.size.width - CGFloat(data.count - 1) * 6) / CGFloat(data.count)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<min(data.count, 7), id: \.self) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.lbBlack)
                            .frame(
                                width: barWidth,
                                height: max(4, (data[index] / maxVal) * (geometry.size.height - 20))
                            )

                        Text(dayLabels[index])
                            .font(.system(size: 10))
                            .foregroundStyle(Color.lbG400)
                    }
                }
            }
        }
    }
}

// MARK: - Mastery Bar

/// A stacked horizontal bar showing mastery breakdown.
private struct MasteryBar: View {
    let mastered: CGFloat
    let known: CGFloat
    let learning: CGFloat
    let new: CGFloat

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                if mastered > 0 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.lbNearBlack)
                        .frame(width: max(4, mastered * geometry.size.width - 1))
                }
                if known > 0 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.lbG400)
                        .frame(width: max(4, known * geometry.size.width - 1))
                }
                if learning > 0 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.lbG200)
                        .frame(width: max(4, learning * geometry.size.width - 1))
                }
                if new > 0 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.lbG100)
                        .frame(width: max(4, new * geometry.size.width - 1))
                }
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Forecast Calendar

/// A monthly calendar grid with forecast intensity coloring.
private struct ForecastCalendar: View {
    let days: [ForecastDay]
    private let dayHeaders = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        VStack(spacing: 4) {
            // Day-of-week headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(dayHeaders, id: \.self) { header in
                    Text(header)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.lbG400)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar cells
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days) { day in
                    if day.isCurrentMonth {
                        Text("\(day.dayNumber)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(forecastTextColor(for: day))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(forecastCellColor(for: day))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                if day.isToday {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.lbNearBlack, lineWidth: 2)
                                }
                            }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private func forecastCellColor(for day: ForecastDay) -> Color {
        switch day.intensity {
        case 1: .lbG200
        case 2: .lbG400
        case 3: .lbNearBlack
        default: .clear
        }
    }

    private func forecastTextColor(for day: ForecastDay) -> Color {
        switch day.intensity {
        case 2, 3: .white
        default: .lbBlack
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FlashcardHubView(viewModel: FlashcardViewModel())
    }
}
