import AppKit

/// File → Open Fiction Project…: puts a Fiction Project that lives anywhere on the writing desk and opens its
/// first chapter. Outside the writing folder it is shown for this session only; the saved writing folder never changes.
/// A folder that isn't a project yet can become one on the way in, with nothing in it moved or changed.
@MainActor enum FictionProjectOpener {
    static func open(browser: FolderBrowser) {
        let panel = NSOpenPanel()
        panel.title = "Open a Fiction Project"
        panel.message = "Choose a Fiction Project’s folder. It can be anywhere, not only in your writing folder."
        panel.prompt = "Open"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        do {
            guard let project = try project(for: chosen) else { return }
            show(project, browser: browser)
        } catch { NSApp.presentError(error) }
    }

    /// The project `folder` is, or is inside. Failing that, the folder itself once the writer agrees to make it one.
    private static func project(for folder: URL) throws -> URL? {
        if let found = FictionProject.enclosingProject(of: folder) { return found }
        let alert = NSAlert()
        alert.messageText = "“\(folder.lastPathComponent)” isn’t a Fiction Project yet. Make it one?"
        alert.informativeText = "Nothing is moved or changed. Standard folders (Manuscript, Characters, Locations, World, Notes, Images) are only added if you choose to, and existing ones are reused. You can convert it back at any time."
        alert.addButton(withTitle: "Add Standard Folders")
        alert.addButton(withTitle: "Keep My Folders As They Are")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: try FictionProject.adopt(folder, addStandardFolders: true)
        case .alertSecondButtonReturn: try FictionProject.adopt(folder, addStandardFolders: false)
        default: return nil
        }
        return folder
    }

    static func show(_ project: URL, browser: FolderBrowser) {
        if let writing = browser.writingFolder, FolderMove.isInside(project, of: writing) {
            browser.endVisit()
            browser.navigate(project, leavingProject: true)
        } else {
            browser.visit(project)
        }
        guard let first = SampleProject.firstChapter(in: project) ?? Optional(FictionProject.guideURL(in: project)), FileManager.default.fileExists(atPath: first.path) else { return }
        let current = (NSApp.mainWindow ?? NSApp.keyWindow)?.windowController?.document as? NSDocument
        SingleDocumentCoordinator.shared.switchDocument(from: current, to: first) { error in
            if let error { NSApp.presentError(error) }
        }
    }
}
