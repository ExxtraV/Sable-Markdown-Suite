import SwiftUI
import Charts

/// Settings for a goal with a deadline, and a quiet look at how it's going. There's one goal at a time; clearing it
/// leaves the writing record alone.
struct WritingGoalSection: View {
    @AppStorage(WritingGoal.enabledKey) private var enabled = false
    @AppStorage(WritingGoal.storageKey) private var stored = ""
    @AppStorage(WritingGoal.showInFooterKey) private var showInFooter = false
    @State private var editing = false
    @State private var draft = WritingGoal.custom()
    @State private var history: [String: Int] = [:]
    @State private var today = Date()

    private var goal: WritingGoal? { WritingGoal.decode(stored) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Track a goal with a deadline", isOn: $enabled)
            if enabled {
                if let goal, !editing {
                    progressView(goal)
                } else if editing {
                    editor
                } else {
                    Text("For a challenge like 50,000 words in November. Set a number of words and the dates to write them between.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button("November: 50,000 words") { stored = WritingGoal.november().encoded; reload() }
                        Button("Custom…") { draft = WritingGoal.custom(); editing = true }
                    }
                }
                Toggle("Show today's share in the footer", isOn: $showInFooter)
                    .disabled(goal == nil)
                Text("Counts words you add as you write, never words you remove, so a rough day takes nothing away. Kept only on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Off. No goal shows in Settings or while you write. A goal you set earlier is kept, and comes back if you turn this on.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .task { reload() }
        .onChange(of: enabled) { _, on in if !on { editing = false } else { reload() } }
    }

    private func progressView(_ goal: WritingGoal) -> some View {
        let progress = goal.progress(history: history, today: today)
        let points = goal.series(history: history, today: today)
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(goal.words.formatted()) words, \(Self.dateText(goal.start)) to \(Self.dateText(goal.end))").font(.callout.weight(.medium))
            Text(WritingGoal.summary(progress)).font(.callout)

            Chart {
                ForEach(points) { point in
                    LineMark(x: .value("Day", point.date, unit: .day), y: .value("Words", point.pace), series: .value("Line", "Pace"))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                ForEach(points) { point in
                    if let written = point.written {
                        LineMark(x: .value("Day", point.date, unit: .day), y: .value("Words", written), series: .value("Line", "Written"))
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
            }
            .chartYScale(domain: 0...max(goal.words, progress.wordsSoFar, 1))
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: max(1, points.count / 4))) { AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
            .frame(height: 130)
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Words written toward the goal, against an even pace")
            .accessibilityValue("\(progress.wordsSoFar.formatted()) of \(goal.words.formatted()) words. The even pace is \(progress.paceWords.formatted()) by the end of today.")

            HStack(spacing: 22) {
                stat("So far", progress.wordsSoFar.formatted())
                switch progress.phase {
                case .upcoming:
                    stat("First day", Self.dateText(goal.start))
                case .active:
                    stat("Pace today", progress.paceWords.formatted())
                case .finished:
                    stat("Pace", progress.paceWords.formatted())
                }
                if progress.phase == .active {
                    stat("Today's target", progress.reached ? "Done" : progress.dailyTarget.formatted())
                }
                stat(progress.phase == .finished ? "Days" : "Days left", progress.phase == .finished ? "\(progress.totalDays)" : "\(progress.daysLeft)")
            }
            HStack {
                Button("Edit Goal…") { draft = goal; editing = true }
                Button("Clear Goal") { stored = ""; reload() }
            }.font(.caption)
            Text("Clearing the goal keeps your writing record.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper("Words: \(draft.words.formatted())", value: $draft.words, in: 1000...WritingGoal.maxWords, step: 1000)
            DatePicker("Start date", selection: dateBinding(\.start), displayedComponents: .date)
            DatePicker("End date", selection: dateBinding(\.end), displayedComponents: .date)
            let days = draft.totalDays()
            if draft.isValid() {
                Text("\(days) \(days == 1 ? "day" : "days"), about \(WritingGoal.Progress.ceilDiv(draft.words, days).formatted()) words a day. Words you write on the start date count, even earlier that day.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(days < 1 ? "The end date needs to be on or after the start date." : "Choose a goal that spans \(WritingGoal.maxDays) days or fewer.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Save Goal") { stored = draft.encoded; editing = false; reload() }
                    .disabled(!draft.isValid())
                Button("Cancel", role: .cancel) { editing = false }
            }
        }
    }

    /// A date picker's date, read from and written back to one of the goal's day keys.
    private func dateBinding(_ path: WritableKeyPath<WritingGoal, String>) -> Binding<Date> {
        Binding(
            get: { WritingHistory.date(from: draft[keyPath: path], calendar: .current) ?? Date() },
            set: { draft[keyPath: path] = WritingHistory.dayKey($0) }
        )
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private static func dateText(_ key: String) -> String {
        WritingHistory.date(from: key, calendar: .current)?.formatted(date: .abbreviated, time: .omitted) ?? key
    }

    private func reload() {
        history = WritingHistory.load()
        today = Date()
    }
}
