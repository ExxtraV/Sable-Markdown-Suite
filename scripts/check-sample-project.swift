import Foundation

// The sample project that ships inside the app: `Examples/Sable Sample Project` is the source, and
// `Contents/Resources/Sample Project` in a built app must be the same thing. Run from the repository root.
// Pass a built app (`build/Sable Markdown Writer.app`) as the first argument to check the packaged copy too.

@main enum SampleProjectChecks {
    static let sourcePath = "Examples/Sable Sample Project"
    static let label = "_Sample text written by Claude Code._"

    static func main() throws {
        let fm = FileManager.default
        let source = URL(fileURLWithPath: sourcePath, isDirectory: true)
        try verify(source, as: "source")

        if CommandLine.arguments.count > 1 {
            let app = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
            guard let packaged = SampleProject.bundled(resourceURL: resources) else { preconditionFailure("The app has no Sample Project in Contents/Resources") }
            try verify(packaged, as: "packaged")
            let same = try snapshot(of: packaged) == snapshot(of: source)
            precondition(same, "The packaged sample is exactly the source folder")
        }

        // An app with no sample says so instead of guessing
        let empty = fm.temporaryDirectory.appendingPathComponent("quill-sample-empty-\(UUID())")
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: empty) }
        precondition(SampleProject.bundled(resourceURL: empty) == nil && SampleProject.bundled(resourceURL: nil) == nil)

        try checkCopying(from: source)
        print("sample project checks passed")
    }

    // MARK: The project itself

    static func verify(_ folder: URL, as name: String) throws {
        let fm = FileManager.default
        func fail(_ message: String) -> Never { preconditionFailure("\(name): \(message)") }

        // A valid Fiction Project with the standard folders
        guard FictionProject.isProject(folder), let project = FictionProject.load(folder) else { fail("is not a Fiction Project") }
        precondition(project.title == "Northwatch" && project.kind == "fiction", "\(name): title \(project.title)")
        precondition((project.wordGoal ?? 0) > 0, "\(name): a word goal, so the Manuscript tab shows a progress bar")
        for standard in FictionProject.standardFolders {
            var isFolder: ObjCBool = false
            precondition(fm.fileExists(atPath: folder.appendingPathComponent(standard).path, isDirectory: &isFolder) && isFolder.boolValue, "\(name): \(standard) folder")
        }

        // Only plain files: Markdown, one picture, and the project's own small JSON
        let all = fm.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [])?.compactMap { $0 as? URL } ?? []
        for url in all where (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
            precondition(["md", "png", "json"].contains(url.pathExtension.lowercased()), "\(name): unexpected file \(url.lastPathComponent)")
        }

        // Every Markdown file the reader sees is labeled as Claude's writing (the snapshot's copies are the same files)
        let markdown = all.filter { $0.pathExtension == "md" }
        precondition(markdown.count >= 14, "\(name): \(markdown.count) Markdown files")
        for url in markdown {
            let head = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n").prefix(14)
            precondition(head.contains(label), "\(name): \(url.lastPathComponent) carries the \"written by Claude Code\" line")
        }

        // Three chapters; the first one opens the sample
        let chapters = ManuscriptStats.load(folder: FictionProject.folder(for: .chapter, in: folder), order: project.chapterOrder)
        precondition(chapters.map(\.name) == ["Chapter 1.md", "Chapter 2.md", "Chapter 3.md"], "\(name): chapters \(chapters.map(\.name))")
        precondition(chapters.allSatisfy { $0.words > 150 && $0.words < 500 }, "\(name): short chapters \(chapters.map(\.words))")
        precondition(SampleProject.firstChapter(in: folder)?.lastPathComponent == "Chapter 1.md", "\(name): the first chapter opens first")
        let first = try String(contentsOf: chapters[0].url, encoding: .utf8)
        let firstBody = FrontMatter.parse(first).body.components(separatedBy: "\n")
        precondition(firstBody.first?.hasPrefix("# ") == true && firstBody.dropFirst().first(where: { !$0.isEmpty }) == label, "\(name): chapter 1 starts with its title, then the label")

        // Exactly the cards the sample promises: 4 characters, 2 locations, 1 world note; nothing else is a card
        let cards = CardIndex.load(project: folder)
        func titles(_ kind: CardKind) -> [String] { cards.filter { $0.kind == kind }.map(\.title).sorted() }
        precondition(titles(.character) == ["Ines Hale", "Mara Venn", "Pell Arden", "Tam Orrin"], "\(name): characters \(titles(.character))")
        precondition(titles(.location) == ["Northwatch", "The Drowned Gate"], "\(name): locations \(titles(.location))")
        precondition(titles(.lore) == ["Gate Law"], "\(name): world notes \(titles(.lore))")
        precondition(cards.count == 7, "\(name): \(cards.count) cards")

        // Mara: aliases and a picture that resolves, is a real PNG, and is the shape a card's portrait wants
        guard let mara = cards.first(where: { $0.title == "Mara Venn" }) else { fail("no card for Mara") }
        precondition(mara.aliases.contains("The Locksmith") && mara.subtitle == "Locksmith", "\(name): Mara's aliases \(mara.aliases)")
        let maraText = try String(contentsOf: mara.url, encoding: .utf8)
        guard let info = CardParsing.info(for: mara.url, text: maraText, projectRoot: folder), let ref = info.imageRef,
              let picture = CardParsing.resolveImage(ref, card: mara.url, projectRoot: folder) else { fail("Mara's picture doesn't resolve") }
        let bytes = [UInt8](try Data(contentsOf: picture))
        precondition(bytes.prefix(8) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "\(name): the portrait is a PNG")
        let width = bytes[16..<20].reduce(0) { $0 << 8 | Int($1) }, height = bytes[20..<24].reduce(0) { $0 << 8 | Int($1) }
        precondition(abs(Double(width) / Double(height) - CropRect.portraitAspect) < 0.01, "\(name): portrait is \(width)×\(height)")
        precondition(cards.filter { !$0.aliases.isEmpty }.count >= 2, "\(name): aliases on more than one card")

        // Scene tags: every chapter has Who and Where, and every name resolves to a card, aliases included
        let usedAlias = try chapters.contains { chapter in
            let tags = SceneTags.parse(try String(contentsOf: chapter.url, encoding: .utf8))
            precondition(!tags.locations.isEmpty && !tags.characters.isEmpty, "\(name): \(chapter.name) has Who and Where tags")
            var viaAlias = false
            for kind in SceneTags.kinds {
                for tag in tags.names(for: kind) {
                    guard let card = CardIndex.match(tag, kind: kind, in: cards) else { fail("\(chapter.name): tag “\(tag)” matches no card") }
                    if CardIndex.normalize(card.stem) != CardIndex.normalize(tag) && CardIndex.normalize(card.title) != CardIndex.normalize(tag) { viaAlias = true }
                }
            }
            return viaAlias
        }
        precondition(usedAlias, "\(name): at least one scene tag names a card by an alias")
        let chapter3 = SceneTags.parse(try String(contentsOf: chapters[2].url, encoding: .utf8))
        precondition(CardIndex.match("The Locksmith", kind: .character, in: cards)?.title == "Mara Venn" && chapter3.characters.contains("The Locksmith"), "\(name): chapter 3 tags Mara by an alias")

        // Names the story uses are all known to the highlighter
        let highlighter = NameHighlighter.build(from: cards)
        let prose = try String(contentsOf: chapters[1].url, encoding: .utf8)
        let found = Set(highlighter.matches(in: prose).map { (prose as NSString).substring(with: $0.range) })
        for expected in ["mara", "tam", "ines hale", "pell", "drowned gate", "gate law"] where !found.contains(where: { $0.lowercased().contains(expected) }) {
            fail("chapter 2 never lights up “\(expected)” (found \(found.sorted()))")
        }

        // One HTML-comment note, in the manuscript, and the word count ignores nothing it shouldn't
        var notes = 0
        for chapter in chapters { notes += try String(contentsOf: chapter.url, encoding: .utf8).components(separatedBy: "<!--").count - 1 }
        precondition(notes == 1, "\(name): \(notes) HTML-comment notes in the chapters")

        // A concept note that is filled in, not the empty template
        let concept = try String(contentsOf: FictionProject.conceptURL(in: folder), encoding: .utf8)
        precondition(concept.hasPrefix("# Northwatch: Concept"), "\(name): concept title")
        for heading in ["## Logline", "## Writer's pitch", "## Genre & tone", "## Major themes", "## Central question"] { precondition(concept.contains(heading), "\(name): \(heading)") }
        precondition(!concept.contains("who wants what, and what stands in the way"), "\(name): the template's prompts are answered, not left in")

        // An outline whose beat tags give the Story Timeline a shape: all six beats, headings in order
        let points = StoryTimeline.points(project: folder)
        let beats = Set(points.compactMap(\.beat))
        precondition(beats == Set(StoryBeat.allCases), "\(name): beats \(beats.map(\.rawValue).sorted())")
        precondition(points.count >= 7 && points.contains { $0.title == "Chapter 1: The Crossing" && $0.beat == .inciting }, "\(name): \(points.map(\.title))")
        precondition(points.contains { $0.beat == .climax && $0.height == 1 } && (points.map(\.height).min() ?? 1) < 0.3, "\(name): the arc has a peak and a low")

        // One snapshot, readable, that has something to compare against
        let snapshots = Revisions.list(in: folder)
        precondition(snapshots.count == 1 && snapshots[0].kind == .manual && !snapshots[0].name.isEmpty, "\(name): \(snapshots.count) snapshots")
        let changes = try Revisions.changes(from: snapshots[0], root: folder, files: chapters.map(\.url))
        let status = Dictionary(uniqueKeysWithValues: changes.map { ($0.title, $0.status) })
        precondition(status["Chapter 1"] == .changed && status["Chapter 2"] == .changed && status["Chapter 3"] == .added, "\(name): comparison \(status)")
        for file in snapshots[0].files { _ = try Revisions.text(of: file.path, in: snapshots[0], root: folder) }
    }

    // MARK: Copying it out

    static func checkCopying(from source: URL) throws {
        let fm = FileManager.default
        let parent = fm.temporaryDirectory.appendingPathComponent("quill-sample-copy-\(UUID())")
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let suite = "quill-sample-check-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { try? fm.removeItem(at: parent); defaults.removePersistentDomain(forName: suite) }
        let before = try snapshot(of: source)

        // The first copy takes the plain name and is a working project
        let documents = parent.appendingPathComponent("Documents")
        let first = try SampleProject.prepare(from: source, into: documents, defaults: defaults)
        precondition(first.lastPathComponent == "Sable Sample Project" && first.deletingLastPathComponent().path == documents.path, "name \(first.lastPathComponent)")
        try verify(first, as: "copy")
        let faithful = try snapshot(of: first, ignoring: "snapshot.json") == snapshot(of: source, ignoring: "snapshot.json")
        precondition(faithful, "a faithful copy")

        // Its snapshot is dated now; everything is writable; nothing is left over beside it
        let made = Revisions.list(in: first)
        precondition(made.count == 1 && abs(made[0].date.timeIntervalSinceNow) < 120, "the snapshot is dated when the copy is made")
        let enumerator = fm.enumerator(atPath: first.path)!
        for case let path as String in enumerator { precondition(fm.isWritableFile(atPath: first.appendingPathComponent(path).path), "\(path) is writable") }
        let leftovers = try fm.contentsOfDirectory(atPath: documents.path)
        precondition(leftovers == ["Sable Sample Project"], "no staging folder left behind: \(leftovers)")

        // Asking again opens the same copy, with the writer's edits intact, instead of making another
        let chapter = SampleProject.firstChapter(in: first)!
        try "my own words".write(to: chapter, atomically: true, encoding: .utf8)
        let again = try SampleProject.prepare(from: source, into: documents, defaults: defaults)
        let kept = try String(contentsOf: chapter, encoding: .utf8)
        precondition(again == first && kept == "my own words", "asking again reuses the copy")

        // If the copy is gone, a new one is made; a folder that already has the name is never touched or overwritten
        try fm.removeItem(at: first)
        let stranger = documents.appendingPathComponent("Sable Sample Project")
        try fm.createDirectory(at: stranger, withIntermediateDirectories: true)
        try "not mine".write(to: stranger.appendingPathComponent("keep.txt"), atomically: true, encoding: .utf8)
        let second = try SampleProject.prepare(from: source, into: documents, defaults: defaults)
        precondition(second.lastPathComponent == "Sable Sample Project 2", "numbered when the name is taken: \(second.lastPathComponent)")
        let strangerText = try String(contentsOf: stranger.appendingPathComponent("keep.txt"), encoding: .utf8)
        precondition(strangerText == "not mine" && !FictionProject.isProject(stranger), "the other folder is untouched")
        try fm.removeItem(at: second)
        let third = try SampleProject.copy(from: source, into: documents)
        let fourth = try SampleProject.copy(from: source, into: documents)
        precondition(third.lastPathComponent == "Sable Sample Project 2" && fourth.lastPathComponent == "Sable Sample Project 3", "\(third.lastPathComponent), \(fourth.lastPathComponent)")

        // The sample the app ships is never changed by any of this
        let after = try snapshot(of: source)
        precondition(after == before, "the source folder is untouched")
        precondition(SampleProject.remembered(defaults: UserDefaults(suiteName: "quill-sample-check-none-\(UUID())")!) == nil)
    }

    /// Every file under `folder` (relative path to bytes), for comparing two trees exactly.
    static func snapshot(of folder: URL, ignoring skipped: String? = nil) throws -> [String: Data] {
        var result: [String: Data] = [:]
        let base = folder.standardizedFileURL.path
        for case let url as URL in FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [])! {
            guard (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true, url.lastPathComponent != skipped else { continue }
            result[String(url.standardizedFileURL.path.dropFirst(base.count))] = try Data(contentsOf: url)
        }
        return result
    }
}
