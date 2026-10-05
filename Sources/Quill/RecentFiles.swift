import Foundation

/// The optional Recent tab's list: the files that have been open in Sable, newest first. It is kept as a small
/// JSON string so it can live in UserDefaults through @AppStorage, and it is only recorded while the tab is turned on.
enum RecentFiles {
    static let storageKey = "recentOpens"
    static let enabledKey = "showRecentTab"
    static let limit = 15

    static func paths(in stored: String) -> [String] {
        guard let data = stored.data(using: .utf8), let paths = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return paths
    }

    fileprivate static func encode(_ paths: [String]) -> String {
        guard let data = try? JSONEncoder().encode(paths), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    /// `url` moved to the front. Returns `stored` itself when nothing changes, so a file that stays open costs no write.
    /// Files in the Trash and anything that isn't a file on disk are never recorded.
    static func adding(_ url: URL, to stored: String, limit: Int = RecentFiles.limit) -> String {
        guard url.isFileURL, !url.pathComponents.contains(where: { $0 == ".Trash" || $0 == ".Trashes" }) else { return stored }
        let path = url.standardizedFileURL.path
        var paths = self.paths(in: stored)
        if paths.first == path { return stored }
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        return encode(Array(paths.prefix(limit)))
    }

    /// The files still on disk, newest first. A file that was moved or deleted simply drops out of the list.
    static func existing(in stored: String, fileManager: FileManager = .default) -> [URL] {
        paths(in: stored).filter { fileManager.fileExists(atPath: $0) }.map { URL(fileURLWithPath: $0) }
    }
}

/// The Fiction Projects opened lately, newest first, wherever they live. This is how a project outside the
/// writing folder is found again: the desk's Recent Projects section and File → Open Recent Project read it.
enum RecentProjects {
    static let storageKey = "recentProjects"
    static let expandedKey = "recentProjectsExpanded"
    static let limit = 8

    static func adding(_ project: URL, to stored: String) -> String { RecentFiles.adding(project, to: stored, limit: limit) }

    static func removing(_ project: URL, from stored: String) -> String {
        let path = project.standardizedFileURL.path
        let paths = RecentFiles.paths(in: stored)
        return paths.contains(path) ? RecentFiles.encode(paths.filter { $0 != path }) : stored
    }

    /// The ones that are still Fiction Projects. A project that was moved, deleted, or turned back into a plain
    /// folder simply drops out of the list.
    static func existing(in stored: String, isProject: (URL) -> Bool) -> [URL] {
        RecentFiles.paths(in: stored).map { URL(fileURLWithPath: $0, isDirectory: true) }.filter(isProject)
    }
}
