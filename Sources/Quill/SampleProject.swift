import Foundation

enum SampleProjectError: LocalizedError {
    case missing
    var errorDescription: String? { "This copy of Sable doesn’t include the sample project. Reinstalling Sable puts it back." }
}

/// A small finished Fiction Project that ships inside the app, so a new writer can see what Sable does before
/// writing a word. The copy in the app is never opened or edited: the writer gets their own copy in Documents,
/// made the same way every time, and that copy is theirs to change or throw away.
enum SampleProject {
    /// Where the sample sits among the app's resources.
    static let bundledFolderName = "Sample Project"
    /// What the writer's copy is called (a number follows when that name is taken).
    static let copyName = "Sable Sample Project"
    /// Remembers the copy made earlier, so asking again opens it instead of piling up more.
    static let rememberedKey = "sampleProjectPath"

    /// The sample inside the app, if this build has one.
    static func bundled(resourceURL: URL? = Bundle.main.resourceURL) -> URL? {
        guard let url = resourceURL?.appendingPathComponent(bundledFolderName, isDirectory: true), FictionProject.isProject(url) else { return nil }
        return url
    }

    /// The first chapter, in the writer's order: where a reader of the sample should start.
    static func firstChapter(in project: URL) -> URL? {
        let folder = FictionProject.folder(for: .chapter, in: project)
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { ManuscriptStats.fileExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
        return ManuscriptStats.orderedNames(names, order: FictionProject.load(project)?.chapterOrder).first.map { folder.appendingPathComponent($0) }
    }

    // MARK: Copying

    /// "Sable Sample Project", or "Sable Sample Project 2", 3, … when that name is already taken.
    static func destination(in parent: URL) -> URL {
        var url = parent.appendingPathComponent(copyName, isDirectory: true)
        var number = 2
        while taken(url) {
            url = parent.appendingPathComponent("\(copyName) \(number)", isDirectory: true)
            number += 1
        }
        return url
    }

    private static func taken(_ url: URL) -> Bool { (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil }

    /// Copies the sample into `parent` under a name that isn't taken, and returns the new folder. Nothing that is
    /// already there is touched. The copy is built beside it first and moved into place only once it is whole.
    @discardableResult
    static func copy(from source: URL, into parent: URL, now: Date = Date()) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".\(copyName)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: source, to: staging)
        try makeWritable(staging)
        try freshenSnapshotDates(in: staging, to: now)
        let target = destination(in: parent)
        try fm.moveItem(at: staging, to: target)
        return target
    }

    /// The copy made before if it is still a project, otherwise a new one in `parent`.
    static func prepare(from source: URL, into parent: URL, defaults: UserDefaults = .standard, now: Date = Date()) throws -> URL {
        if let earlier = remembered(defaults: defaults) { return earlier }
        let made = try copy(from: source, into: parent, now: now)
        defaults.set(made.path, forKey: rememberedKey)
        return made
    }

    static func remembered(defaults: UserDefaults = .standard) -> URL? {
        guard let path = defaults.string(forKey: rememberedKey) else { return nil }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        return FictionProject.isProject(url) ? url : nil
    }

    /// Files inside an app can be read-only; a writer's copy must be theirs to edit.
    private static func makeWritable(_ folder: URL) throws {
        let fm = FileManager.default
        let inside = (fm.enumerator(atPath: folder.path)?.allObjects as? [String]) ?? []
        for path in [folder.path] + inside.map({ folder.appendingPathComponent($0).path }) {
            let attributes = try fm.attributesOfItem(atPath: path)
            let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
            let isFolder = attributes[.type] as? FileAttributeType == .typeDirectory
            try fm.setAttributes([.posixPermissions: mode | (isFolder ? 0o700 : 0o600)], ofItemAtPath: path)
        }
    }

    /// The sample's snapshot is dated when the copy is made, so it reads as the writer's own recent snapshot and
    /// the daily automatic one doesn't land on top of it the moment the project opens.
    private static func freshenSnapshotDates(in project: URL, to date: Date) throws {
        let fm = FileManager.default
        let folders = (try? fm.contentsOfDirectory(at: Revisions.directory(in: project), includingPropertiesForKeys: nil)) ?? []
        for folder in folders {
            let file = folder.appendingPathComponent("snapshot.json")
            guard let data = try? Data(contentsOf: file), var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
            object["date"] = ISO8601DateFormatter().string(from: date)
            try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: file, options: .atomic)
        }
    }
}
