import Foundation

@main enum RecentFilesChecks {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("quill-recent-\(getpid())")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let a = root.appendingPathComponent("A.md"), b = root.appendingPathComponent("B.md"), c = root.appendingPathComponent("C.md")
        for url in [a, b, c] { try Data("x".utf8).write(to: url) }

        var stored = ""
        precondition(RecentFiles.existing(in: stored).isEmpty, "Nothing at first")
        stored = RecentFiles.adding(a, to: stored)
        stored = RecentFiles.adding(b, to: stored)
        precondition(RecentFiles.existing(in: stored).map(\.lastPathComponent) == ["B.md", "A.md"], "Newest first")
        let same = RecentFiles.adding(b, to: stored)
        precondition(same == stored, "A file that stays open changes nothing, so it costs no write")
        stored = RecentFiles.adding(a, to: stored)
        precondition(RecentFiles.existing(in: stored).map(\.lastPathComponent) == ["A.md", "B.md"], "Opening a file again moves it to the front, once")

        for n in 0..<30 { stored = RecentFiles.adding(root.appendingPathComponent("F\(n).md"), to: stored) }
        precondition(RecentFiles.paths(in: stored).count == RecentFiles.limit, "The list is capped")
        precondition(RecentFiles.paths(in: stored).first?.hasSuffix("F29.md") == true)

        stored = RecentFiles.adding(a, to: "")
        stored = RecentFiles.adding(b, to: stored)
        try fm.removeItem(at: a)
        precondition(RecentFiles.existing(in: stored).map(\.lastPathComponent) == ["B.md"], "A deleted file drops out")

        let trashed = URL(fileURLWithPath: NSHomeDirectory() + "/.Trash/Gone.md")
        precondition(RecentFiles.adding(trashed, to: "") == "", "Files in the Trash are never recorded")
        precondition(RecentFiles.adding(URL(string: "https://example.com/x.md")!, to: "") == "", "Only files on disk are recorded")
        precondition(RecentFiles.paths(in: "not json").isEmpty && RecentFiles.existing(in: "{").isEmpty, "A damaged list reads as empty")
        precondition(RecentFiles.adding(c, to: "not json") != "not json", "…and is replaced by a good one")
        // Recent projects: the same list, for folders, kept only while each is still a project.
        let p1 = root.appendingPathComponent("One", isDirectory: true), p2 = root.appendingPathComponent("Two", isDirectory: true)
        for url in [p1, p2] {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            try Data("{}".utf8).write(to: url.appendingPathComponent("marker"))
        }
        let isProject: (URL) -> Bool = { fm.fileExists(atPath: $0.appendingPathComponent("marker").path) }
        var projects = RecentProjects.adding(p1, to: "")
        projects = RecentProjects.adding(p2, to: projects)
        precondition(RecentProjects.existing(in: projects, isProject: isProject).map(\.lastPathComponent) == ["Two", "One"], "Newest project first")
        precondition(RecentProjects.adding(p2, to: projects) == projects, "Staying in a project costs no write")
        try fm.removeItem(at: p1.appendingPathComponent("marker"))
        precondition(RecentProjects.existing(in: projects, isProject: isProject).map(\.lastPathComponent) == ["Two"], "A folder that is no longer a project drops out")
        precondition(RecentProjects.removing(p2, from: projects) != projects && RecentProjects.existing(in: RecentProjects.removing(p2, from: projects), isProject: isProject).isEmpty, "A project can be taken off the list")
        precondition(RecentProjects.removing(root, from: projects) == projects, "Removing one that isn't listed changes nothing")
        for n in 0..<20 { projects = RecentProjects.adding(root.appendingPathComponent("P\(n)", isDirectory: true), to: projects) }
        precondition(RecentFiles.paths(in: projects).count == RecentProjects.limit, "The project list is capped")
        precondition(RecentFiles.paths(in: RecentFiles.adding(a, to: "")).count == 1 && RecentFiles.storageKey != RecentProjects.storageKey, "Files and projects are kept apart")

        print("Passed: recent projects (order, removal, former projects, cap) and recent files (order, no rewrite when unchanged, cap, deleted and Trash files, damaged storage).")
    }
}
