import Foundation

/// The facts a bug report can carry about this Mac and this copy of Sable, shown to the writer before they choose to include them.
struct SystemDetails: Equatable {
    var sable: String
    var macOS: String
    var mac: String

    /// "Sable 1.0.0-beta.1 (16) · macOS 15.1 (24B83) · Mac14,2, Apple M2", exactly what the sheet shows under its checkbox.
    var summary: String { "Sable \(sable) · \(macOS) · \(mac)" }

    static func current(bundle: Bundle = .main) -> SystemDetails {
        let info = bundle.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var macOS = "macOS \(os.majorVersion).\(os.minorVersion)"
        if os.patchVersion != 0 { macOS += ".\(os.patchVersion)" }
        if let osBuild = sysctlString("kern.osversion") { macOS += " (\(osBuild))" }
        let model = sysctlString("hw.model") ?? "unknown model"
        let chip = sysctlString("machdep.cpu.brand_string")
        return SystemDetails(sable: build.map { "\(version) (\($0))" } ?? version,
                             macOS: macOS,
                             mac: chip.map { "\(model), \($0)" } ?? model)
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let value = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

/// Builds the link that opens GitHub's bug report form with the writer's words already in it. The form's fields are filled
/// through the link's query, so nothing is sent anywhere until the writer reads it in their browser and submits it there.
enum BugReport {
    static let repository = "ExxtraV/Sable-Markdown-Suite"
    static let issuesNew = "https://github.com/\(repository)/issues/new"
    static let ideasURL = URL(string: "https://github.com/\(repository)/discussions/categories/ideas")!
    /// `.github/ISSUE_TEMPLATE/bug_report.yml`; the field ids below must match its `id:` lines (`check-bug-report.swift` confirms it).
    static let template = "bug_report.yml"
    /// GitHub turns away addresses past about 8,000 characters, so stay well inside that.
    static let maxLinkLength = 6000
    static let truncationNote = "[Shortened to fit in a link. Please paste the rest here.]"

    struct Link: Equatable {
        var url: URL
        /// True when the happened or steps text was cut so the link would fit.
        var shortened: Bool
    }

    /// The link for these words. `details` is nil when the writer left the version checkbox off.
    static func link(happened: String, steps: String, details: SystemDetails?) -> Link {
        let happened = happened.trimmingCharacters(in: .whitespacesAndNewlines)
        let steps = steps.trimmingCharacters(in: .whitespacesAndNewlines)

        var fixed = [("template", template)]
        if let details {
            fixed += [("sable-version", details.sable), ("macos-version", details.macOS), ("mac-model", details.mac)]
        }
        let fixedLength = issuesNew.count + 1 + fixed.map { encoded($0.0).count + 1 + encoded($0.1).count + 1 }.reduce(0, +)
        // Each long field costs its own name and "=" and "&" on top of its text
        let overhead = ["description", "steps"].map { encoded($0).count + 2 }.reduce(0, +)
        let room = max(0, maxLinkLength - fixedLength - overhead)

        let (happenedText, stepsText) = share(room, happened, steps)
        var fields = fixed
        if !happenedText.isEmpty { fields.append(("description", happenedText)) }
        if !stepsText.isEmpty { fields.append(("steps", stepsText)) }
        let query = fields.map { "\(encoded($0.0))=\(encoded($0.1))" }.joined(separator: "&")
        return Link(url: URL(string: "\(issuesNew)?\(query)")!, shortened: happenedText != happened || stepsText != steps)
    }

    /// Whether this much text would fit in the link without being cut. Lets the sheet say so before the writer clicks.
    static func isShortened(happened: String, steps: String, details: SystemDetails?) -> Bool {
        link(happened: happened, steps: steps, details: details).shortened
    }

    // MARK: Fitting the text

    /// Splits `room` encoded characters between the two texts: each keeps what it needs if it fits, and a long one takes
    /// what the shorter one leaves over. Neither is ever cut below half the room unless the other needs less.
    private static func share(_ room: Int, _ first: String, _ second: String) -> (String, String) {
        let firstNeeds = encoded(first).count, secondNeeds = encoded(second).count
        if firstNeeds + secondNeeds <= room { return (first, second) }
        let half = room / 2
        if firstNeeds <= half { return (first, cut(second, to: room - firstNeeds)) }
        if secondNeeds <= half { return (cut(first, to: room - secondNeeds), second) }
        return (cut(first, to: half), cut(second, to: room - half))
    }

    /// `text` shortened (at a word break where there is one, never inside a character) so that it and the note about the
    /// cut take at most `budget` encoded characters.
    static func cut(_ text: String, to budget: Int) -> String {
        if encoded(text).count <= budget { return text }
        let note = "\n\n" + truncationNote
        let noteCost = encoded(note).count
        guard budget > noteCost else { return "" }
        let characters = Array(text)
        var low = 0, high = characters.count
        while low < high {
            let middle = (low + high + 1) / 2
            if encoded(String(characters[..<middle])).count + noteCost <= budget { low = middle } else { high = middle - 1 }
        }
        var kept = String(characters[..<low])
        if let space = kept.lastIndex(where: { $0.isWhitespace }), kept.distance(from: space, to: kept.endIndex) < 40 {
            kept = String(kept[..<space])
        }
        return kept.trimmingCharacters(in: .whitespacesAndNewlines) + note
    }

    /// Percent-encodes everything but letters, digits, and `-._~`, so `&`, `=`, `+`, `#`, and line breaks can't change the link's meaning.
    static func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

/// Finds Sable's own crash reports in the system's diagnostic folder. Only names and dates are looked at here; a report's
/// contents are read by `contents(of:)`, and only when the writer asks to see it.
enum CrashReports {
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60
    static let maxBytes = 1_000_000
    /// The app's executable is "Quill", and macOS names its reports "Quill-<date>-<time>.ips" (or ".crash" on older systems).
    static let processName = "Quill"

    static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
    }

    struct Report: Equatable {
        var url: URL
        var date: Date
    }

    /// The newest Sable crash report from the last seven days, if there is one.
    static func latest(in folder: URL = defaultFolder, now: Date = Date()) -> Report? {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix(processName + "-") && ["ips", "crash"].contains($0.pathExtension.lowercased()) }
            .compactMap { url -> Report? in
                guard let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return nil }
                return Report(url: url, date: date)
            }
            .filter { now.timeIntervalSince($0.date) <= maxAge && $0.date <= now.addingTimeInterval(60) }
            .max { $0.date < $1.date }
    }

    /// The report's text, up to a megabyte. Called only after the writer asks to see the report.
    static func contents(of report: Report) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: report.url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maxBytes) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
