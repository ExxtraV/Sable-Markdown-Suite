import Foundation

// Checks for Help → Report a Bug…: the GitHub link carries the writer's words and nothing else, stays under the length
// limit with a polite note when it has to cut, matches the issue template's fields, and the crash-report finder looks at
// names and dates only. Run from the repository root.

@main enum BugReportChecks {
    static func main() throws {
        try checkLink()
        try checkLength()
        try checkTemplate()
        try checkCrashReports()
        print("bug report checks passed")
    }

    /// The link's fields, decoded the way GitHub reads them.
    static func fields(_ url: URL) -> [String: String] {
        let query = url.absoluteString.components(separatedBy: "?").dropFirst().joined(separator: "?")
        var result: [String: String] = [:]
        for pair in query.components(separatedBy: "&") {
            let parts = pair.components(separatedBy: "=")
            precondition(parts.count == 2, "each field is name=value: \(pair)")
            result[parts[0]] = parts[1].removingPercentEncoding
        }
        return result
    }

    static let details = SystemDetails(sable: "1.0.0-beta.1 (16)", macOS: "macOS 15.1 (24B83)", mac: "Mac14,2, Apple M2")

    static func checkLink() throws {
        let link = BugReport.link(happened: "It crashed & lost \"my\" chapter + notes #1\nSecond line = bad", steps: "1. Open it\n2. Type é 🇨🇦 ~", details: details)
        precondition(link.url.absoluteString.hasPrefix("https://github.com/ExxtraV/Sable-Markdown-Suite/issues/new?template=bug_report.yml&"), "goes to the new-issue form with the bug report template")
        precondition(link.url.scheme == "https" && link.url.host == "github.com", "an https GitHub link")
        precondition(!link.shortened, "short text isn't cut")
        let f = fields(link.url)
        precondition(f["description"] == "It crashed & lost \"my\" chapter + notes #1\nSecond line = bad", "symbols and line breaks survive: \(f["description"] ?? "nil")")
        precondition(f["steps"] == "1. Open it\n2. Type é 🇨🇦 ~", "accents and flags survive")
        precondition(f["sable-version"] == "1.0.0-beta.1 (16)" && f["macos-version"] == "macOS 15.1 (24B83)" && f["mac-model"] == "Mac14,2, Apple M2", "the three details")
        precondition(Set(f.keys) == ["template", "description", "steps", "sable-version", "macos-version", "mac-model"], "nothing else is in the link: \(f.keys.sorted())")
        let raw = link.url.absoluteString
        precondition(!raw.contains(" ") && !raw.contains("\n") && raw.filter({ $0 == "&" }).count == 5 && raw.filter({ $0 == "#" }).isEmpty, "&, #, spaces, and line breaks are encoded")

        // Checkbox off: no details, and empty fields are left out
        let bare = fields(BugReport.link(happened: "  Only this  ", steps: "", details: nil).url)
        precondition(Set(bare.keys) == ["template", "description"] && bare["description"] == "Only this", "version off and steps empty: \(bare)")
        precondition(SystemDetails.current().summary.contains("macOS"), "the real details can be read")
        precondition(BugReport.ideasURL.absoluteString == "https://github.com/ExxtraV/Sable-Markdown-Suite/discussions/categories/ideas", "the Ideas category")
    }

    static func checkLength() throws {
        // Long text is cut to fit, with the note, never in the middle of a character, and the link stays inside the limit
        let sentence = "The chapter vanished after I pressed save, 🇨🇦 and the éclair icon changed. "
        for (a, b) in [(2000, 2000), (50000, 10), (10, 50000), (100000, 100000), (3000, 0), (0, 9000)] {
            let happened = String(repeating: sentence, count: a / sentence.count + (a > 0 ? 1 : 0)).prefix(a)
            let steps = String(repeating: "Then " + sentence, count: b / sentence.count + (b > 0 ? 1 : 0)).prefix(b)
            for withDetails in [true, false] {
                let link = BugReport.link(happened: String(happened), steps: String(steps), details: withDetails ? details : nil)
                let length = link.url.absoluteString.count
                precondition(length <= BugReport.maxLinkLength, "\(a)/\(b): link is \(length)")
                let f = fields(link.url)
                for (key, original) in [("description", String(happened)), ("steps", String(steps))] where !original.isEmpty {
                    guard let text = f[key] else { preconditionFailure("\(a)/\(b): \(key) went missing") }
                    if text != original.trimmingCharacters(in: .whitespacesAndNewlines) {
                        precondition(link.shortened && text.hasSuffix(BugReport.truncationNote), "\(a)/\(b): a cut \(key) says so")
                        let kept = String(text.dropLast(BugReport.truncationNote.count + 2))
                        precondition(original.hasPrefix(kept), "\(a)/\(b): \(key) keeps the start of what was written")
                        precondition(kept.count > 300, "\(a)/\(b): \(key) keeps a useful amount, \(kept.count) characters")
                    }
                }
                if a + b < 3000 { precondition(!link.shortened, "\(a)/\(b): short enough to keep whole") }
                if a + b > 20000 { precondition(link.shortened, "\(a)/\(b): too long to keep whole") }
            }
        }
        // Both texts long: neither crowds the other out
        let both = fields(BugReport.link(happened: String(repeating: "a ", count: 20000), steps: String(repeating: "b ", count: 20000), details: details).url)
        let da = both["description"]?.count ?? 0, ds = both["steps"]?.count ?? 0
        precondition(da > 1000 && ds > 1000 && abs(da - ds) < 50, "two long texts share the room: \(da) and \(ds)")
        // One short, one long: the long one gets the room the short one leaves
        let uneven = fields(BugReport.link(happened: "short", steps: String(repeating: "word ", count: 20000), details: details).url)
        precondition(uneven["description"] == "short" && (uneven["steps"]?.count ?? 0) > 2500, "the long text takes the leftover room")
        // A character is never split
        let emoji = BugReport.cut(String(repeating: "👨‍👩‍👧‍👦", count: 500), to: 600)
        precondition(emoji.hasSuffix(BugReport.truncationNote) && emoji.dropLast(BugReport.truncationNote.count + 2).allSatisfy { $0 == "👨‍👩‍👧‍👦" }, "family emoji stay whole")
        precondition(BugReport.cut("hello", to: 100) == "hello" && BugReport.cut("hello world", to: 5) == "", "no room means nothing, not a broken note")
    }

    static func checkTemplate() throws {
        let template = try String(contentsOfFile: ".github/ISSUE_TEMPLATE/bug_report.yml", encoding: .utf8)
        let ids = Set(template.components(separatedBy: "\n").compactMap { line -> String? in
            guard line.hasPrefix("    id: ") else { return nil }
            return String(line.dropFirst("    id: ".count))
        })
        let url = BugReport.link(happened: "x", steps: "y", details: details).url
        for key in fields(url).keys where key != "template" {
            precondition(ids.contains(key), "the bug report template has a field with id \(key)")
        }
        precondition(FileManager.default.fileExists(atPath: ".github/ISSUE_TEMPLATE/\(BugReport.template)"), "the template file exists")
    }

    static func checkCrashReports() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("quill-crash-\(UUID())", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: folder.path); try? fm.removeItem(at: folder) }
        let now = Date()
        precondition(CrashReports.latest(in: folder, now: now) == nil, "an empty folder has none")
        precondition(CrashReports.latest(in: folder.appendingPathComponent("missing"), now: now) == nil, "a missing folder has none")

        func make(_ name: String, daysOld: Double, text: String = "report") throws -> URL {
            let url = folder.appendingPathComponent(name)
            try text.write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.modificationDate: now.addingTimeInterval(-daysOld * 86400)], ofItemAtPath: url.path)
            return url
        }
        _ = try make("Quill-2026-09-01-101010.ips", daysOld: 33)
        _ = try make("Safari-2026-10-04-101010.ips", daysOld: 0)
        _ = try make("Quillette-2026-10-04-101010.ips", daysOld: 0)
        _ = try make("Quill-notes.txt", daysOld: 0)
        precondition(CrashReports.latest(in: folder, now: now) == nil, "old reports, other apps, and other files are ignored")

        let older = try make("Quill-2026-09-30-101010.ips", daysOld: 4)
        let newest = try make("Quill-2026-10-02-101010.crash", daysOld: 2)
        _ = try make("Quill-2026-10-01-101010.ips", daysOld: 3)
        let found = CrashReports.latest(in: folder, now: now)
        precondition(found?.url.lastPathComponent == newest.lastPathComponent, "the newest from the last seven days wins, \(older.lastPathComponent) doesn't")

        // Finding a report never opens it: a file Sable could not read is still found, and reading it is a separate, explicit step
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: newest.path)
        let unreadable = CrashReports.latest(in: folder, now: now)
        precondition(unreadable?.url.lastPathComponent == newest.lastPathComponent, "looking doesn't read")
        precondition(CrashReports.contents(of: unreadable!) == nil, "an unreadable report is nil, not a crash")
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: newest.path)
        precondition(CrashReports.contents(of: unreadable!) == "report", "contents are read on request")

        // A big report is capped
        let big = try make("Quill-2026-10-03-101010.ips", daysOld: 0.5, text: String(repeating: "x", count: 1_500_000))
        precondition(CrashReports.contents(of: CrashReports.latest(in: folder, now: now)!)?.count == CrashReports.maxBytes && big.lastPathComponent == CrashReports.latest(in: folder, now: now)?.url.lastPathComponent, "a huge report is cut at a megabyte")
    }
}
