import Foundation

/// Where one top-level item of a Scrivener binder goes in the new Fiction Project.
enum ScrivenerDestination: String, CaseIterable, Sendable, Identifiable {
    case manuscript, characters, locations, world, notes, skip
    var id: String { rawValue }
    var title: String {
        switch self {
        case .manuscript: return "Manuscript"
        case .characters: return "Characters"
        case .locations: return "Locations"
        case .world: return "World"
        case .notes: return "Notes"
        case .skip: return "Don’t Import"
        }
    }
    var folderName: String? {
        switch self {
        case .manuscript: return FictionProject.manuscriptFolder
        case .characters: return "Characters"
        case .locations: return "Locations"
        case .world: return "World"
        case .notes: return "Notes"
        case .skip: return nil
        }
    }
    var cardKind: CardKind? {
        switch self { case .characters: return .character; case .locations: return .location; case .world: return .lore; default: return nil }
    }
}

/// Everything an import will write, worked out before a single file exists, so the writer can see it first.
struct ScrivenerImportPlan: Equatable, Sendable {
    /// One file of the new project: Markdown made here, or a file copied out of the Scrivener project.
    struct File: Equatable, Sendable {
        var path: String
        var contents: String? = nil
        var source: URL? = nil
    }
    /// Something that couldn't become Markdown. `path` is where a copy was put, when one was.
    struct Skipped: Equatable, Sendable {
        enum Kind: String, Sendable { case image, pdf, webPage, file, pastedPictures, missing, template, unreadable, leftOut }
        var kind: Kind
        var title: String
        var path: String? = nil
        var count = 1
    }

    var title: String
    var files: [File] = []
    var chapterOrder: [String] = []
    var chapters = 0, scenes = 0, characters = 0, locations = 0, worldNotes = 0, notes = 0
    var skipped: [Skipped] = []
    var warnings: [ScrivenerWarning] = []

    /// "42 scenes in 12 chapters, 9 characters, 3 locations, 14 notes"
    var summary: String {
        func some(_ count: Int, _ one: String, _ many: String) -> String? { count == 0 ? nil : "\(count) \(count == 1 ? one : many)" }
        var parts: [String] = []
        if scenes > 0 { parts.append("\(some(scenes, "scene", "scenes")!) in \(some(chapters, "chapter", "chapters") ?? "0 chapters")") }
        parts += [some(characters, "character", "characters"), some(locations, "location", "locations"), some(worldNotes, "world note", "world notes"), some(notes, "note", "notes")].compactMap { $0 }
        return parts.isEmpty ? "Nothing to import" : parts.joined(separator: ", ")
    }

    /// "2 items can’t become Markdown: images, a PDF", or nil when everything converts. Items left out by choice aren't counted.
    var skippedSummary: String? {
        let kinds: [(Skipped.Kind, String, String)] = [(.image, "an image", "images"), (.pdf, "a PDF", "PDFs"), (.webPage, "a web page", "web pages"), (.file, "a file", "other files"),
                                                        (.pastedPictures, "a pasted picture", "pasted pictures"), (.missing, "a missing file", "missing files"), (.unreadable, "an unreadable document", "unreadable documents")]
        var total = 0
        var names: [String] = []
        for (kind, one, many) in kinds {
            let count = skipped.filter { $0.kind == kind }.reduce(0) { $0 + $1.count }
            guard count > 0 else { continue }
            total += count
            names.append(count == 1 ? one : many)
        }
        guard total > 0 else { return nil }
        return "\(total) \(total == 1 ? "item" : "items") can’t become Markdown: \(names.joined(separator: ", "))"
    }
}

/// Decides where everything in a Scrivener binder goes. Nothing here touches the disk.
enum ScrivenerImportPlanner {
    static let reportName = "Import Report.md"
    /// A synopsis longer than this goes in the text as a note, so a card's opening lines stay short enough to index.
    static let maxFrontMatterSynopsis = 500

    // MARK: Suggestions

    /// The destination offered for each top-level binder item, before the writer changes any.
    static func suggestedDestinations(for project: ScrivenerProject) -> [ScrivenerDestination] { project.binder.map(suggestedDestination) }

    static func suggestedDestination(for root: ScrivenerItem) -> ScrivenerDestination {
        switch root.kind {
        case .draftFolder: return .manuscript
        case .researchFolder: return .notes
        case .trashFolder: return .skip
        default: break
        }
        if root.isTemplate { return .skip }
        let name = root.title.trimmingCharacters(in: .whitespaces).lowercased()
        let documents = root.flattened.filter { $0.text != nil }
        let characterSheets = documents.filter { sheetKind(of: $0) == .character }.count, locationSheets = documents.filter { sheetKind(of: $0) == .location }.count
        // The names Sable itself takes for card folders ("Characters", "Places", "World"…), then what the sheets say.
        switch CardKind.named(name) ?? (name == "cast" ? .character : name == "settings" ? .location : nil) {
        case .character: return .characters
        case .location: return .locations
        case .lore: return .world
        case nil: break
        }
        if characterSheets > 0 && characterSheets * 2 >= documents.count { return .characters }
        if locationSheets > 0 && locationSheets * 2 >= documents.count { return .locations }
        // The page a Scrivener template opens with, explaining the template itself.
        if root.kind == .text, root.children.isEmpty, root.iconName == "Information", name.hasSuffix(" format") { return .skip }
        return .notes
    }

    /// Scrivener marks nothing as a character or location sheet; the icon a template sheet carries is the clue.
    static func sheetKind(of item: ScrivenerItem) -> CardKind? {
        guard let icon = item.iconName else { return nil }
        if icon.contains("Character Sheet") { return .character }
        if icon.contains("Location Sheet") { return .location }
        return nil
    }

    /// What a top-level item holds, for the preview: "12 documents", "1 document, 3 files", "Empty".
    static func contentsDescription(of root: ScrivenerItem) -> String {
        let items = root.flattened.filter { !$0.isTemplate || root.isTemplate }
        let documents = items.filter { $0.text != nil }.count, files = items.filter { $0.attachment != nil }.count
        var parts: [String] = []
        if documents > 0 { parts.append("\(documents) \(documents == 1 ? "document" : "documents")") }
        if files > 0 { parts.append("\(files) \(files == 1 ? "file" : "files")") }
        return parts.isEmpty ? "Empty" : parts.joined(separator: ", ")
    }

    // MARK: Planning

    static func plan(_ project: ScrivenerProject, destinations: [ScrivenerDestination]? = nil) -> ScrivenerImportPlan {
        let chosen = destinations ?? suggestedDestinations(for: project)
        var builder = Builder(plan: ScrivenerImportPlan(title: project.title, warnings: project.warnings))
        for (index, root) in project.binder.enumerated() {
            let destination = index < chosen.count ? chosen[index] : suggestedDestination(for: root)
            switch destination {
            case .skip:
                let count = root.flattened.filter { $0.text != nil || $0.attachment != nil }.count
                if count > 0 { builder.plan.skipped.append(.init(kind: root.isTemplate ? .template : .leftOut, title: displayTitle(root), count: count)) }
            case .manuscript:
                // Scrivener's manuscript folder is the Manuscript folder. Anything else sent there is a chapter or a part.
                guard root.kind == .draftFolder else { builder.chapter(root, part: nil); break }
                if root.text != nil { builder.chapter(leaf(root), part: nil) }
                for child in root.children { builder.chapter(child, part: nil) }
            case .characters, .locations, .world, .notes:
                let base = destination.folderName!
                let own = displayTitle(root).lowercased()
                // "Characters" goes straight into Characters; "Old Drafts" becomes Notes/Old Drafts.
                let nests = destination == .notes && own != "notes" && root.isContainer
                if root.isContainer {
                    let folder = nests ? base + "/" + builder.claim(displayTitle(root), in: base, ext: nil) : base
                    if root.text != nil || root.notes != nil || root.synopsis != nil { builder.document(leaf(root), in: folder, destination: destination) }
                    for child in root.children { builder.walk(child, in: folder, destination: destination) }
                } else {
                    builder.walk(root, in: base, destination: destination)
                }
            }
        }
        for warning in project.warnings where warning.message.contains("left out") && warning.uuid != nil {
            builder.plan.skipped.append(.init(kind: .unreadable, title: project.allItems.first { $0.uuid == warning.uuid }.map(displayTitle) ?? "A document"))
        }
        builder.plan.files.append(.init(path: reportName, contents: report(for: builder.plan, project: project)))
        return builder.plan
    }

    private static func leaf(_ item: ScrivenerItem) -> ScrivenerItem {
        var copy = item
        copy.children = []
        return copy
    }

    static func displayTitle(_ item: ScrivenerItem) -> String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled" : title
    }

    /// A title made safe to be a file or folder name: nothing that means something to the file system, no leading
    /// period, and not too long. The title itself is kept, as written, in the file's heading.
    static func fileName(for title: String) -> String {
        var name = String(title.unicodeScalars.compactMap { scalar -> Character? in
            if scalar == "/" || scalar == ":" || scalar == "\\" { return "-" }
            // Legal on a Mac, but trouble the day the folder is synced or copied anywhere else.
            if "*?\"<>|".unicodeScalars.contains(scalar) { return nil }
            return CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar) ? " " : Character(scalar)
        })
        name = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        while name.hasPrefix(".") || name.hasPrefix(" ") { name.removeFirst() }
        if name.count > 80 { name = String(name.prefix(80)).trimmingCharacters(in: .whitespaces) }
        return name.isEmpty ? "Untitled" : name
    }

    private struct Builder {
        var plan: ScrivenerImportPlan
        /// Names already used in each folder, compared without regard to case, so nothing lands on anything else.
        var taken: [String: Set<String>] = [:]

        mutating func claim(_ title: String, in folder: String, ext: String?) -> String {
            let base = ScrivenerImportPlanner.fileName(for: title)
            func full(_ stem: String) -> String { ext.map { stem + "." + $0 } ?? stem }
            // A document and the folder of its children share a name, so the stem is what must be free.
            var stem = base, number = 2
            while taken[folder.lowercased(), default: []].contains(key(stem, ext)) {
                stem = "\(base) \(number)"
                number += 1
            }
            taken[folder.lowercased(), default: []].insert(key(stem, ext))
            return full(stem)
        }
        private func key(_ stem: String, _ ext: String?) -> String { (ext.map { stem + "." + $0 } ?? stem + "/").lowercased() }

        // MARK: Manuscript

        /// One binder item under the manuscript. A folder of scenes becomes one chapter file; a folder of folders
        /// is a part, and its chapters follow in order.
        mutating func chapter(_ item: ScrivenerItem, part: String?) {
            guard !item.isTemplate else { return }
            if item.attachment != nil || [.image, .pdf, .webArchive].contains(item.kind) { attach(item, in: "Notes"); return }
            let documents = item.children.filter { $0.attachment == nil && ![.image, .pdf, .webArchive].contains($0.kind) }
            if !item.children.isEmpty, item.children.contains(where: { !$0.children.isEmpty }) {
                if item.text != nil { write(chapter: ScrivenerImportPlanner.leaf(item), scenes: [], part: part) }
                for child in item.children { chapter(child, part: ScrivenerImportPlanner.displayTitle(item)) }
                return
            }
            for child in item.children where !documents.contains(child) { attach(child, in: "Notes") }
            let scenes = documents.filter { !$0.isTemplate }
            // An empty folder is nothing; an empty document is a chapter not yet written, and keeps its place.
            guard item.kind == .text || item.text != nil || !scenes.isEmpty else { return }
            write(chapter: item, scenes: scenes, part: part)
        }

        private mutating func write(chapter item: ScrivenerItem, scenes: [ScrivenerItem], part: String?) {
            let title = ScrivenerImportPlanner.displayTitle(item)
            let name = claim(title, in: FictionProject.manuscriptFolder, ext: "md")
            var fields = ScrivenerImportPlanner.fields(for: item)
            if let part { fields.append(("part", part)) }
            var blocks = ScrivenerImportPlanner.body(of: item, title: title, fields: &fields)
            for (index, scene) in scenes.enumerated() {
                if index > 0 || item.text != nil { blocks.append("* * *") }
                blocks.append(ScrivenerImportPlanner.sceneNote(scene))
                if let text = scene.text { blocks.append(text.trimmingCharacters(in: .newlines)) }
                pictures(in: scene)
            }
            pictures(in: item)
            plan.files.append(.init(path: FictionProject.manuscriptFolder + "/" + name, contents: ScrivenerImportPlanner.assemble(fields: fields, blocks: blocks)))
            plan.chapterOrder.append(name)
            plan.chapters += 1
            plan.scenes += max(1, scenes.count)
        }

        // MARK: Cards and notes

        mutating func walk(_ item: ScrivenerItem, in folder: String, destination: ScrivenerDestination) {
            if item.isTemplate {
                plan.skipped.append(.init(kind: .template, title: ScrivenerImportPlanner.displayTitle(item)))
                return
            }
            if item.attachment != nil || [.image, .pdf, .webArchive].contains(item.kind) {
                attach(item, in: destination == .notes ? folder : "Notes")
            } else if item.kind == .other, item.text == nil {
                plan.skipped.append(.init(kind: .missing, title: ScrivenerImportPlanner.displayTitle(item)))
            } else if item.kind != .folder || item.text != nil || item.notes != nil || item.synopsis != nil {
                document(ScrivenerImportPlanner.leaf(item), in: folder, destination: destination, hasChildren: !item.children.isEmpty)
            }
            guard !item.children.isEmpty else { return }
            // A document's children sit in a folder of the same name beside it.
            let sub = folder + "/" + claim(ScrivenerImportPlanner.displayTitle(item), in: folder, ext: nil)
            for child in item.children { walk(child, in: sub, destination: destination) }
        }

        mutating func document(_ item: ScrivenerItem, in folder: String, destination: ScrivenerDestination, hasChildren: Bool = false) {
            let title = ScrivenerImportPlanner.displayTitle(item)
            // Sable also reads any folder named Characters, Places, World… as holding cards, wherever it is.
            let byFolder = folder.split(separator: "/").reversed().lazy.compactMap { CardKind.named(String($0)) }.first
            let kind = destination.cardKind ?? ScrivenerImportPlanner.sheetKind(of: item) ?? byFolder
            var fields: [(String, String)] = kind.map { [("type", $0.rawValue)] } ?? []
            fields += ScrivenerImportPlanner.fields(for: item)
            if kind != nil, let image = item.cardImage {
                let name = claim(title, in: FictionProject.imagesFolder, ext: image.pathExtension.lowercased())
                plan.files.append(.init(path: FictionProject.imagesFolder + "/" + name, source: image))
                fields.append(("image", FictionProject.imagesFolder + "/" + name))
            }
            let blocks = ScrivenerImportPlanner.body(of: item, title: title, fields: &fields)
            pictures(in: item)
            plan.files.append(.init(path: folder + "/" + claim(title, in: folder, ext: "md"), contents: ScrivenerImportPlanner.assemble(fields: fields, blocks: blocks)))
            switch kind {
            case .character: plan.characters += 1
            case .location: plan.locations += 1
            case .lore: plan.worldNotes += 1
            case nil: plan.notes += 1
            }
        }

        /// A picture, PDF, web archive, or other file: copied across as it is, and listed in the report.
        private mutating func attach(_ item: ScrivenerItem, in folder: String) {
            let title = ScrivenerImportPlanner.displayTitle(item)
            guard let source = item.attachment else {
                if item.text != nil { document(ScrivenerImportPlanner.leaf(item), in: folder, destination: .notes) } else { plan.skipped.append(.init(kind: .missing, title: title)) }
                return
            }
            let ext = source.pathExtension.lowercased()
            let kind: ScrivenerImportPlan.Skipped.Kind = item.kind == .image ? .image : item.kind == .pdf ? .pdf : item.kind == .webArchive ? .webPage : .file
            let target = kind == .image ? FictionProject.imagesFolder : folder
            let path = target + "/" + claim(title, in: target, ext: ext.isEmpty ? nil : ext)
            plan.files.append(.init(path: path, source: source))
            plan.skipped.append(.init(kind: kind, title: title, path: path))
            if item.text != nil || item.notes != nil || item.synopsis != nil { document(ScrivenerImportPlanner.leaf(item), in: folder, destination: .notes) }
        }

        private mutating func pictures(in item: ScrivenerItem) {
            if item.embeddedPictures > 0 { plan.skipped.append(.init(kind: .pastedPictures, title: ScrivenerImportPlanner.displayTitle(item), count: item.embeddedPictures)) }
        }
    }

    // MARK: Text

    /// The front-matter lines a document's Scrivener details become. `tags` is the key Sable's cards already read.
    static func fields(for item: ScrivenerItem) -> [(String, String)] {
        var fields: [(String, String)] = []
        if let synopsis = item.synopsis, synopsis.count <= maxFrontMatterSynopsis { fields.append(("synopsis", oneLine(synopsis))) }
        if let status = item.status { fields.append(("status", oneLine(status))) }
        if let label = item.label { fields.append(("label", oneLine(label))) }
        if !item.keywords.isEmpty { fields.append(("tags", item.keywords.map { oneLine($0).replacingOccurrences(of: ",", with: " ") }.joined(separator: ", "))) }
        return fields
    }

    /// Heading, long synopsis, notes, then the words. Notes are `<!-- -->` so they never reach Reading Mode or an export.
    static func body(of item: ScrivenerItem, title: String, fields: inout [(String, String)]) -> [String] {
        var blocks: [String] = []
        let text = item.text?.trimmingCharacters(in: .newlines)
        if text?.hasPrefix("# ") != true { blocks.append("# " + headingText(title)) }
        if let synopsis = item.synopsis, synopsis.count > maxFrontMatterSynopsis { blocks.append(note("Synopsis", synopsis)) }
        if let notes = item.notes { blocks.append(note("Notes", notes)) }
        if let text { blocks.append(text) }
        return blocks
    }

    /// What Scrivener knew about a scene, kept above its text where only the writer sees it.
    static func sceneNote(_ scene: ScrivenerItem) -> String {
        var details = [displayTitle(scene)]
        if let status = scene.status { details.append("Status: " + oneLine(status)) }
        if let label = scene.label { details.append("Label: " + oneLine(label)) }
        if !scene.keywords.isEmpty { details.append("Keywords: " + scene.keywords.map(oneLine).joined(separator: ", ")) }
        var lines = ["Scene: " + details.joined(separator: " · ")]
        if let synopsis = scene.synopsis { lines.append("Synopsis: " + synopsis) }
        if let notes = scene.notes { lines.append("Notes:\n" + notes.trimmingCharacters(in: .newlines)) }
        return "<!-- " + commentSafe(lines.joined(separator: "\n")) + (lines.count > 1 ? "\n-->" : " -->")
    }

    private static func note(_ name: String, _ text: String) -> String {
        "<!-- \(name):\n" + commentSafe(text.trimmingCharacters(in: .newlines)) + "\n-->"
    }

    /// Text that can sit inside `<!-- -->` without ending it early.
    static func commentSafe(_ text: String) -> String {
        text.replacingOccurrences(of: "-->", with: "--\u{200B}>").replacingOccurrences(of: "<!--", with: "<\u{200B}!--")
    }

    private static func oneLine(_ text: String) -> String {
        text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func headingText(_ title: String) -> String {
        var result = ""
        for character in oneLine(title) {
            if "*_\\`~<#".contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }

    static func assemble(fields: [(String, String)], blocks: [String]) -> String {
        var text = blocks.joined(separator: "\n\n") + "\n"
        // FrontMatter does the quoting, and adds each new key at the end of the block, so they stay in this order.
        for (key, value) in fields where !value.isEmpty { text = FrontMatter.setting(key, to: value, in: text) }
        return text
    }

    // MARK: Report

    static func report(for plan: ScrivenerImportPlan, project: ScrivenerProject, failedCopies: [String] = [], date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        var lines = ["# Import Report", "", "Imported from the Scrivener project “\(project.title)” on \(formatter.string(from: date)). The Scrivener project was only read; nothing in it was changed.", ""]
        lines += ["## What was imported", "", "- " + plan.summary]
        let copied = plan.files.filter { $0.source != nil }.count
        if copied > 0 { lines.append("- \(copied) \(copied == 1 ? "file" : "files") copied as they were (pictures, PDFs, and the like)") }
        lines += ["", "Synopses, statuses, labels, and keywords are at the top of each file, between the `---` lines. Document notes and scene details are kept as notes in the text (`<!-- like this -->`), which Sable leaves out of Reading Mode and exports.", ""]

        func section(_ title: String, _ intro: String, _ kinds: [ScrivenerImportPlan.Skipped.Kind], line: (ScrivenerImportPlan.Skipped) -> String) {
            let items = plan.skipped.filter { kinds.contains($0.kind) }
            guard !items.isEmpty else { return }
            lines += ["## " + title, "", intro, ""] + items.map { "- " + line($0) } + [""]
        }
        section("Copied, not converted", "These can’t become Markdown, so each was copied into the project as it was.", [.image, .pdf, .webPage, .file]) { "\(headingText($0.title)): `\($0.path ?? "")`" }
        section("Pictures in the text", "Pictures pasted into a document’s text were left behind; Markdown text can’t hold them. They are still in the Scrivener project.", [.pastedPictures]) {
            "\(headingText($0.title)): \($0.count) \($0.count == 1 ? "picture" : "pictures")"
        }
        section("Couldn’t be read", "These were in the binder, but their files were missing or damaged.", [.missing, .unreadable]) { headingText($0.title) }
        section("Left out", "Not imported, by your choice or because they are Scrivener’s blank template sheets.", [.leftOut, .template]) {
            headingText($0.title) + ($0.count > 1 ? " (\($0.count) items)" : "")
        }
        if !failedCopies.isEmpty { lines += ["## Couldn’t be copied", "", "These files could not be copied out of the Scrivener project.", ""] + failedCopies.map { "- `\($0)`" } + [""] }
        let other = plan.warnings.filter { !$0.message.contains("left out") }
        if !other.isEmpty { lines += ["## Other things Sable noticed", ""] + Array(Set(other.map(\.message))).sorted().map { "- " + $0 } + [""] }
        return lines.joined(separator: "\n")
    }
}

enum ScrivenerImportError: LocalizedError {
    case exists(String)
    var errorDescription: String? {
        switch self {
        case .exists(let name): return "“\(name)” already exists. Choose a different name or place for the imported project."
        }
    }
}

/// Writes a planned import as a new Fiction Project. It creates one new folder and never touches anything that
/// already exists, the Scrivener project least of all.
enum ScrivenerImportWriter {
    /// Builds the project beside `destination` first, and moves it into place only once it is whole.
    @discardableResult
    static func write(_ plan: ScrivenerImportPlan, project source: ScrivenerProject, to destination: URL, now: Date = Date()) throws -> URL {
        let fm = FileManager.default
        guard (try? fm.attributesOfItem(atPath: destination.path)) == nil else { throw ScrivenerImportError.exists(destination.lastPathComponent) }
        let parent = destination.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".sable-import-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }

        try FictionProject.writeMarker(FictionProject(title: destination.lastPathComponent, created: now, chapterOrder: plan.chapterOrder.isEmpty ? nil : plan.chapterOrder), in: staging)
        for standard in FictionProject.standardFolders { try fm.createDirectory(at: staging.appendingPathComponent(standard, isDirectory: true), withIntermediateDirectories: true) }
        try FictionProject.ensureGuide(in: staging)
        try FictionProject.ensureConcept(in: staging)

        var failed: [String] = []
        for file in plan.files where file.path != ScrivenerImportPlanner.reportName {
            // Every part of a planned path was made by `fileName(for:)`; this is the last look before writing.
            let parts = file.path.split(separator: "/").map(String.init)
            guard !parts.isEmpty, parts.allSatisfy({ !$0.hasPrefix(".") && !$0.contains(":") && !$0.contains("\\") && $0 != ".." }) else { failed.append(file.path); continue }
            let url = parts.reduce(staging) { $0.appendingPathComponent($1) }
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let contents = file.contents {
                try Data(contents.utf8).write(to: url, options: .withoutOverwriting)
            } else if let original = file.source {
                // The file itself, not a link to it; and a file that has gone missing is reported, not fatal.
                do { try fm.copyItem(at: original.resolvingSymlinksInPath(), to: url) } catch { failed.append(file.path) }
            }
        }
        let report = ScrivenerImportPlanner.report(for: plan, project: source, failedCopies: failed, date: now)
        try Data(report.utf8).write(to: staging.appendingPathComponent(ScrivenerImportPlanner.reportName), options: .withoutOverwriting)
        try fm.moveItem(at: staging, to: destination)
        return destination
    }

    /// The first chapter of an imported project, in order: where the writer lands afterwards.
    static func firstChapter(in project: URL) -> URL? {
        let folder = FictionProject.folder(for: .chapter, in: project)
        guard let name = FictionProject.load(project)?.chapterOrder?.first else { return nil }
        let url = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
