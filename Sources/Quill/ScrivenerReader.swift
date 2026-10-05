import AppKit
import Foundation

/// Why a Scrivener project couldn't be read at all. Trouble with a single document is a warning instead.
enum ScrivenerError: LocalizedError, Equatable {
    case notPackage, noBinder, scrivener2, unsupportedVersion(String), unreadableBinder
    var errorDescription: String? {
        switch self {
        case .notPackage: return "That isn’t a Scrivener project. Choose the project itself, the item whose name ends in .scriv."
        case .noBinder: return "This Scrivener project has no binder file (.scrivx), so there is nothing to read."
        case .scrivener2: return "This project was last saved by Scrivener 2, which Sable can’t read yet. Opening it in Scrivener 3 updates it."
        case .unsupportedVersion(let version): return "This project uses a Scrivener format Sable doesn’t know (version \(version))."
        case .unreadableBinder: return "This Scrivener project’s binder file is damaged and couldn’t be read."
        }
    }
}

/// Something the reader noticed and worked around. The message never includes the writer's own words.
struct ScrivenerWarning: Equatable, Sendable {
    var uuid: String?
    var message: String
}

/// One row of the Scrivener binder, with whatever it carried: text, a synopsis, notes, or a file.
struct ScrivenerItem: Equatable, Sendable {
    enum Kind: String, Sendable { case draftFolder, researchFolder, trashFolder, folder, text, image, pdf, webArchive, other }

    var uuid: String
    var kind: Kind
    /// The `Type` exactly as Scrivener wrote it, for kinds the reader files under `other`.
    var typeName: String
    /// Empty when Scrivener saved no title (it shows such items as "Untitled").
    var title = ""
    var created: Date? = nil
    var modified: Date? = nil
    var includeInCompile = false
    var label: String? = nil
    var status: String? = nil
    var keywords: [String] = []
    var sectionType: String? = nil
    /// Scrivener's icon, e.g. "Characters (Character Sheet)": the best clue to what a document is.
    var iconName: String? = nil
    /// Inside the project's template-sheets folder, so a blank form and not the writer's work.
    var isTemplate = false
    var synopsis: String? = nil
    /// The document's words as Markdown; nil when it has none.
    var text: String? = nil
    /// The inspector notes as Markdown; nil when it has none.
    var notes: String? = nil
    /// The picture, PDF, web archive, or other file this item stands for. Still inside the Scrivener project.
    var attachment: URL? = nil
    /// A picture pinned to the index card. Still inside the Scrivener project.
    var cardImage: URL? = nil
    /// Pictures pasted into the text, which Markdown can't carry.
    var embeddedPictures = 0
    var children: [ScrivenerItem] = []

    var isContainer: Bool { [.draftFolder, .researchFolder, .trashFolder, .folder].contains(kind) }
    /// This item and everything beneath it, in binder order.
    var flattened: [ScrivenerItem] { [self] + children.flatMap(\.flattened) }
}

/// A Scrivener project held in memory: the binder, in order, with every document's text.
struct ScrivenerProject: Equatable, Sendable {
    var title: String
    /// The app that last saved it, e.g. "SCRMAC-3.5.2-17487".
    var creator: String
    var formatVersion: String
    var labels: [String] = []
    var statuses: [String] = []
    var binder: [ScrivenerItem] = []
    var warnings: [ScrivenerWarning] = []

    var allItems: [ScrivenerItem] { binder.flatMap(\.flattened) }
    /// The manuscript. Writers rename it, so it is found by kind and never by name.
    var draft: ScrivenerItem? { binder.first { $0.kind == .draftFolder } }
    var research: ScrivenerItem? { binder.first { $0.kind == .researchFolder } }
    var trash: ScrivenerItem? { binder.first { $0.kind == .trashFolder } }
}

/// Reads a Scrivener 3 project (`docs/scrivener-format.md` describes the format). It only ever reads: nothing in
/// the project is created, changed, or removed. A project is someone else's file, so nothing in it is trusted.
enum ScrivenerReader {
    static let maxBinderBytes = 64 * 1024 * 1024
    static let maxDocumentBytes = 32 * 1024 * 1024
    static let maxSynopsisBytes = 1024 * 1024
    static let maxItems = 100_000
    static let maxDepth = 64

    static func read(_ package: URL) throws -> ScrivenerProject {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: package.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw ScrivenerError.notPackage }
        let name = package.deletingPathExtension().lastPathComponent
        let binders = ((try? fm.contentsOfDirectory(atPath: package.path)) ?? []).filter { ($0 as NSString).pathExtension.lowercased() == "scrivx" }.sorted()
        guard let binderName = binders.first(where: { ($0 as NSString).deletingPathExtension == name }) ?? binders.first else { throw ScrivenerError.noBinder }
        let files = Files(package: package)
        guard let data = files.data(package.appendingPathComponent(binderName), limit: maxBinderBytes), let root = XMLTree.parse(data), root.name == "ScrivenerProject" else {
            throw ScrivenerError.unreadableBinder
        }

        let version = root.attributes["Version"] ?? ""
        let hasDocs = fm.fileExists(atPath: package.appendingPathComponent("Files/Docs").path)
        let hasData = fm.fileExists(atPath: package.appendingPathComponent("Files/Data").path)
        if version.hasPrefix("1.") || (hasDocs && !hasData) { throw ScrivenerError.scrivener2 }
        guard version.hasPrefix("2.") else { throw ScrivenerError.unsupportedVersion(version.isEmpty ? "unknown" : String(version.prefix(20))) }

        var context = Context(files: files, dataFolder: package.appendingPathComponent("Files/Data", isDirectory: true))
        context.labels = titles(in: root.child("LabelSettings")?.child("Labels"), element: "Label")
        context.statuses = titles(in: root.child("StatusSettings")?.child("StatusItems"), element: "Status")
        context.sectionTypes = titles(in: root.child("SectionTypes")?.child("TypeDefinitions"), element: "Type")
        for keyword in root.child("Keywords")?.children(named: "Keyword") ?? [] {
            if let id = keyword.attributes["ID"] { context.keywords[id] = keyword.child("Title")?.trimmedText ?? keyword.trimmedText }
        }
        context.templateFolder = root.child("TemplateFolderUUID")?.trimmedText

        var project = ScrivenerProject(title: name, creator: root.attributes["Creator"] ?? "", formatVersion: version)
        // "No Label" and "No Status" (ID -1) are the absence of one, not a choice.
        project.labels = context.labels.filter { $0.id != "-1" }.map(\.title)
        project.statuses = context.statuses.filter { $0.id != "-1" }.map(\.title)
        project.binder = (root.child("Binder")?.children(named: "BinderItem") ?? []).compactMap { item($0, depth: 0, inTemplates: false, &context) }
        project.warnings = context.warnings
        return project
    }

    // MARK: Binder

    private struct Context {
        var files: Files
        var dataFolder: URL
        var labels: [(id: String, title: String)] = []
        var statuses: [(id: String, title: String)] = []
        var sectionTypes: [(id: String, title: String)] = []
        var keywords: [String: String] = [:]
        var templateFolder: String?
        var seen: Set<String> = []
        var warnings: [ScrivenerWarning] = []
        var count = 0
    }

    private static func titles(in list: XMLTree.Node?, element: String) -> [(id: String, title: String)] {
        (list?.children(named: element) ?? []).compactMap { node in node.attributes["ID"].map { ($0, node.trimmedText) } }
    }

    private static func item(_ node: XMLTree.Node, depth: Int, inTemplates: Bool, _ context: inout Context) -> ScrivenerItem? {
        guard depth < maxDepth, context.count < maxItems else {
            if context.warnings.last?.message != tooMuch { context.warnings.append(ScrivenerWarning(uuid: nil, message: tooMuch)) }
            return nil
        }
        context.count += 1
        let uuid = node.attributes["UUID"] ?? node.attributes["ID"] ?? ""
        let typeName = node.attributes["Type"] ?? ""
        var item = ScrivenerItem(uuid: uuid, kind: kind(typeName), typeName: typeName)
        item.title = node.child("Title")?.trimmedText ?? ""
        item.created = node.attributes["Created"].flatMap(date)
        item.modified = node.attributes["Modified"].flatMap(date)
        let meta = node.child("MetaData")
        item.includeInCompile = meta?.child("IncludeInCompile")?.trimmedText == "Yes"
        item.iconName = meta?.child("IconFileName")?.trimmedText.nonEmpty
        item.label = named(meta?.child("LabelID")?.trimmedText, in: context.labels)
        item.status = named(meta?.child("StatusID")?.trimmedText, in: context.statuses)
        item.sectionType = named(meta?.child("SectionType")?.trimmedText, in: context.sectionTypes)
        item.keywords = (node.child("Keywords")?.children(named: "KeywordID") ?? []).compactMap { context.keywords[$0.trimmedText]?.nonEmpty }
        item.isTemplate = inTemplates || (context.templateFolder != nil && uuid == context.templateFolder)

        // The name is about to become part of a path, so it must be a plain one; and a second item claiming the
        // same folder gets nothing, so no document is ever read twice.
        if !isSafeName(uuid) {
            context.warnings.append(ScrivenerWarning(uuid: nil, message: "A binder item has an identifier that isn’t a plain name; its files were not read."))
        } else if !context.seen.insert(uuid).inserted {
            context.warnings.append(ScrivenerWarning(uuid: uuid, message: "Two binder items share one identifier; only the first was given the files."))
        } else {
            load(&item, fileExtension: meta?.child("FileExtension")?.trimmedText, cardExtension: meta?.child("IndexCardImageFileExtension")?.trimmedText, &context)
        }
        item.children = (node.child("Children")?.children(named: "BinderItem") ?? []).compactMap { Self.item($0, depth: depth + 1, inTemplates: item.isTemplate, &context) }
        return item
    }

    private static let tooMuch = "The binder is larger or more deeply nested than Sable reads; the rest was left out."

    private static func kind(_ type: String) -> ScrivenerItem.Kind {
        switch type {
        case "DraftFolder": return .draftFolder
        case "ResearchFolder": return .researchFolder
        case "TrashFolder": return .trashFolder
        case "Folder": return .folder
        case "Text": return .text
        case "Image": return .image
        case "PDF": return .pdf
        case "WebArchive": return .webArchive
        default: return .other
        }
    }

    private static func named(_ id: String?, in list: [(id: String, title: String)]) -> String? {
        guard let id, id != "-1" else { return nil }
        return list.first { $0.id == id }?.title.nonEmpty
    }

    /// Letters, digits, and hyphens: what a Scrivener identifier is made of, and nothing that can leave a folder.
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 64 && name.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-") }
    }

    private static func date(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: raw)
    }

    // MARK: An item's files

    private static func load(_ item: inout ScrivenerItem, fileExtension: String?, cardExtension: String?, _ context: inout Context) {
        let folder = context.dataFolder.appendingPathComponent(item.uuid, isDirectory: true)
        let files = context.files
        if let data = files.data(folder.appendingPathComponent("synopsis.txt"), limit: maxSynopsisBytes) {
            item.synopsis = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }
        for (name, isNotes) in [("content.rtf", false), ("notes.rtf", true)] {
            let url = folder.appendingPathComponent(name)
            guard files.exists(url) else { continue }
            guard let data = files.data(url, limit: maxDocumentBytes) else {
                context.warnings.append(ScrivenerWarning(uuid: item.uuid, message: "\(name) is too large or couldn’t be opened, and was left out."))
                continue
            }
            guard let converted = ScrivenerText.markdown(fromRTF: data) else {
                context.warnings.append(ScrivenerWarning(uuid: item.uuid, message: "\(name) isn’t readable rich text, and was left out."))
                continue
            }
            if isNotes { item.notes = converted.markdown.nonEmpty } else {
                item.text = converted.markdown.nonEmpty
                item.embeddedPictures = converted.pictures
            }
        }
        // A file's extension comes from the binder, so it gets the same scrutiny as the identifier.
        if [.image, .pdf, .webArchive, .other].contains(item.kind) {
            let ext = fileExtension ?? ""
            let url = folder.appendingPathComponent(ext.isEmpty ? "content" : "content." + ext)
            if ext.isEmpty || isSafeName(ext), files.exists(url) { item.attachment = url }
        }
        if let ext = cardExtension, isSafeName(ext), files.exists(folder.appendingPathComponent("card-image." + ext)) {
            item.cardImage = folder.appendingPathComponent("card-image." + ext)
        }
    }

    /// Reads ordinary files that really are inside the project: a link pointing out of it is treated as missing.
    private struct Files {
        let root: String
        init(package: URL) { root = package.resolvingSymlinksInPath().path }

        func exists(_ url: URL) -> Bool {
            let resolved = url.resolvingSymlinksInPath()
            guard resolved.path.hasPrefix(root + "/") else { return false }
            return (try? resolved.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
        }

        func data(_ url: URL, limit: Int) -> Data? {
            guard exists(url) else { return nil }
            let resolved = url.resolvingSymlinksInPath()
            guard let size = (try? resolved.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= limit else { return nil }
            return try? Data(contentsOf: resolved)
        }
    }
}

/// Scrivener's rich text, turned into Markdown by the same converter as File → Import Document.
enum ScrivenerText {
    /// Scrivener's own bookkeeping, left in the text as words: `<$Scr_Ps::0>`, `<!$Scr_Cs::1>`, `<$ScrKeepWithNext>`.
    static let markerPattern = "<!?\\$Scr[A-Za-z_]*(?:::[^<>\\n]{0,40})?>"
    /// A line holding only a separator (`#`, `* * *`, `⁂`, `⸻`, `---`): how writers mark a scene break inside a document.
    static let sceneBreakPattern = "^[ \\t]*(?:[#*⁂~•·◆❧⸻](?: ?[#*⁂~•·◆❧⸻]){0,4}|[-–—_]{3,}|(?:- ){2,}-)[ \\t]*$"
    private static let sceneBreakToken = "\u{E000}scenebreak\u{E000}"

    /// Nil when the data isn't rich text. It is only ever read as RTF, never sniffed, so a web page saved under a
    /// document's name is not loaded as one.
    static func markdown(fromRTF data: Data) -> (markdown: String, pictures: Int)? {
        guard data.starts(with: Data("{\\rtf".utf8)),
              let source = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else { return nil }
        let attributed = NSMutableAttributedString(attributedString: source)
        // Courier is a writing font to a novelist. Without this the converter would take whole chapters for code.
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, range, _ in
            guard let font = value as? NSFont, font.isFixedPitch else { return }
            attributed.addAttribute(.font, value: NSFontManager.shared.convert(font, toFamily: "Helvetica"), range: range)
        }
        if let markers = try? NSRegularExpression(pattern: markerPattern) {
            for match in markers.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length)).reversed() {
                attributed.deleteCharacters(in: match.range)
            }
        }
        if let breaks = try? NSRegularExpression(pattern: sceneBreakPattern, options: [.anchorsMatchLines]) {
            for match in breaks.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length)).reversed() {
                attributed.replaceCharacters(in: match.range, with: sceneBreakToken)
            }
        }
        let lines = RichTextMarkdown.markdown(from: attributed).components(separatedBy: "\n").map { $0.contains(sceneBreakToken) ? "* * *" : $0 }
        let markdown = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (markdown.isEmpty ? "" : markdown + "\n", pictureCount(in: data))
    }

    private static func pictureCount(in data: Data) -> Int {
        let needle = Data("\\pict".utf8)
        var count = 0, start = data.startIndex
        while let found = data.range(of: needle, in: start..<data.endIndex) {
            count += 1
            start = found.upperBound
        }
        return count
    }
}

/// A plain tree of the binder file's XML. External entities are never fetched, and a file that declares its own
/// entities is refused, so reading one can't reach the network or balloon in memory.
enum XMLTree {
    final class Node {
        let name: String
        let attributes: [String: String]
        var text = ""
        var children: [Node] = []
        init(name: String, attributes: [String: String]) { self.name = name; self.attributes = attributes }

        var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
        func child(_ name: String) -> Node? { children.first { $0.name == name } }
        func children(named name: String) -> [Node] { children.filter { $0.name == name } }
    }

    static func parse(_ data: Data) -> Node? {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let builder = Builder()
        parser.delegate = builder
        guard parser.parse(), !builder.refused else { return nil }
        return builder.root
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: Node?
        var stack: [Node] = []
        var refused = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            let node = Node(name: elementName, attributes: attributes)
            if let parent = stack.last { parent.children.append(node) } else if root == nil { root = node }
            stack.append(node)
        }
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) { _ = stack.popLast() }
        func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { stack.last?.text += String(decoding: CDATABlock, as: UTF8.self) }
        func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { refuse(parser) }
        func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { refuse(parser) }
        private func refuse(_ parser: XMLParser) { refused = true; parser.abortParsing() }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
