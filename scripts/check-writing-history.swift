import Foundation

@main enum WritingHistoryChecks {
    static func main() {
        let defaults = UserDefaults(suiteName: "quill-history-checks-\(getpid())")!
        defaults.removePersistentDomain(forName: "quill-history-checks-\(getpid())")
        let calendar = Calendar(identifier: .gregorian)
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d))! }

        precondition(WritingHistory.total(defaults: defaults) == 0, "Nothing recorded at first")
        precondition(WritingHistory.add(0, on: date(2026, 3, 1), calendar: calendar, defaults: defaults) == 0, "Zero does nothing")
        precondition(WritingHistory.add(-5, on: date(2026, 3, 1), calendar: calendar, defaults: defaults) == 0, "Negative does nothing")
        _ = WritingHistory.add(120, on: date(2026, 3, 1), calendar: calendar, defaults: defaults)
        let after = WritingHistory.add(80, on: date(2026, 3, 1), calendar: calendar, defaults: defaults)
        precondition(after == 200, "Same day adds up: \(after)")
        _ = WritingHistory.add(300, on: date(2026, 3, 3), calendar: calendar, defaults: defaults)
        precondition(WritingHistory.total(defaults: defaults) == 500, "Total across days")

        let recent = WritingHistory.recent(days: 5, today: date(2026, 3, 3), calendar: calendar, defaults: defaults)
        precondition(recent.count == 5, "Five days requested")
        precondition(recent.map(\.words) == [0, 0, 200, 0, 300], "Missing days are filled with zero, oldest first: \(recent.map(\.words))")
        precondition(recent.last?.date == date(2026, 3, 3), "The last day is today")
        precondition(WritingHistory.recent(days: 1, today: date(2026, 3, 3), calendar: calendar, defaults: defaults).map(\.words) == [300], "One day is just today")
        precondition(WritingHistory.recent(days: 0, today: date(2026, 3, 3), calendar: calendar, defaults: defaults).isEmpty)

        let best = WritingHistory.best(defaults: defaults, calendar: calendar)
        precondition(best?.words == 300 && best?.date == date(2026, 3, 3), "Best day: \(String(describing: best))")
        precondition(WritingHistory.activeDays(defaults: defaults) == 2, "Two days have anything on them")

        // The key format round-trips through a month and year boundary
        _ = WritingHistory.add(10, on: date(2025, 12, 31), calendar: calendar, defaults: defaults)
        _ = WritingHistory.add(10, on: date(2026, 1, 1), calendar: calendar, defaults: defaults)
        let wrap = WritingHistory.recent(days: 3, today: date(2026, 1, 1), calendar: calendar, defaults: defaults)
        precondition(wrap.map(\.words) == [0, 10, 10], "New Year's Eve and Day are both counted, in order: \(wrap.map(\.words))")

        WritingHistory.reset(defaults: defaults)
        precondition(WritingHistory.total(defaults: defaults) == 0 && WritingHistory.best(defaults: defaults) == nil, "Reset clears everything")

        goalChecks(defaults: defaults)

        defaults.removePersistentDomain(forName: "quill-history-checks-\(getpid())")
        print("Passed: writing history (adding, same-day totals, filled ranges, best day, active days, boundaries, reset) and writing goals (pace math, date edges, presets, storage).")
    }

    static func makeCalendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    static func goalChecks(defaults: UserDefaults) {
        let ny = makeCalendar("America/New_York")
        func at(_ c: Calendar, _ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ s: Int = 0) -> Date {
            c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi, second: s))!
        }
        func key(_ y: Int, _ m: Int, _ d: Int) -> String { String(format: "%04d-%02d-%02d", y, m, d) }
        let november = WritingGoal(words: 50_000, start: "2026-11-01", end: "2026-11-30")

        // Shape: both ends count
        precondition(november.totalDays(calendar: ny) == 30, "November is 30 days")
        precondition(WritingGoal(words: 10, start: "2026-11-05", end: "2026-11-05").totalDays(calendar: ny) == 1, "One day goal")
        precondition(WritingGoal(words: 10, start: "2026-11-05", end: "2026-11-04").totalDays(calendar: ny) == 0, "Backwards is nothing")
        precondition(WritingGoal(words: 10, start: "2028-02-01", end: "2028-02-29").totalDays(calendar: ny) == 29, "Leap February")
        precondition(WritingGoal(words: 10, start: "2026-12-15", end: "2027-01-14").totalDays(calendar: ny) == 31, "Across New Year")

        // Day one, goal set mid-day: everything written that day counts, including words from before it was set
        let first = november.progress(history: ["2026-11-01": 1204], today: at(ny, 2026, 11, 1, 15, 30), calendar: ny)
        precondition(first.phase == .active && first.dayNumber == 1 && first.daysLeft == 30, "Day one: \(first)")
        precondition(first.wordsSoFar == 1204 && first.wordsToday == 1204, "Words from earlier that day count: \(first)")
        precondition(first.dailyTarget == 1667 && first.paceWords == 1667, "50,000 over 30 days is 1,667 a day: \(first)")
        precondition(first.leftToday == 463 && !first.reached && first.onPace, "Left today: \(first)")
        precondition(WritingGoal.footerText(first) == "\(1204.formatted()) / \(1667.formatted()) today", "Footer: \(String(describing: WritingGoal.footerText(first)))")
        let morning = november.progress(history: [:], today: at(ny, 2026, 11, 1, 0, 0, 1), calendar: ny)
        precondition(morning.wordsSoFar == 0 && morning.dailyTarget == 1667 && morning.leftToday == 1667, "Nothing written yet: \(morning)")

        // Day two: the target is worked out from words before today, so writing today doesn't move it
        let d2 = november.progress(history: ["2026-11-01": 1000, "2026-11-02": 300], today: at(ny, 2026, 11, 2), calendar: ny)
        precondition(d2.dayNumber == 2 && d2.daysLeft == 29 && d2.wordsSoFar == 1300 && d2.wordsToday == 300, "Day two: \(d2)")
        precondition(d2.dailyTarget == 1690, "49,000 over 29 days rounds up to 1,690: \(d2.dailyTarget)")
        precondition(d2.paceWords == 3334, "Pace line at the end of day two: \(d2.paceWords)")
        let d2more = november.progress(history: ["2026-11-01": 1000, "2026-11-02": 2400], today: at(ny, 2026, 11, 2, 22), calendar: ny)
        precondition(d2more.dailyTarget == 1690 && d2more.wordsSoFar == 3400, "Writing more today leaves today's target alone: \(d2more)")

        // Behind, on pace, ahead, done. Behind is a number, not a verdict.
        let behind = november.progress(history: ["2026-11-01": 12_000], today: at(ny, 2026, 11, 11), calendar: ny)
        precondition(behind.dayNumber == 11 && behind.daysLeft == 20 && behind.dailyTarget == 1900, "38,000 over 20 days: \(behind)")
        precondition(!behind.onPace, "More than the even share is not on pace")
        precondition(WritingGoal.summary(behind) == "\(1900.formatted()) a day finishes on time.", "Neutral behind message: \(WritingGoal.summary(behind))")
        let lowered = WritingGoal.summary(behind).lowercased()
        for word in ["behind", "late", "miss", "fail", "catch up", "streak", "lost"] { precondition(!lowered.contains(word), "No guilt words: \(lowered)") }
        let steady = november.progress(history: ["2026-11-01": 18_337], today: at(ny, 2026, 11, 11), calendar: ny)
        precondition(steady.onPace && steady.dailyTarget == 1584, "On pace: \(steady)")
        precondition(WritingGoal.summary(steady).hasPrefix("On pace."), "On pace message: \(WritingGoal.summary(steady))")
        let ahead = november.progress(history: ["2026-11-01": 40_000], today: at(ny, 2026, 11, 11), calendar: ny)
        precondition(ahead.onPace && ahead.dailyTarget == 500, "Ahead: \(ahead)")
        let done = november.progress(history: ["2026-11-01": 50_000], today: at(ny, 2026, 11, 11), calendar: ny)
        precondition(done.reached && done.dailyTarget == 0 && done.leftToday == 0, "Reached: \(done)")
        precondition(WritingGoal.footerText(done) == "0 today · goal reached", "Reached footer: \(String(describing: WritingGoal.footerText(done)))")
        precondition(WritingGoal.summary(done) == "Goal reached. Anything more is a bonus.", WritingGoal.summary(done))
        let overshoot = november.progress(history: ["2026-11-01": 49_000, "2026-11-11": 2_000], today: at(ny, 2026, 11, 11), calendar: ny)
        precondition(overshoot.reached && overshoot.dailyTarget == 50, "Reaching it during today: target came from before today: \(overshoot)")

        // Only forward progress: stored zeros and negatives add nothing and take nothing away
        let damaged = november.progress(history: ["2026-11-01": 500, "2026-11-02": -900, "2026-11-03": 0], today: at(ny, 2026, 11, 3), calendar: ny)
        precondition(damaged.wordsSoFar == 500, "Negative days are ignored: \(damaged)")

        // The window: words outside it never count
        let outside = november.progress(history: ["2026-10-31": 9_000, "2026-11-01": 100, "2026-12-01": 9_000], today: at(ny, 2026, 11, 2), calendar: ny)
        precondition(outside.wordsSoFar == 100, "Words before the start and after the end are not counted: \(outside)")

        // The end date itself is still a day of the goal, all the way to its last second
        let lastMorning = november.progress(history: ["2026-11-01": 40_000, "2026-11-30": 2_000], today: at(ny, 2026, 11, 30, 0, 0, 0), calendar: ny)
        let lastNight = november.progress(history: ["2026-11-01": 40_000, "2026-11-30": 2_000], today: at(ny, 2026, 11, 30, 23, 59, 59), calendar: ny)
        for p in [lastMorning, lastNight] {
            precondition(p.phase == .active && p.dayNumber == 30 && p.daysLeft == 1, "The end date is the last day: \(p)")
            precondition(p.paceWords == 50_000 && p.dailyTarget == 10_000 && p.wordsSoFar == 42_000, "Last day: \(p)")
        }
        let after = november.progress(history: ["2026-11-01": 40_000, "2026-11-30": 2_000, "2026-12-01": 500], today: at(ny, 2026, 12, 1, 0, 0, 1), calendar: ny)
        precondition(after.phase == .finished && after.daysLeft == 0 && after.wordsSoFar == 42_000, "The day after: \(after)")
        precondition(WritingGoal.footerText(after) == nil, "Nothing in the footer once it's over")
        precondition(WritingGoal.summary(after) == "The goal ended at \(42_000.formatted()) of \(50_000.formatted()) words.", WritingGoal.summary(after))
        let won = november.progress(history: ["2026-11-20": 50_100], today: at(ny, 2026, 12, 15), calendar: ny)
        precondition(won.reached && WritingGoal.summary(won) == "Goal reached: \(50_100.formatted()) words.", WritingGoal.summary(won))

        // Before the start
        let twoOut = november.progress(history: ["2026-10-30": 700], today: at(ny, 2026, 10, 30, 8), calendar: ny)
        precondition(twoOut.phase == .upcoming(daysUntilStart: 2) && twoOut.wordsSoFar == 0 && twoOut.daysLeft == 30, "Two days out: \(twoOut)")
        let lateEve = november.progress(history: [:], today: at(ny, 2026, 10, 31, 23, 30), calendar: ny)
        precondition(lateEve.phase == .upcoming(daysUntilStart: 1), "The night before: \(lateEve)")
        precondition(WritingGoal.footerText(lateEve) == nil, "No footer before the start")
        precondition(WritingGoal.summary(twoOut) == "Starts in 2 days. \(1667.formatted()) a day finishes on time.", WritingGoal.summary(twoOut))

        // One-day goal
        let single = WritingGoal(words: 800, start: "2026-11-05", end: "2026-11-05")
        let singleDay = single.progress(history: ["2026-11-05": 300], today: at(ny, 2026, 11, 5), calendar: ny)
        precondition(singleDay.daysLeft == 1 && singleDay.dailyTarget == 800 && singleDay.paceWords == 800 && singleDay.leftToday == 500, "One day: \(singleDay)")

        // Daylight saving. NY falls back on 2026-11-01 (25-hour day) and springs forward on 2026-03-08 (23-hour day).
        let fall = november.progress(history: [:], today: at(ny, 2026, 11, 1, 23, 30), calendar: ny)
        precondition(fall.dayNumber == 1 && fall.daysLeft == 30, "The 25-hour day is still one day: \(fall)")
        let afterFall = november.progress(history: [:], today: at(ny, 2026, 11, 2, 0, 30), calendar: ny)
        precondition(afterFall.dayNumber == 2 && afterFall.daysLeft == 29, "The day after the 25-hour day: \(afterFall)")
        let march = WritingGoal(words: 31_000, start: "2026-03-01", end: "2026-03-31")
        precondition(march.totalDays(calendar: ny) == 31, "March 2026 is 31 days through the spring change")
        let spring = march.progress(history: [:], today: at(ny, 2026, 3, 8, 23, 30), calendar: ny)
        let afterSpring = march.progress(history: [:], today: at(ny, 2026, 3, 9, 0, 10), calendar: ny)
        precondition(spring.dayNumber == 8 && spring.paceWords == 8_000, "The 23-hour day: \(spring)")
        precondition(afterSpring.dayNumber == 9 && afterSpring.daysLeft == 23 && afterSpring.paceWords == 9_000, "After the spring change: \(afterSpring)")
        let sydney = makeCalendar("Australia/Sydney") // falls back 2026-04-05, inside this goal
        let aus = WritingGoal(words: 3_000, start: "2026-04-01", end: "2026-04-10")
        let ausDay = aus.progress(history: [:], today: at(sydney, 2026, 4, 6, 0, 5), calendar: sydney)
        precondition(aus.totalDays(calendar: sydney) == 10 && ausDay.dayNumber == 6 && ausDay.daysLeft == 5, "Southern hemisphere: \(ausDay)")
        // A zone where a day has no midnight (São Paulo started summer time at 00:00 on 2018-11-04): the day still counts once
        let sp = makeCalendar("America/Sao_Paulo")
        let spGoal = WritingGoal(words: 3_000, start: "2018-11-01", end: "2018-11-30")
        precondition(spGoal.totalDays(calendar: sp) == 30, "No-midnight zone keeps 30 days")
        let spDay = spGoal.progress(history: [:], today: at(sp, 2018, 11, 4, 0, 30), calendar: sp)
        precondition(spDay.dayNumber == 4 && spDay.daysLeft == 27, "The day with no midnight: \(spDay)")
        let spSeries = spGoal.series(history: [:], today: at(sp, 2018, 11, 10), calendar: sp)
        precondition(Set(spSeries.map { WritingHistory.dayKey($0.date, calendar: sp) }).count == 30, "Thirty distinct days in the chart")
        // The same instant is a different goal day in different zones, as it should be for a calendar-day goal
        let moment = at(makeCalendar("Pacific/Auckland"), 2026, 11, 2, 0, 30)
        precondition(november.progress(history: [:], today: moment, calendar: makeCalendar("Pacific/Auckland")).dayNumber == 2, "Auckland is on day two")
        precondition(november.progress(history: [:], today: moment, calendar: ny).dayNumber == 1, "New York is still on day one")

        // Chart series
        let points = november.series(history: ["2026-11-01": 1000, "2026-11-03": 500], today: at(ny, 2026, 11, 3), calendar: ny)
        precondition(points.count == 30, "One point per day")
        precondition(points.prefix(3).map(\.written) == [1000, 1000, 1500], "Running total: \(points.prefix(3).map(\.written))")
        precondition(points.dropFirst(3).allSatisfy { $0.written == nil }, "Nothing plotted for days to come")
        precondition(points.last?.pace == 50_000 && abs((points.first?.pace ?? 0) - 50_000.0 / 30) < 0.001, "The pace line is straight, ending at the goal")
        precondition(points.first?.date == ny.startOfDay(for: at(ny, 2026, 11, 1)) && points.last?.date == ny.startOfDay(for: at(ny, 2026, 11, 30)), "Series spans the goal's dates")
        precondition(points[2].written == november.progress(history: ["2026-11-01": 1000, "2026-11-03": 500], today: at(ny, 2026, 11, 3), calendar: ny).wordsSoFar, "The chart and the numbers agree")
        precondition(november.series(history: [:], today: at(ny, 2026, 11, 3), calendar: ny).compactMap(\.written).allSatisfy { $0 == 0 }, "An empty record plots zero")
        precondition(WritingGoal(words: 10, start: "bad", end: "worse").series(history: [:], calendar: ny).isEmpty, "Unparseable dates plot nothing")

        // Validity and storage
        precondition(november.isValid(calendar: ny), "November is valid")
        precondition(!WritingGoal(words: 0, start: "2026-11-01", end: "2026-11-30").isValid(calendar: ny), "No words is not a goal")
        precondition(!WritingGoal(words: 100, start: "2026-11-30", end: "2026-11-01").isValid(calendar: ny), "Ending before starting is not a goal")
        precondition(!WritingGoal(words: 100, start: "2026-01-01", end: "2027-01-02").isValid(calendar: ny), "More than a year is not a goal")
        precondition(WritingGoal(words: 100, start: "2026-01-01", end: "2026-12-31").isValid(calendar: ny), "A year is fine")
        precondition(!WritingGoal(words: 2_000_000, start: "2026-11-01", end: "2026-11-30").isValid(calendar: ny), "Too many words")
        precondition(WritingGoal.decode("") == nil && WritingGoal.decode("not json") == nil && WritingGoal.decode("{}") == nil, "Damaged text is nothing")
        precondition(WritingGoal.decode(#"{"words":-5,"start":"2026-11-01","end":"2026-11-30"}"#) == nil, "A goal that makes no sense is nothing")
        precondition(WritingGoal.decode(november.encoded) == november, "Round trip")

        let goalDefaults = UserDefaults(suiteName: "quill-goal-checks-\(getpid())")!
        goalDefaults.removePersistentDomain(forName: "quill-goal-checks-\(getpid())")
        precondition(WritingGoal.load(defaults: goalDefaults) == nil, "No goal at first")
        WritingGoal.save(november, defaults: goalDefaults)
        precondition(WritingGoal.load(defaults: goalDefaults) == november, "Saved goal loads")
        goalDefaults.set("garbage", forKey: WritingGoal.storageKey)
        precondition(WritingGoal.load(defaults: goalDefaults) == nil, "A damaged stored goal loads as none")
        // Clearing the goal keeps the history, and clearing the history keeps the goal
        _ = WritingHistory.add(250, on: at(ny, 2026, 11, 1), calendar: ny, defaults: goalDefaults)
        WritingGoal.save(november, defaults: goalDefaults)
        WritingGoal.clear(defaults: goalDefaults)
        precondition(WritingGoal.load(defaults: goalDefaults) == nil && WritingHistory.total(defaults: goalDefaults) == 250, "Clearing the goal keeps the writing record")
        WritingGoal.save(november, defaults: goalDefaults)
        WritingHistory.reset(defaults: goalDefaults)
        precondition(WritingGoal.load(defaults: goalDefaults) == november && WritingHistory.total(defaults: goalDefaults) == 0, "Clearing the record keeps the goal")
        goalDefaults.removePersistentDomain(forName: "quill-goal-checks-\(getpid())")

        // The same numbers from the real stored record, through the same path the app uses
        let live = UserDefaults(suiteName: "quill-goal-live-\(getpid())")!
        live.removePersistentDomain(forName: "quill-goal-live-\(getpid())")
        _ = WritingHistory.add(400, on: at(ny, 2026, 11, 1, 9), calendar: ny, defaults: live)
        _ = WritingHistory.add(300, on: at(ny, 2026, 11, 1, 21), calendar: ny, defaults: live)
        precondition(november.progress(history: WritingHistory.load(defaults: live), today: at(ny, 2026, 11, 1, 22), calendar: ny).wordsSoFar == 700, "Adds through the record")
        live.removePersistentDomain(forName: "quill-goal-live-\(getpid())")

        // Presets
        let nov = WritingGoal.november(today: at(ny, 2026, 9, 30), calendar: ny)
        precondition(nov == november, "The preset from September: \(nov)")
        precondition(WritingGoal.november(today: at(ny, 2026, 11, 15), calendar: ny) == november, "Mid-November still means this one")
        precondition(WritingGoal.november(today: at(ny, 2026, 11, 30, 23, 59), calendar: ny) == november, "Its last day still means this one")
        let next = WritingGoal.november(today: at(ny, 2026, 12, 1), calendar: ny)
        precondition(next == WritingGoal(words: 50_000, start: "2027-11-01", end: "2027-11-30"), "From December it means next year: \(next)")
        precondition(november.isValid(calendar: ny) && next.isValid(calendar: ny), "Presets are valid goals")
        let custom = WritingGoal.custom(today: at(ny, 2026, 3, 1, 10), calendar: ny)
        precondition(custom.start == "2026-03-01" && custom.end == "2026-03-30" && custom.isValid(calendar: ny), "Custom starts today: \(custom)")
        precondition(WritingGoal.custom(today: at(ny, 2026, 3, 8, 10), calendar: ny).end == "2026-04-06", "Custom runs through the spring change")
    }
}
