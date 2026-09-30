import Foundation

/// A word goal with a deadline, for "50,000 words in November" and similar challenges. It is built on the daily
/// writing record and adds nothing to it: progress is just the words the record already holds for the goal's days,
/// so it counts only words added and never takes anything back for deletions.
///
/// Days are calendar days, stored as the same "yyyy-MM-dd" keys the record uses. That keeps the math the same across
/// a daylight-saving change or a trip to another time zone: the goal is a run of dates, not a span of hours. Every word
/// written on the start date counts, including words written before the goal was set that day.
struct WritingGoal: Codable, Equatable {
    var words: Int
    /// First day of the goal, as a day key.
    var start: String
    /// Last day of the goal, inclusive, as a day key.
    var end: String

    static let storageKey = "writingGoal"
    static let showInFooterKey = "showGoalInFooter"
    /// The master switch. Off by default: until a writer turns it on, nothing about goals appears anywhere.
    static let enabledKey = "writingGoalEnabled"
    static let maxWords = 1_000_000
    /// A year is plenty for a challenge, and it keeps the chart to a size that reads.
    static let maxDays = 366

    // MARK: Storage

    /// Reads a stored goal, or nil for nothing stored, damaged text, or a goal that no longer makes sense.
    static func decode(_ stored: String) -> WritingGoal? {
        guard let data = stored.data(using: .utf8),
              let goal = try? JSONDecoder().decode(WritingGoal.self, from: data),
              goal.isValid() else { return nil }
        return goal
    }

    var encoded: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    static func load(defaults: UserDefaults = .standard) -> WritingGoal? {
        defaults.string(forKey: storageKey).flatMap(decode)
    }

    static func save(_ goal: WritingGoal, defaults: UserDefaults = .standard) {
        defaults.set(goal.encoded, forKey: storageKey)
    }

    /// Clears the goal and nothing else: the writing record is untouched.
    static func clear(defaults: UserDefaults = .standard) { defaults.removeObject(forKey: storageKey) }

    // MARK: Shape

    /// Whole calendar days from `start` through `end`, counting both. Zero for dates that don't parse or run backwards.
    func totalDays(calendar: Calendar = .current) -> Int {
        guard let first = WritingHistory.date(from: start, calendar: calendar),
              let last = WritingHistory.date(from: end, calendar: calendar) else { return 0 }
        return max(0, Self.daysBetween(first, last, calendar: calendar) + 1)
    }

    func isValid(calendar: Calendar = .current) -> Bool {
        let days = totalDays(calendar: calendar)
        return words > 0 && words <= Self.maxWords && days >= 1 && days <= Self.maxDays
    }

    /// Calendar days from one date to another. Uses calendar arithmetic, not seconds, so a 23- or 25-hour day is still one day.
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    // MARK: Presets

    /// "November: 50,000 words", for the coming November, or the current one while it's still going.
    static func november(today: Date = Date(), calendar: Calendar = .current) -> WritingGoal {
        let year = calendar.component(.year, from: today)
        let thisYear = WritingGoal(words: 50_000, start: String(format: "%04d-11-01", year), end: String(format: "%04d-11-30", year))
        if WritingHistory.dayKey(today, calendar: calendar) <= thisYear.end { return thisYear }
        return WritingGoal(words: 50_000, start: String(format: "%04d-11-01", year + 1), end: String(format: "%04d-11-30", year + 1))
    }

    /// A starting point for a custom goal: today through the next 30 days.
    static func custom(today: Date = Date(), calendar: Calendar = .current) -> WritingGoal {
        let last = calendar.date(byAdding: .day, value: 29, to: calendar.startOfDay(for: today)) ?? today
        return WritingGoal(words: 20_000, start: WritingHistory.dayKey(today, calendar: calendar), end: WritingHistory.dayKey(last, calendar: calendar))
    }

    // MARK: Progress

    enum Phase: Equatable {
        /// Today is before the start date.
        case upcoming(daysUntilStart: Int)
        case active
        /// Today is after the end date.
        case finished
    }

    struct Progress: Equatable {
        let phase: Phase
        let goal: Int
        let totalDays: Int
        /// Which day of the goal today is, 1-based. 0 before the goal starts; the last day's number after it ends.
        let dayNumber: Int
        /// Days remaining including today. On the last day it's 1; after the end it's 0.
        let daysLeft: Int
        /// Words recorded on the goal's days up to and including today.
        let wordsSoFar: Int
        let wordsToday: Int
        /// Where the straight pace line stands at the end of today, rounded up.
        let paceWords: Int
        /// What today needs to be for the rest of the goal to finish on time, spreading what's left evenly over the days
        /// left. It's worked out from the words written before today, so it holds steady through the day. Zero once the
        /// goal is reached.
        let dailyTarget: Int

        var reached: Bool { wordsSoFar >= goal }
        /// Words still to write today to meet `dailyTarget`.
        var leftToday: Int { max(0, dailyTarget - wordsToday) }
        /// The unchanging share of the goal per day, for comparing `dailyTarget` with.
        var evenDailyShare: Int { Self.ceilDiv(goal, max(1, totalDays)) }
        /// Whether finishing on time still takes no more than the even daily share. Quiet by design: there's no "behind" state.
        var onPace: Bool { dailyTarget <= evenDailyShare }
    }

    /// Everything the views need, from the record's day totals (keyed "yyyy-MM-dd"). Day keys sort the same way dates
    /// do, so the math compares keys and never touches clock arithmetic beyond the calendar-day count.
    func progress(history: [String: Int], today: Date = Date(), calendar: Calendar = .current) -> Progress {
        let total = max(1, totalDays(calendar: calendar))
        let todayKey = WritingHistory.dayKey(today, calendar: calendar)
        func sum(through limit: String) -> Int {
            history.reduce(0) { $1.key >= start && $1.key <= min(end, limit) && $1.value > 0 ? $0 + $1.value : $0 }
        }
        let todayWords = (todayKey >= start && todayKey <= end) ? max(0, history[todayKey] ?? 0) : 0
        let beforeToday = history.reduce(0) { $1.key >= start && $1.key < todayKey && $1.key <= end && $1.value > 0 ? $0 + $1.value : $0 }

        if todayKey < start {
            let first = WritingHistory.date(from: start, calendar: calendar) ?? today
            let until = max(1, Self.daysBetween(today, first, calendar: calendar))
            return Progress(phase: .upcoming(daysUntilStart: until), goal: words, totalDays: total, dayNumber: 0, daysLeft: total,
                            wordsSoFar: 0, wordsToday: 0, paceWords: 0, dailyTarget: Progress.ceilDiv(words, total))
        }
        if todayKey > end {
            return Progress(phase: .finished, goal: words, totalDays: total, dayNumber: total, daysLeft: 0,
                            wordsSoFar: sum(through: end), wordsToday: 0, paceWords: words, dailyTarget: 0)
        }
        let first = WritingHistory.date(from: start, calendar: calendar) ?? today
        let number = min(total, max(1, Self.daysBetween(first, today, calendar: calendar) + 1))
        let left = total - number + 1
        return Progress(phase: .active, goal: words, totalDays: total, dayNumber: number, daysLeft: left,
                        wordsSoFar: beforeToday + todayWords, wordsToday: todayWords,
                        paceWords: Progress.ceilDiv(words * number, total),
                        dailyTarget: Progress.ceilDiv(max(0, words - beforeToday), left))
    }

    /// One day of the goal for the chart.
    struct Point: Identifiable, Equatable {
        var id: Date { date }
        let date: Date
        /// Running total at the end of this day, or nil for days that haven't happened yet.
        let written: Int?
        /// The straight pace line at the end of this day.
        let pace: Double
    }

    /// Every day of the goal, oldest first, for charting the running total against the pace line.
    func series(history: [String: Int], today: Date = Date(), calendar: Calendar = .current) -> [Point] {
        let total = totalDays(calendar: calendar)
        guard total > 0, let first = WritingHistory.date(from: start, calendar: calendar) else { return [] }
        let todayKey = WritingHistory.dayKey(today, calendar: calendar)
        var running = 0
        return (0..<total).compactMap { offset -> Point? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: first)) else { return nil }
            let key = WritingHistory.dayKey(date, calendar: calendar)
            running += max(0, history[key] ?? 0)
            return Point(date: date, written: key <= todayKey ? running : nil, pace: Double(words) * Double(offset + 1) / Double(total))
        }
    }
}

extension WritingGoal.Progress {
    static func ceilDiv(_ a: Int, _ b: Int) -> Int { b <= 0 ? 0 : (a + b - 1) / b }
}

extension WritingGoal {
    /// The footer's "1,204 / 1,667 today", or nil when there's nothing to show (no goal, not started, or over).
    static func footerText(_ progress: Progress) -> String? {
        guard progress.phase == .active else { return nil }
        if progress.reached { return "\(progress.wordsToday.formatted()) today · goal reached" }
        return "\(progress.wordsToday.formatted()) / \(progress.dailyTarget.formatted()) today"
    }

    /// A calm sentence about where things stand. It never says "behind"; when the daily figure is higher than the even
    /// share it just states what finishes on time.
    static func summary(_ p: Progress) -> String {
        switch p.phase {
        case .upcoming(let days):
            return "Starts in \(days) \(days == 1 ? "day" : "days"). \(p.dailyTarget.formatted()) a day finishes on time."
        case .finished:
            return p.reached ? "Goal reached: \(p.wordsSoFar.formatted()) words." : "The goal ended at \(p.wordsSoFar.formatted()) of \(p.goal.formatted()) words."
        case .active:
            if p.reached { return "Goal reached. Anything more is a bonus." }
            return p.onPace ? "On pace. \(p.dailyTarget.formatted()) a day finishes on time." : "\(p.dailyTarget.formatted()) a day finishes on time."
        }
    }
}
