import AppKit
import SwiftUI
import QuillCore

/// Switching between the editor and Reading Mode keeps the writer's place: the position map in both directions, then
/// the two real views side by side in a window.
@main enum ReadingPositionChecks {
    static let chapter = """
    ---
    type: chapter
    status: draft
    ---
    # The Harbor Bell

    <!-- scene: arrival
    synopsis: Ines comes back -->
    The bell rang **twice** before dawn,
    which meant someone had *lied*.

    ## Low Tide

    ![The quay at dawn](images/quay.png)

    Ines counted the boats. <!-- check the number --> Eleven, not twelve.

    * * *

    > Counting was how the harbor kept its dead.

    - a rope
    - [ ] a ledger

    <!-- cut this? -->
    The last light went out.
    """

    @MainActor static func main() {
        _ = NSApplication.shared
        checkMap()
        checkViews()
        print("Reading position checks passed")
    }

    // MARK: The map

    @MainActor static func checkMap() {
        let source = chapter as NSString
        let page = MarkdownReading.page(chapter, family: "Charter", size: 19, spacing: 0.28)
        let text = page.text.string as NSString
        let map = page.map
        func sourceStart(_ needle: String) -> Int { let r = source.range(of: needle); precondition(r.location != NSNotFound, needle); return r.location }
        func pageStart(_ needle: String) -> Int { let r = text.range(of: needle); precondition(r.location != NSNotFound, needle); return r.location }

        // The blocks say where in the file they came from, front matter and notes counted
        let located = MarkdownBlocks.located(chapter)
        precondition(located.map(\.block) == MarkdownBlocks.parse(chapter), "Locating changes nothing about what is read")
        let pieces = located.map { source.substring(with: $0.range) }
        precondition(pieces == [
            "# The Harbor Bell",
            "The bell rang **twice** before dawn,\nwhich meant someone had *lied*.",
            "## Low Tide",
            "![The quay at dawn](images/quay.png)",
            "Ines counted the boats. <!-- check the number --> Eleven, not twelve.",
            "* * *",
            "> Counting was how the harbor kept its dead.",
            "- a rope",
            "- [ ] a ledger",
            "The last light went out.",
        ], "Each block's stretch of the file: \(pieces)")
        precondition(map.entries.count == located.count)

        // The start of every block goes to the start of the same block, both ways
        let starts: [(file: String, page: String)] = [
            ("# The Harbor Bell", "The Harbor Bell"), ("The bell rang", "The bell rang twice"), ("## Low Tide", "Low Tide"),
            ("![The quay", "[Image: The quay at dawn]"), ("Ines counted", "Ines counted"), ("* * *", "*  *  *"),
            ("> Counting", "Counting was"), ("- a rope", "•  a rope"), ("- [ ] a ledger", "☐  a ledger"), ("The last light", "The last light"),
        ]
        for pair in starts {
            let inFile = sourceStart(pair.file), onPage = pageStart(pair.page)
            precondition(map.pageOffset(forSource: inFile) == onPage, "\(pair.file) opens at its place on the page: \(map.pageOffset(forSource: inFile)) vs \(onPage)")
            precondition(map.sourceOffset(forPage: onPage) == inFile, "\(pair.page) goes back to its place in the file: \(map.sourceOffset(forPage: onPage)) vs \(inFile)")
        }

        // What the page leaves out lands on the next thing it shows
        precondition(map.pageOffset(forSource: 0) == 0, "Front matter: the heading")
        precondition(map.pageOffset(forSource: sourceStart("status: draft")) == pageStart("The Harbor Bell"))
        precondition(map.pageOffset(forSource: sourceStart("synopsis: Ines")) == pageStart("The bell rang"), "A note: the paragraph under it")
        precondition(map.pageOffset(forSource: sourceStart("<!-- cut this?")) == pageStart("The last light"))
        precondition(map.pageOffset(forSource: sourceStart("* * *") - 1) == pageStart("*  *  *"), "A blank line: the scene break under it")
        precondition(map.pageOffset(forSource: source.length + 50) == text.length, "Past the end: the end of the page")
        precondition(map.sourceOffset(forPage: text.length + 50) == source.length, "And back")

        // A place inside a block stays inside it, close to the same words, and nothing ever runs backwards
        let secondLine = sourceStart("which meant")
        let onPage = map.pageOffset(forSource: secondLine)
        precondition(abs(onPage - pageStart("which meant")) <= 6, "Partway through a paragraph: \(onPage) vs \(pageStart("which meant"))")
        precondition(abs(map.sourceOffset(forPage: pageStart("Eleven")) - sourceStart("Eleven")) <= 28, "A note inside a paragraph shifts the place by no more than itself")
        var lastPage = 0
        for offset in 0...source.length {
            let there = map.pageOffset(forSource: offset)
            precondition(there >= lastPage && there <= text.length, "Forward in the file is never backward on the page (at \(offset))")
            lastPage = there
            if let entry = map.entries.first(where: { NSLocationInRange(offset, $0.source) }) {
                precondition(NSLocationInRange(there, entry.page), "Inside a block in the file is inside it on the page (at \(offset))")
                precondition(NSLocationInRange(map.sourceOffset(forPage: there), entry.source), "And comes back to the same block (at \(offset))")
            }
        }
        var lastSource = 0
        for offset in 0...text.length {
            let there = map.sourceOffset(forPage: offset)
            precondition(there >= lastSource && there <= source.length, "Forward on the page is never backward in the file (at \(offset))")
            lastSource = there
        }

        // Nothing to show, and nothing but what is hidden
        precondition(ReadingMap().pageOffset(forSource: 40) == 0 && ReadingMap().sourceOffset(forPage: 40) == 0)
        let hidden = MarkdownReading.page("---\ntype: note\n---\n<!-- only a note -->\n", family: "Charter", size: 19, spacing: 0.28)
        precondition(hidden.map.entries.isEmpty && hidden.map.pageOffset(forSource: 10) == 0)
        // An unclosed note hides the rest, and an unclosed code block runs to the end
        precondition(MarkdownBlocks.located("One.\n\n<!-- never closed\nTwo.").map { $0.range } == [NSRange(location: 0, length: 4)])
        precondition(MarkdownBlocks.located("```\nlet a = 1\nlet b = 2").map { $0.range } == [NSRange(location: 0, length: 23)])
    }

    // MARK: The views

    final class Mode: ObservableObject {
        @Published var reading = false
        @Published var text = ""
        @Published var size = 19.0
    }

    struct Page: View {
        @ObservedObject var mode: Mode
        let commands: EditorCommands
        let place: PagePlace
        var body: some View {
            ZStack {
                NativeEditor(text: $mode.text, review: false, words: "", fontSize: mode.size, pageWidth: 680, commands: commands, readOnly: mode.reading, place: place)
                    .opacity(mode.reading ? 0 : 1)
                if mode.reading { ReadingView(text: mode.text, family: "Charter", size: mode.size, spacing: 0.28, width: 680, place: place) }
            }
        }
    }

    @MainActor static func spin(_ seconds: TimeInterval = 0.05) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

    @MainActor static func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for child in view.subviews { if let match = find(type, in: child) { return match } }
        return nil
    }

    /// A long chapter: front matter, then scenes of numbered paragraphs with headings, notes, pictures, and scene breaks.
    static func longChapter(paragraphs: Int) -> String {
        var out = "---\ntype: chapter\nstatus: draft\ntags: [harbor, bell, tide]\n---\n# A Long Chapter\n\n"
        for number in 1...paragraphs {
            if number % 9 == 0 { out += "<!-- scene \(number / 9)\nsynopsis: what happens next, at some length, over\nseveral lines\nthat Reading Mode leaves out -->\n" }
            if number % 14 == 0 { out += "## Part \(number / 14)\n\n" }
            if number % 11 == 0 { out += "![Map \(number)](images/map-\(number).png)\n\n" }
            if number % 17 == 0 { out += "* * *\n\n" }
            out += "Paragraph \(number) begins here. " + String(repeating: "The **harbor** bell rang twice before *dawn*, and nobody on the quay looked up from the nets. ", count: 2 + number % 4) + "\n\n"
        }
        return out
    }

    /// Which numbered paragraph a place in the file is in or just before.
    static func paragraphNumber(at offset: Int, in text: String) -> Int {
        let ns = text as NSString
        let found = ns.range(of: "Paragraph ", options: [], range: NSRange(location: min(offset, ns.length), length: ns.length - min(offset, ns.length)))
        let before = ns.range(of: "Paragraph ", options: .backwards, range: NSRange(location: 0, length: min(offset + 10, ns.length)))
        // Inside a paragraph, that paragraph; in the hidden or blank stretch above one, the one below.
        var start = found.location
        if before.location != NSNotFound, ns.paragraphRange(for: NSRange(location: before.location, length: 0)).contains(min(offset, ns.length - 1)) { start = before.location }
        guard start != NSNotFound else { return -1 }
        return Int(ns.substring(with: NSRange(location: start + 10, length: min(6, ns.length - start - 10))).prefix { $0.isNumber }) ?? -1
    }

    @MainActor static func checkViews() {
        let mode = Mode()
        mode.text = longChapter(paragraphs: 400)
        let commands = EditorCommands()
        let place = PagePlace()
        let host = NSHostingView(rootView: Page(mode: mode, commands: commands, place: place))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .resizable], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        spin()
        guard let editor = commands.editor, let editorScroll = editor.enclosingScrollView else { preconditionFailure("The editor is on screen") }
        let editorClip = editorScroll.contentView

        // SwiftUI builds and removes the reading page a beat after the mode changes, and a slow machine takes longer.
        func waitFor(_ condition: () -> Bool, timeout: TimeInterval = 10) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while true {
                host.layoutSubtreeIfNeeded()
                spin()
                if condition() { return true }
                if Date() > deadline { return false }
            }
        }
        func readingView() -> ReadingTextView {
            guard waitFor({ find(ReadingTextView.self, in: host)?.topLine() != nil }), let view = find(ReadingTextView.self, in: host) else { preconditionFailure("The reading page is on screen") }
            return view
        }
        func scrollEditor(toParagraph number: Int, below: CGFloat) {
            let location = (mode.text as NSString).range(of: "Paragraph \(number) begins").location
            precondition(editor.showLine(holding: location, below: below))
        }
        func editorTop() -> (paragraph: Int, below: CGFloat) {
            let top = editor.topLine()!
            return (paragraphNumber(at: top.character, in: mode.text), top.below)
        }
        func readingTop(_ view: ReadingTextView) -> (paragraph: Int, below: CGFloat) {
            let top = view.topLine()!
            return (paragraphNumber(at: view.map.sourceOffset(forPage: top.character), in: mode.text), top.below)
        }
        func setReading(_ on: Bool) {
            mode.reading = on
            host.layoutSubtreeIfNeeded()
            spin()
            if !on { precondition(waitFor { find(ReadingTextView.self, in: host) == nil }, "The reading page is gone") }
        }

        for (width, size) in [(900.0, 19.0), (620.0, 15.0), (1300.0, 26.0)] {
            window.setContentSize(NSSize(width: width, height: 700))
            mode.size = size
            host.layoutSubtreeIfNeeded()
            spin()
            for paragraph in [3, 57, 180, 333] {
                // Into Reading Mode: the paragraph at the top of the window is at the top there, at the same height
                scrollEditor(toParagraph: paragraph, below: -12)
                editor.setSelectedRange(NSRange(location: 40, length: 0))
                let before = editorTop()
                let editorY = editorClip.bounds.origin.y
                precondition(before.paragraph == paragraph, "The check put paragraph \(paragraph) at the top: \(before)")
                setReading(true)
                let reading = readingView()
                let shown = readingTop(reading)
                precondition(shown.paragraph == paragraph, "Reading Mode opens on paragraph \(paragraph), not \(shown.paragraph) (width \(width), size \(size))")
                precondition(abs(shown.below - before.below) < 1, "…at the same height: \(shown.below) vs \(before.below)")

                // Straight back: the editor hasn't moved at all, and neither has the caret
                setReading(false)
                precondition(editorClip.bounds.origin.y == editorY, "Back without scrolling leaves the editor where it was")
                precondition(editor.selectedRange() == NSRange(location: 40, length: 0), "The caret stays put")

                // Read on, then back: the editor shows what the reading page showed, at the same height
                setReading(true)
                let again = readingView()
                let ahead = (mode.text as NSString).range(of: "Paragraph \(paragraph + 23) begins").location
                precondition(again.showLine(holding: again.map.pageOffset(forSource: ahead), below: 31))
                again.letGoOfPlace()
                let left = readingTop(again)
                setReading(false)
                let landed = editorTop()
                precondition(landed.paragraph == left.paragraph, "The editor opens on paragraph \(left.paragraph), not \(landed.paragraph) (width \(width), size \(size))")
                precondition(abs(landed.below - left.below) < 1, "…at the same height: \(landed.below) vs \(left.below)")
                precondition(editor.selectedRange() == NSRange(location: 40, length: 0), "Scrolling the reading page never moves the caret")
            }
        }

        // A click on the reading page is the one thing that moves the caret
        scrollEditor(toParagraph: 90, below: 0)
        setReading(true)
        let clicked = readingView()
        let target = (mode.text as NSString).range(of: "Paragraph 91 begins").location
        let onPage = clicked.map.pageOffset(forSource: target)
        clicked.noteClick()
        clicked.setSelectedRange(NSRange(location: onPage, length: 0))
        setReading(false)
        precondition(editor.selectedRange() == NSRange(location: target, length: 0), "The caret follows a click: \(editor.selectedRange()) vs \(target)")

        // The top and the end of a chapter stay the top and the end
        // (AppKit can leave a text view's frame away from zero, so the top is wherever the page begins.)
        editorClip.scroll(to: NSPoint(x: 0, y: editorClip.documentRect.minY))
        editorScroll.reflectScrolledClipView(editorClip)
        precondition(editor.pageAnchor()?.offset == 0, "The check scrolled the editor to its first line")
        setReading(true)
        let topClip = readingView().enclosingScrollView!.contentView
        precondition(topClip.bounds.minY == topClip.documentRect.minY, "The top of the chapter is the top of the page: \(topClip.bounds) in \(topClip.documentRect)")
        setReading(false)
        scrollEditor(toParagraph: 400, below: 300)
        precondition(abs(editorClip.bounds.maxY - editorClip.documentRect.maxY) < 8, "The check scrolled the editor to its end: \(editorClip.bounds) in \(editorClip.documentRect)")
        setReading(true)
        let endClip = readingView().enclosingScrollView!.contentView
        precondition(abs(endClip.bounds.maxY - endClip.documentRect.maxY) < 8, "The end of the chapter is the end of the page: \(endClip.bounds) in \(endClip.documentRect)")
        setReading(false)

        // A novel: Reading Mode opens partway through without laying out more than it must. Times are printed, not
        // judged; the first is what opening at the top costs, which is what it always cost.
        mode.text = longChapter(paragraphs: 1500)
        host.layoutSubtreeIfNeeded()
        spin(0.3)
        let words = mode.text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        for paragraph in [1, 750, 1490] {
            scrollEditor(toParagraph: paragraph, below: -5)
            let started = Date()
            mode.reading = true
            host.layoutSubtreeIfNeeded()
            let took = Date().timeIntervalSince(started)
            let novel = readingView()
            precondition(readingTop(novel).paragraph == paragraph, "Paragraph \(paragraph) of a novel: \(readingTop(novel))")
            setReading(false)
            print(String(format: "Opening Reading Mode at paragraph %d of 1500 (%d words) took %.0f ms", paragraph, words, took * 1000))
        }
    }
}
