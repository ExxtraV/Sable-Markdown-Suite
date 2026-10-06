import SwiftUI
import AppKit
import QuillCore

@MainActor
enum MarkdownReading {
    /// Reading Mode draws exactly what the shared Markdown reader finds, the same blocks the exports use.
    /// `ink`, `muted`, and `quiet` are the body color, the color for quotes and notes, and the color for ornaments; a
    /// themed page passes its own (see ThemePalette), and the cards use the system's.
    static func render(_ source: String, family: String, size: Double, spacing: Double,
                       ink: NSColor = .labelColor, muted: NSColor = .secondaryLabelColor, quiet: NSColor = .tertiaryLabelColor) -> NSAttributedString {
        page(source, family: family, size: size, spacing: spacing, ink: ink, muted: muted, quiet: quiet).text
    }

    /// `render`, with a map from places in `source` to places on the page (see ReadingMap).
    static func page(_ source: String, family: String, size: Double, spacing: Double,
                     ink: NSColor = .labelColor, muted: NSColor = .secondaryLabelColor, quiet: NSColor = .tertiaryLabelColor) -> (text: NSAttributedString, map: ReadingMap) {
        let base = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) ?? .systemFont(ofSize: size)
        let mono = NSFont.monospacedSystemFont(ofSize: size * 0.88, weight: .regular)
        let output = NSMutableAttributedString()
        func paragraphStyle(indent: CGFloat, centered: Bool) -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = size * spacing
            style.paragraphSpacing = size * 0.8
            style.headIndent = indent
            style.firstLineHeadIndent = indent
            if centered { style.alignment = .center }
            return style
        }
        func append(_ runs: [MarkdownRun], font: NSFont, color: NSColor? = nil, indent: CGFloat = 0, centered: Bool = false, prefix: String = "") {
            let style = paragraphStyle(indent: indent, centered: centered)
            let color = color ?? ink
            if !prefix.isEmpty {
                output.append(NSAttributedString(string: prefix, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]))
            }
            for run in runs {
                var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
                var traits: NSFontTraitMask = []
                if run.bold { traits.insert(.boldFontMask) }
                if run.italic { traits.insert(.italicFontMask) }
                attributes[.font] = NSFontManager.shared.convert(font, toHaveTrait: traits)
                if run.code { attributes[.font] = mono }
                if run.strike { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
                if let address = run.link, let link = URL(string: address), ["https", "http", "mailto"].contains(link.scheme?.lowercased() ?? "") {
                    attributes[.link] = link
                    attributes[.foregroundColor] = NSColor.linkColor
                }
                output.append(NSAttributedString(string: run.text, attributes: attributes))
            }
            output.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: style]))
        }
        var map = ReadingMap()
        for located in MarkdownBlocks.located(source) {
            let start = output.length
            defer { map.add(source: located.range, page: NSRange(location: start, length: output.length - start)) }
            switch located.block {
            case let .paragraph(runs): append(runs, font: base)
            case let .heading(level, runs):
                let headingSize = size + Double(max(1, 5 - level)) * 3
                let font = NSFontManager.shared.font(withFamily: family, traits: .boldFontMask, weight: 9, size: headingSize) ?? .systemFont(ofSize: headingSize, weight: .semibold)
                append(runs.map { var run = $0; run.bold = false; return run }, font: font)
            case let .quote(runs): append(runs, font: base, color: muted, indent: 18)
            case let .bullet(runs, depth): append(runs, font: base, indent: CGFloat(depth) * 18, prefix: "•  ")
            case let .numbered(number, runs, depth): append(runs, font: base, indent: CGFloat(depth) * 18, prefix: "\(number).  ")
            case let .task(done, runs, depth): append(runs, font: base, indent: CGFloat(depth) * 18, prefix: (done ? "☑" : "☐") + "  ")
            case .sceneBreak: append([MarkdownRun(text: "*  *  *")], font: base, color: quiet, centered: true)
            case let .code(text):
                for line in text.components(separatedBy: "\n") { append([MarkdownRun(text: line)], font: mono) }
            case let .table(rows, _):
                for row in rows { append([MarkdownRun(text: row.joined(separator: "   "))], font: mono, color: muted) }
            case let .image(alt, _):
                append([MarkdownRun(text: alt.isEmpty ? "[Image]" : "[Image: \(alt)]", italic: true)], font: base, color: muted)
            }
        }
        return (output, map)
    }
}

struct ReadingView: NSViewRepresentable {
    @AppStorage("writingTheme") private var themeName = "graphite"
    @AppStorage("editorZoom") private var globalZoom = 1.0
    @Environment(\.colorSchemeContrast) private var contrast
    var zoom: Double? = nil
    var zoomKey: String = WritingZoom.mainKey
    let text: String
    let family: String
    let size: Double
    let spacing: Double
    var width: Double = 680
    var darker = false
    /// Let the page behind show through (the edge shading is drawn there).
    var transparent = false
    var sidebarGesture: (() -> Void)? = nil
    /// Shared with the editor this page stands in for, so the page opens where the editor was and hands its place back.
    var place: PagePlace? = nil
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = WritingScrollView(frame: NSRect(x: 0, y: 0, width: 700, height: 600))
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.zoomKey = zoomKey
        scroll.sidebarGesture = sidebarGesture
        let view = ReadingTextView(frame: scroll.contentView.bounds)
        view.isEditable = false; view.isSelectable = true
        view.isVerticallyResizable = true; view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize.height = CGFloat.greatestFiniteMagnitude
        view.delegate = context.coordinator
        // The place is found with the classic layout manager, as the editor and pinch-to-zoom already do.
        _ = view.layoutManager
        scroll.documentView = view
        view.place = place
        if let place, let editor = place.editor, let anchor = editor.pageAnchor() {
            view.opening = anchor
            place.opened = (editor.layoutSignature, .nan)
        }
        return scroll
    }
    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        (scroll.documentView as? ReadingTextView)?.handBackPlace()
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url = (link as? URL) ?? (link as? String).flatMap(URL.init(string:))
            guard let url else { return false }
            NSWorkspace.shared.open(url)
            return true
        }
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? ReadingTextView else { return }
        (scroll as? WritingScrollView)?.zoomKey = zoomKey
        (scroll as? WritingScrollView)?.sidebarGesture = sidebarGesture
        let zoom = self.zoom ?? globalZoom
        view.columnWidth = width * zoom
        view.updateMargins()
        view.appearance = darker ? NSAppearance(named: .darkAqua) : nil
        let theme = WritingTheme.named(darker ? "midnight" : themeName)
        view.backgroundColor = transparent ? .clear : theme.background
        view.drawsBackground = !transparent
        scroll.drawsBackground = !transparent
        scroll.contentView.drawsBackground = !transparent
        let increased = contrast == .increased
        let key = "\(family)|\(size)|\(spacing)|\(zoom)|\(theme.id)|\(increased)|\(text)"
        if view.renderKey != key {
            // Quotes and ornaments are the theme's ink, quieter by the amounts ThemePalette sets.
            let levels = ThemePalette.dimLevels(dark: theme.dark, increasedContrast: increased)
            let rendered = MarkdownReading.page(text, family: family, size: size * zoom, spacing: spacing, ink: theme.foreground,
                                                muted: theme.foreground.withAlphaComponent(levels.muted), quiet: theme.foreground.withAlphaComponent(levels.marker))
            // Another document's text has no use for the place this page opened at.
            if let shown = view.source, shown != text { view.letGoOfPlace() }
            view.source = text
            view.textStorage?.setAttributedString(rendered.text)
            view.map = rendered.map
            view.renderKey = key
            view.settleOpening()
        }
        (scroll as? WritingScrollView)?.zoomDidApply(zoom)
    }
}
final class ReadingTextView: NSTextView, PageHolding {
    var columnWidth = 680.0
    var renderKey = ""
    var map = ReadingMap()
    /// The Markdown now on the page.
    var source: String?
    weak var place: PagePlace?
    /// Where the editor was when this page opened. SwiftUI gives the view its real size only after making it, so the
    /// place is put again whenever the size changes, until the reader scrolls or clicks.
    var opening: PageAnchor? { didSet { if opening == nil { placedY = nil } } }
    /// Where the page was scrolled to when the place was last put; anywhere else means the reader has moved it.
    private var placedY: CGFloat?
    private var settling = false
    /// The reader clicked on the page, so the caret follows them back to the editor.
    private var clicked = false

    func updateMargins() { textContainerInset = NSSize(width: max(26, (bounds.width - columnWidth) / 2), height: 36) }
    override func setFrameSize(_ newSize: NSSize) { super.setFrameSize(newSize); updateMargins(); settleOpening() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); settleOpening() }
    override func mouseDown(with event: NSEvent) { noteClick(); super.mouseDown(with: event) }
    func noteClick() { clicked = true; opening = nil }
    override func keyDown(with event: NSEvent) { opening = nil; super.keyDown(with: event) }
    func letGoOfPlace() { opening = nil }

    /// Puts the paragraph that topped the editor at the same height here. Never animated.
    func settleOpening() {
        guard let opening, !settling, window != nil, let clip = enclosingScrollView?.contentView else { return }
        if let placedY, abs(clip.bounds.origin.y - placedY) > 0.5 { self.opening = nil; return }
        settling = true
        defer { settling = false }
        if showLine(holding: map.pageOffset(forSource: opening.offset), below: opening.below) {
            placedY = clip.bounds.origin.y
            place?.opened?.readingY = clip.bounds.origin.y
        }
    }

    /// Leaving Reading Mode: the editor takes the paragraph at the top of this page, at the same height. If the
    /// reader never moved the page, the editor is still exactly where it was and is left alone.
    func handBackPlace() {
        guard let place else { return }
        defer { place.opened = nil }
        let caret = clicked ? map.sourceOffset(forPage: selectedRange().location) : nil
        if let opened = place.opened, let editor = place.editor, let clip = enclosingScrollView?.contentView,
           opened.editor == editor.layoutSignature, abs(clip.bounds.origin.y - opened.readingY) < 0.5 {
            if let caret { editor.moveCaretQuietly(to: caret) }
            return
        }
        guard let top = topLine() else { return }
        let anchor = PageAnchor(offset: map.sourceOffset(forPage: top.character), below: top.below, caret: caret)
        if let editor = place.editor { editor.open(at: anchor) } else { place.waiting = anchor }
    }
}
