import Foundation
import SwiftUI

// MARK: - Flashcard Card Type

/// The type of vocabulary item on a flashcard.
enum FlashcardType: String, Sendable, CaseIterable, Identifiable {
    case word
    case phrase
    case sentence

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .word: "Word"
        case .phrase: "Phrase"
        case .sentence: "Sentence"
        }
    }

    var pluralName: String {
        switch self {
        case .word: "Words"
        case .phrase: "Phrases"
        case .sentence: "Sentences"
        }
    }
}

// MARK: - Flashcard Item

/// A single flashcard for review.
struct FlashcardItem: Identifiable, Sendable {
    let id: String
    let type: FlashcardType
    let frontText: String
    let frontLanguageTag: String
    let exampleSentence: String
    let exampleHighlight: String
    let definitions: [FlashcardDefinition]
    let status: String // new, learning, known, mastered

    /// Creates a FlashcardItem from a FlashcardCardResponse API response.
    init(from card: FlashcardCardResponse) {
        self.id = card.id
        switch card.type.lowercased() {
        case "phrase": self.type = .phrase
        case "sentence": self.type = .sentence
        default: self.type = .word
        }
        self.frontText = card.text
        self.frontLanguageTag = card.type.uppercased()
        self.exampleSentence = card.exampleSentence ?? ""
        self.exampleHighlight = card.text
        self.status = card.status

        // Convert API definitions to FlashcardDefinition
        if let apiDefs = card.definitions, !apiDefs.isEmpty {
            self.definitions = apiDefs.enumerated().map { index, def in
                FlashcardDefinition(
                    id: "\(card.id)-def-\(index)",
                    number: index + 1,
                    word: def["meaning"] ?? card.translation,
                    example: def["example"] ?? "",
                    exampleBold: "",
                    translation: def["definition"] ?? card.translation
                )
            }
        } else {
            // Fall back to just using the translation
            self.definitions = [
                FlashcardDefinition(
                    id: "\(card.id)-def-0",
                    number: 1,
                    word: card.translation,
                    example: card.exampleSentence ?? "",
                    exampleBold: card.text,
                    translation: card.translation
                )
            ]
        }
    }

    /// Internal initializer for mock data.
    init(
        id: String,
        type: FlashcardType,
        frontText: String,
        frontLanguageTag: String,
        exampleSentence: String,
        exampleHighlight: String,
        definitions: [FlashcardDefinition],
        status: String
    ) {
        self.id = id
        self.type = type
        self.frontText = frontText
        self.frontLanguageTag = frontLanguageTag
        self.exampleSentence = exampleSentence
        self.exampleHighlight = exampleHighlight
        self.definitions = definitions
        self.status = status
    }
}

/// A definition entry shown on the back of a flashcard.
struct FlashcardDefinition: Identifiable, Sendable {
    let id: String
    let number: Int
    let word: String
    let example: String
    let exampleBold: String
    let translation: String
}

// MARK: - Custom Study Mode

enum CustomStudyMode: String, Sendable, CaseIterable, Identifiable {
    case dailyReview
    case hardestCards
    case newCardsOnly
    case reviewAhead
    case randomMix

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dailyReview: "Daily Review"
        case .hardestCards: "Hardest Cards"
        case .newCardsOnly: "New Cards Only"
        case .reviewAhead: "Review Ahead"
        case .randomMix: "Random Mix"
        }
    }

    var description: String {
        switch self {
        case .dailyReview: "Cards due for review today"
        case .hardestCards: "Cards you've missed the most"
        case .newCardsOnly: "Preview cards you haven't seen yet"
        case .reviewAhead: "Practice cards before they're due"
        case .randomMix: "Shuffle from your entire deck"
        }
    }

    var iconName: String {
        switch self {
        case .dailyReview: "clock"
        case .hardestCards: "waveform.path"
        case .newCardsOnly: "star"
        case .reviewAhead: "forward"
        case .randomMix: "shuffle"
        }
    }

    /// Maps to the backend API `StudyMode` enum value.
    var apiMode: String {
        switch self {
        case .dailyReview: "daily"
        case .hardestCards: "hardest"
        case .newCardsOnly: "new"
        case .reviewAhead: "ahead"
        case .randomMix: "random"
        }
    }
}

// MARK: - Card Limit

enum CardLimit: String, Sendable, CaseIterable, Identifiable {
    case ten = "10"
    case twentyFive = "25"
    case fifty = "50"
    case all = "All"

    var id: String { rawValue }

    var intValue: Int {
        switch self {
        case .ten: 10
        case .twentyFive: 25
        case .fifty: 50
        case .all: 100
        }
    }
}

// MARK: - Card Type Filter

enum CardTypeFilter: String, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case words = "Words"
    case phrases = "Phrases"
    case sentences = "Sentences"

    var id: String { rawValue }

    /// Maps to the backend API `CardTypeFilter` value, nil for "All".
    var apiValue: String? {
        switch self {
        case .all: nil
        case .words: "word"
        case .phrases: "phrase"
        case .sentences: "sentence"
        }
    }
}

// MARK: - Session Record

/// A record of a past flashcard review session.
struct SessionRecord: Identifiable, Sendable {
    let id: String
    let date: Date
    let type: String
    let tag: String?
    let correct: Int
    let total: Int
    let durationMinutes: Int
    let accuracy: Double

    /// Creates a SessionRecord from a StudySessionResponse API response.
    init(from session: StudySessionResponse) {
        self.id = session.id
        // Parse ISO 8601 date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.date = formatter.date(from: session.createdAt)
            ?? ISO8601DateFormatter().date(from: session.createdAt)
            ?? Date()
        self.type = session.mode.replacingOccurrences(of: "_", with: " ").capitalized
        self.tag = session.cardTypeFilter
        self.correct = session.correctCount
        self.total = session.totalCards
        self.durationMinutes = (session.durationSeconds ?? 0) / 60
        let totalCards = session.totalCards
        self.accuracy = totalCards > 0
            ? Double(session.correctCount) / Double(totalCards)
            : 0
    }

    /// Internal initializer for mock data.
    init(
        id: String,
        date: Date,
        type: String,
        tag: String?,
        correct: Int,
        total: Int,
        durationMinutes: Int,
        accuracy: Double
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.tag = tag
        self.correct = correct
        self.total = total
        self.durationMinutes = durationMinutes
        self.accuracy = accuracy
    }
}

// MARK: - Activity Day

/// A single day in the activity grid.
struct ActivityDay: Identifiable, Sendable {
    let id: String
    let date: Date
    let isActive: Bool
    let isToday: Bool
}

// MARK: - Forecast Day

/// A day in the review forecast calendar.
struct ForecastDay: Identifiable, Sendable {
    let id: String
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    /// 0 = none, 1 = low, 2 = medium, 3 = high
    let intensity: Int
}

// MARK: - Accuracy Session

/// A recent accuracy session entry for the statistics hub.
struct AccuracySession: Identifiable, Sendable {
    let id: String
    let date: String
    let details: String
    let percentage: Int
}

// MARK: - Flashcard View Model

@MainActor
@Observable
final class FlashcardViewModel {

    // MARK: - Stats (populated from API)

    var wordCount: Int = 0
    var phraseCount: Int = 0
    var sentenceCount: Int = 0

    // MARK: - Due Today

    var dueTotal: Int = 0
    var dueWords: Int = 0
    var duePhrases: Int = 0
    var dueSentences: Int = 0

    // MARK: - Streak

    var streakDays: Int = 0

    // MARK: - Learning Velocity

    var velocityHeadline: String = "Loading..."
    var velocityInsight: String = ""
    var velocityDataPoints: [CGFloat] = []

    // MARK: - Accuracy

    var accuracyPercentage: Int = 0
    var accuracyTrend: String = ""
    var recentAccuracySessions: [AccuracySession] = []

    // MARK: - Time Spent

    var timeSpentMinutes: Int = 0
    var timeAverage: String = ""
    var weeklyTimeData: [CGFloat] = [0, 0, 0, 0, 0, 0, 0]

    // MARK: - Mastery Breakdown

    var masteryPercentage: Int = 0
    var masteredCount: Int = 0
    var knownCount: Int = 0
    var learningCount: Int = 0
    var newCount: Int = 0

    // MARK: - Review Forecast

    var forecastMonth: String = ""
    private var forecastData: [ForecastDayResponse] = []

    // MARK: - Activity Grid

    var activityGrid: [[ActivityDay]] = []

    // MARK: - Review State

    var cards: [FlashcardItem] = []
    var currentCardIndex: Int = 0
    var isShowingBack: Bool = false
    var answersCorrect: Int = 0
    var answersWrong: Int = 0
    var reviewCompleted: Bool = false

    // MARK: - Custom Study

    var selectedMode: CustomStudyMode = .dailyReview
    var selectedLimit: CardLimit = .twentyFive
    var selectedType: CardTypeFilter = .all
    var isCustomStudyPresented: Bool = false

    // MARK: - Past Sessions

    var pastSessions: [SessionRecord] = []
    var selectedSession: SessionRecord? = nil
    var isSessionDetailPresented: Bool = false

    // MARK: - Active Flag

    var activeFlag: String = ""

    // MARK: - Loading State

    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Session Tracking

    private var activeSessionId: String?
    private var sessionStartTime: Date?

    // MARK: - Dependencies

    private let flashcardService: FlashcardService

    // MARK: - Init

    init(flashcardService: FlashcardService = .shared) {
        self.flashcardService = flashcardService
        // Set forecast month to current month
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        forecastMonth = formatter.string(from: Date())
    }

    // MARK: - Computed

    var currentCard: FlashcardItem? {
        guard currentCardIndex < cards.count else { return nil }
        return cards[currentCardIndex]
    }

    var totalCards: Int {
        cards.count
    }

    var reviewProgress: Double {
        guard totalCards > 0 else { return 0 }
        return Double(currentCardIndex) / Double(totalCards)
    }

    var counterLabel: String {
        "\(currentCardIndex + 1)/\(totalCards)"
    }

    var masteryTotal: Int {
        masteredCount + knownCount + learningCount + newCount
    }

    var masteredFraction: CGFloat {
        guard masteryTotal > 0 else { return 0 }
        return CGFloat(masteredCount) / CGFloat(masteryTotal)
    }

    var knownFraction: CGFloat {
        guard masteryTotal > 0 else { return 0 }
        return CGFloat(knownCount) / CGFloat(masteryTotal)
    }

    var learningFraction: CGFloat {
        guard masteryTotal > 0 else { return 0 }
        return CGFloat(learningCount) / CGFloat(masteryTotal)
    }

    var newFraction: CGFloat {
        guard masteryTotal > 0 else { return 0 }
        return CGFloat(newCount) / CGFloat(masteryTotal)
    }

    // MARK: - Grouped Past Sessions

    var groupedSessions: [(String, [SessionRecord])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var groups: [String: [SessionRecord]] = [:]
        var order: [String] = []

        for session in pastSessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            let label: String
            if sessionDay == today {
                label = "TODAY"
            } else if sessionDay == yesterday {
                label = "YESTERDAY"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d"
                label = formatter.string(from: session.date).uppercased()
            }

            if groups[label] == nil {
                order.append(label)
            }
            groups[label, default: []].append(session)
        }

        return order.compactMap { key in
            guard let sessions = groups[key] else { return nil }
            return (key, sessions)
        }
    }

    // MARK: - Data Loading

    /// Loads all hub data: stats, due cards, sessions, activity grid.
    func loadAllData() async {
        isLoading = true
        errorMessage = nil

        async let statsTask: () = loadStats()
        async let dueTask: () = loadDueCards()
        async let sessionsTask: () = loadSessions()

        _ = await (statsTask, dueTask, sessionsTask)

        isLoading = false
    }

    /// Loads flashcard statistics from the API.
    func loadStats() async {
        do {
            let stats = try await flashcardService.getStats()
            applyStats(stats)
        } catch {
            print("[FlashcardVM] Failed to load stats: \(error)")
        }

        // Also load vocabulary counts
        do {
            let vocabStats = try await flashcardService.getVocabularyStats()
            wordCount = vocabStats.words
            phraseCount = vocabStats.phrases
            sentenceCount = vocabStats.sentences
        } catch {
            print("[FlashcardVM] Failed to load vocab stats: \(error)")
        }
    }

    /// Loads due cards from the API.
    func loadDueCards() async {
        do {
            let response = try await flashcardService.getDueCards(
                mode: selectedMode.apiMode,
                type: selectedType.apiValue,
                limit: selectedLimit.intValue
            )
            dueTotal = response.totalDue
            cards = response.items.map { FlashcardItem(from: $0) }

            // Calculate per-type due counts
            dueWords = response.items.filter { $0.type.lowercased() == "word" }.count
            duePhrases = response.items.filter { $0.type.lowercased() == "phrase" }.count
            dueSentences = response.items.filter { $0.type.lowercased() == "sentence" }.count
        } catch {
            print("[FlashcardVM] Failed to load due cards: \(error)")
        }
    }

    /// Loads past sessions from the API.
    func loadSessions() async {
        do {
            let response = try await flashcardService.listSessions(limit: 20)
            pastSessions = response.items.map { SessionRecord(from: $0) }
        } catch {
            print("[FlashcardVM] Failed to load sessions: \(error)")
        }
    }

    // MARK: - Review Actions

    func flipCard() {
        isShowingBack.toggle()
    }

    func answerCorrect() {
        submitReview(quality: 3)
        answersCorrect += 1
        advanceCard()
    }

    func answerWrong() {
        submitReview(quality: 1)
        answersWrong += 1
        advanceCard()
    }

    func startReview() {
        currentCardIndex = 0
        isShowingBack = false
        answersCorrect = 0
        answersWrong = 0
        reviewCompleted = false
        sessionStartTime = Date()

        // Create a session on the backend
        Task {
            await createStudySession()
            // Reload due cards for the selected mode
            await loadDueCards()
        }
    }

    func selectSession(_ session: SessionRecord) {
        selectedSession = session
        isSessionDetailPresented = true
    }

    // MARK: - Session Management

    /// Creates a study session on the backend.
    private func createStudySession() async {
        do {
            let session = try await flashcardService.createSession(
                mode: selectedMode.apiMode,
                cardLimit: selectedLimit.intValue,
                cardTypeFilter: selectedType.apiValue
            )
            activeSessionId = session.id
        } catch {
            print("[FlashcardVM] Failed to create session: \(error)")
        }
    }

    /// Completes the active study session.
    func completeStudySession() async {
        guard let sessionId = activeSessionId else { return }

        let duration: Int
        if let start = sessionStartTime {
            duration = Int(Date().timeIntervalSince(start))
        } else {
            duration = 0
        }

        do {
            _ = try await flashcardService.completeSession(
                id: sessionId,
                durationSeconds: duration
            )
        } catch {
            print("[FlashcardVM] Failed to complete session: \(error)")
        }

        activeSessionId = nil
        sessionStartTime = nil
    }

    // MARK: - Private Helpers

    private func advanceCard() {
        isShowingBack = false
        if currentCardIndex + 1 < cards.count {
            currentCardIndex += 1
        } else {
            reviewCompleted = true
            // Complete the session
            Task {
                await completeStudySession()
            }
        }
    }

    /// Submits a single card review to the backend.
    private func submitReview(quality: Int) {
        guard let card = currentCard else { return }

        Task {
            do {
                _ = try await flashcardService.reviewCard(
                    id: card.id,
                    quality: quality,
                    sessionId: activeSessionId
                )
            } catch {
                print("[FlashcardVM] Failed to submit review for \(card.id): \(error)")
            }
        }
    }

    /// Applies flashcard stats response to view model properties.
    private func applyStats(_ stats: FlashcardStatsResponse) {
        // Mastery breakdown
        masteredCount = stats.masteryBreakdown.mastered
        knownCount = stats.masteryBreakdown.known
        learningCount = stats.masteryBreakdown.learning
        newCount = stats.masteryBreakdown.new
        let total = stats.masteryBreakdown.total
        if total > 0 {
            masteryPercentage = Int(
                Double(stats.masteryBreakdown.mastered + stats.masteryBreakdown.known) / Double(total) * 100
            )
        }

        // Streak
        streakDays = stats.streakData.current

        // Accuracy
        accuracyPercentage = Int(stats.accuracy.accuracyPercentage)
        accuracyTrend = ""

        // Build recent accuracy sessions from past sessions
        let formatter = DateFormatter()
        let calendar = Calendar.current
        recentAccuracySessions = pastSessions.prefix(4).map { session in
            let dateLabel: String
            if calendar.isDateInToday(session.date) {
                dateLabel = "Today"
            } else if calendar.isDateInYesterday(session.date) {
                dateLabel = "Yesterday"
            } else {
                formatter.dateFormat = "MMM d"
                dateLabel = formatter.string(from: session.date)
            }
            return AccuracySession(
                id: session.id,
                date: dateLabel,
                details: "\(session.total) cards, \(session.durationMinutes) min",
                percentage: Int(session.accuracy * 100)
            )
        }

        // Velocity
        let wordsPerDay = stats.velocity.wordsPerDay7d
        velocityHeadline = "You're learning \(String(format: "%.1f", wordsPerDay)) words per day on average"
        velocityInsight = "\(stats.velocity.newWordsThisWeek) new words this week"

        // Time spent
        timeSpentMinutes = stats.timeSpent.totalSeconds / 60
        let avgMinutes = stats.timeSpent.averageSessionSeconds / 60
        timeAverage = "\(String(format: "%.1f", avgMinutes)) min/session average"

        // Forecast
        forecastData = stats.forecast

        // Build activity grid from streak data
        loadActivityGrid()
    }

    private func loadActivityGrid() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var grid: [[ActivityDay]] = Array(repeating: [], count: 7)

        for col in 0..<8 {
            for row in 0..<7 {
                let daysBack = (7 - col) * 7 + (6 - row)
                let date = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
                let isToday = calendar.isDateInToday(date)
                // Show as active if within the streak period or today
                let isActive = isToday || (daysBack > 0 && daysBack <= streakDays)
                grid[row].append(ActivityDay(
                    id: "act_\(row)_\(col)",
                    date: date,
                    isActive: isActive,
                    isToday: isToday
                ))
            }
        }
        activityGrid = grid
    }

    // MARK: - Forecast Data

    func forecastDays() -> [ForecastDay] {
        var days: [ForecastDay] = []
        let calendar = Calendar.current
        let now = Date()

        // Get current month info
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let firstOfMonth = calendar.date(from: components) else { return days }

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        // Monday-start offset: Sunday=7 maps to 6, Monday=1 maps to 0, etc.
        let mondayOffset = (weekday + 5) % 7

        guard let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return days }
        let daysInMonth = range.count
        let todayDay = calendar.component(.day, from: now)

        // Build a lookup from forecast API data
        var forecastLookup: [Int: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        for forecast in forecastData {
            if let date = dateFormatter.date(from: forecast.date) {
                let day = calendar.component(.day, from: date)
                forecastLookup[day] = forecast.count
            }
        }

        // Leading empty cells
        for i in 0..<mondayOffset {
            days.append(ForecastDay(id: "empty_\(i)", dayNumber: 0, isCurrentMonth: false, isToday: false, intensity: 0))
        }

        // Actual days
        for day in 1...daysInMonth {
            let isToday = day == todayDay
            let count = forecastLookup[day] ?? 0
            let intensity: Int
            if day < todayDay {
                intensity = 0
            } else if count == 0 {
                intensity = 0
            } else if count <= 5 {
                intensity = 1
            } else if count <= 15 {
                intensity = 2
            } else {
                intensity = 3
            }
            days.append(ForecastDay(id: "day_\(day)", dayNumber: day, isCurrentMonth: true, isToday: isToday, intensity: intensity))
        }

        // Trailing cells
        let totalCells = days.count
        let remainder = totalCells % 7
        if remainder > 0 {
            for i in 0..<(7 - remainder) {
                days.append(ForecastDay(id: "trail_\(i)", dayNumber: 0, isCurrentMonth: false, isToday: false, intensity: 0))
            }
        }

        return days
    }
}
