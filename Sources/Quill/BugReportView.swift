import SwiftUI
import AppKit

/// Help → Report a Bug…: the writer's words go into a GitHub bug report in their browser, and nothing is sent from here.
struct BugReportView: View {
    @State private var happened = ""
    @State private var steps = ""
    @State private var includeDetails = true
    @State private var crash: CrashReports.Report?
    @State private var crashText: String?
    @State private var crashUnreadable = false
    @State private var copiedCrash = false
    @Environment(\.dismissWindow) private var dismissWindow
    private let details = SystemDetails.current()

    private var link: BugReport.Link {
        BugReport.link(happened: happened, steps: steps, details: includeDetails ? details : nil)
    }
    private var hasText: Bool {
        !happened.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Report a bug").font(.title3.weight(.semibold)).accessibilitySectionHeading()
            Text("Open in GitHub fills in a bug report in your browser. Nothing is sent from Sable; you read it there and choose whether to submit it.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            field("What happened?", text: $happened, height: 84)
            field("Steps to reproduce", text: $steps, height: 84)

            VStack(alignment: .leading, spacing: 3) {
                Toggle("Include my Sable and macOS version and Mac model", isOn: $includeDetails)
                Text(details.summary).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).padding(.leading, 20)
            }

            if let crash { crashSection(crash) }

            if link.shortened {
                Text("That's more than fits in a link, so the end will be cut off with a note. You can paste the rest into the report on GitHub.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("A free GitHub account is needed to submit it.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismissWindow(id: "report-a-bug") }.keyboardShortcut(.cancelAction)
                Button("Open in GitHub") { NSWorkspace.shared.open(link.url) }
                    .keyboardShortcut(.defaultAction).disabled(!hasText)
                    .accessibilityHint("Opens your browser to a bug report with these words filled in")
            }
        }
        .padding(22).frame(width: 520)
        .onAppear { crash = CrashReports.latest() }
    }

    private func field(_ title: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout.weight(.medium))
            TextEditor(text: text)
                .font(.body).scrollContentBackground(.hidden)
                .padding(4).frame(height: height)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.4)))
                .accessibilityLabel(title)
        }
    }

    /// Offered only when Sable crashed in the last week. The report is read, and shown, only when the writer clicks.
    private func crashSection(_ report: CrashReports.Report) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let text = crashText {
                HStack {
                    Text("Latest crash report").font(.callout.weight(.medium))
                    Spacer()
                    Button(copiedCrash ? "Copied" : "Copy Report") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        copiedCrash = true
                        Announce.say("Crash report copied")
                    }
                    Button("Hide") { crashText = nil; copiedCrash = false }
                }
                SelectableText(text: text).frame(height: 150)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.4)))
                    .accessibilityLabel("Latest crash report")
                Text("It can include file paths on your Mac. Nothing is attached for you; paste it into the GitHub report only if you want to.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                HStack {
                    Button("Show Latest Crash Report") {
                        if let text = CrashReports.contents(of: report) { crashText = text; crashUnreadable = false } else { crashUnreadable = true }
                    }
                    Text("Sable closed unexpectedly \(report.date.formatted(.relative(presentation: .named))).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if crashUnreadable {
                    Text("Sable couldn't read that report. You can find it in Console under Crash Reports.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Read-only text the writer can select and copy, without SwiftUI laying out a very long string.
private struct SelectableText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        if let view = scroll.documentView as? NSTextView {
            view.isEditable = false
            view.isSelectable = true
            view.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            view.textContainerInset = NSSize(width: 6, height: 6)
            view.string = text
        }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        if let view = scroll.documentView as? NSTextView, view.string != text { view.string = text }
    }
}
