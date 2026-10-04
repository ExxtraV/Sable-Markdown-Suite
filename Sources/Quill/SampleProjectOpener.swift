import AppKit

/// Opens the sample Fiction Project: the writer's own copy in Documents (made the first time, found after that),
/// shown on the writing desk for this session only, starting at its first chapter. Their saved writing folder never changes.
@MainActor enum SampleProjectOpener {
    static func open(browser: FolderBrowser) {
        do {
            guard let source = SampleProject.bundled() else { throw SampleProjectError.missing }
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let project = try SampleProject.prepare(from: source, into: documents)
            browser.visit(project)
            guard let chapter = SampleProject.firstChapter(in: project) else { return }
            let current = (NSApp.mainWindow ?? NSApp.keyWindow)?.windowController?.document as? NSDocument
            SingleDocumentCoordinator.shared.switchDocument(from: current, to: chapter) { error in
                if let error { NSApp.presentError(error) }
            }
        } catch { NSApp.presentError(error) }
    }
}
