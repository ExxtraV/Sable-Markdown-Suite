import SwiftUI
import Charts
import Accessibility

/// A quiet record of how much you've written, day by day. Not a streak — missing a day changes nothing here.
struct WritingRecordSection: View {
    private let span = 30
    @State private var days: [WritingHistory.Day] = []
    @State private var total = 0
    @State private var best: WritingHistory.Day?
    @State private var confirmReset = false

    private var monthWords: Int { days.reduce(0) { $0 + $1.words } }
    private var todayWords: Int { days.last?.words ?? 0 }
    private var hasAnything: Bool { total > 0 }
    private var bestDayText: String {
        guard let best, best.words > 0 else { return "" }
        return " Best day: \(best.words.formatted()) words, \(best.date.formatted(date: .abbreviated, time: .omitted))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasAnything {
                Chart(days) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Words", day.words))
                        .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.accentColor : Color.accentColor.opacity(0.55))
                        .cornerRadius(2)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                .frame(height: 130)
                .padding(.top, 4)
                // A chart can't be read bar by bar quickly, so VoiceOver gets a summary and an audio graph of the days.
                .accessibilityChartDescriptor(RecordChartDescriptor(days: days, summary: WritingHistory.summary(days: days, total: total) + bestDayText))

                HStack(spacing: 22) {
                    stat("Today", todayWords)
                    stat("Last \(span) days", monthWords)
                    stat("All time", total)
                }
                if let best, best.words > 0 {
                    Text("Best day: \(best.words.formatted()) words, \(best.date.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Nothing recorded yet. Write a little, and today will show up here.").font(.callout).foregroundStyle(.secondary)
            }
            Text("Counts words you add as you write, never words you remove. Kept only on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            if hasAnything {
                Button("Clear Writing Record…") { confirmReset = true }.font(.caption)
            }
        }
        .task { reload() }
        .confirmationDialog("Clear your writing record?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Clear It", role: .destructive) { WritingHistory.reset(); reload() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This can't be undone. Your files and their word counts are untouched — only this record of days and totals is removed.") }
    }

    private func stat(_ label: String, _ words: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(words.formatted()).font(.callout.weight(.medium)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func reload() {
        days = WritingHistory.recent(days: span)
        total = WritingHistory.total()
        best = WritingHistory.best()
    }
}

/// The writing record as VoiceOver's audio graph: one point per day, with a plain-language summary to start from.
private struct RecordChartDescriptor: AXChartDescriptorRepresentable {
    let days: [WritingHistory.Day]
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = days.map { $0.date.formatted(date: .abbreviated, time: .omitted) }
        let top = Double(max(1, days.map(\.words).max() ?? 1))
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Day", categoryOrder: labels)
        let yAxis = AXNumericDataAxisDescriptor(title: "Words written", range: 0...top, gridlinePositions: []) { "\(Int($0)) words" }
        let series = AXDataSeriesDescriptor(name: "Words written each day", isContinuous: false,
                                            dataPoints: zip(labels, days).map { AXDataPoint(x: $0.0, y: Double($0.1.words)) })
        return AXChartDescriptor(title: "Words written each day, last \(days.count) days", summary: summary,
                                 xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        descriptor.summary = summary
    }
}
