import Foundation

/// The one description of what a Markdown line is. The editor's styling, Reading Mode, and every export ask these
/// same questions, so a scene break, a note, or a list item is the same thing everywhere.
public enum MarkdownLines {
    /// `---`, `***`, `___`, or `* * *` on a line of its own.
    public static func isSceneBreak(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    /// A bare "****" is what pressing ⌘B on nothing types, so it stays bold rather than becoming a scene break.
    public static func isRule(_ line: String) -> Bool {
        isSceneBreak(line) && line.trimmingCharacters(in: .whitespaces) != "****"
    }

    /// `<!-- … -->`, an author's note that never reaches Reading Mode or an export.
    public static let commentPattern = "<!--[\\s\\S]*?(?:-->|\\z)"

    public static func removingComments(_ text: String) -> String {
        text.replacingOccurrences(of: commentPattern, with: "", options: .regularExpression)
    }

    /// The `---` metadata block at the very top of a file, if there is one.
    public static func frontMatterRange(in text: String) -> NSRange {
        let ns = text as NSString
        guard ns.hasPrefix("---\n") else { return NSRange(location: 0, length: 0) }
        let close = ns.range(of: "\n---", options: [], range: NSRange(location: 3, length: ns.length - 3))
        guard close.location != NSNotFound else { return NSRange(location: 0, length: 0) }
        return NSRange(location: 0, length: NSMaxRange(close))
    }

    /// `| a | b |`
    public static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
    }

    /// The `|---|:--:|` line under a table's header.
    public static func isTableDivider(_ line: String) -> Bool {
        isTableRow(line) && line.contains("-") && line.allSatisfy { "|-: \t".contains($0) }
    }

    public static func isFence(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") { return "```" }
        if trimmed.hasPrefix("~~~") { return "~~~" }
        return nil
    }
}

public struct MarkdownRun: Equatable, Sendable {
    public var text: String
    public var bold = false
    public var italic = false
    public var code = false
    public var strike = false
    public var link: String?
    public init(text: String, bold: Bool = false, italic: Bool = false, code: Bool = false, strike: Bool = false, link: String? = nil) {
        self.text = text; self.bold = bold; self.italic = italic; self.code = code; self.strike = strike; self.link = link
    }
}

public enum MarkdownBlock: Equatable, Sendable {
    case heading(Int, [MarkdownRun])
    case paragraph([MarkdownRun])
    case quote([MarkdownRun])
    case bullet([MarkdownRun], depth: Int)
    case numbered(Int, [MarkdownRun], depth: Int)
    case task(done: Bool, [MarkdownRun], depth: Int)
    case sceneBreak
    case code(String)
    /// Rows of cells; `header` is true when the first row is followed by a divider line.
    case table([[String]], header: Bool)
    case image(alt: String, source: String)
}

/// A block and the stretch of the file it was read from (UTF-16 offsets into the whole text, front matter and notes
/// included), so a place on the Reading Mode page can be matched to a place in the editor.
public struct LocatedBlock: Equatable, Sendable {
    public let block: MarkdownBlock
    public let range: NSRange
}

public enum MarkdownBlocks {
    /// Turns Markdown into paragraphs, headings, quotes, lists, tasks, tables, scene breaks, and code, joining soft
    /// line breaks. Notes (`<!-- -->`) and a metadata block at the top are left out.
    public static func parse(_ markdown: String, skipFrontMatter: Bool = true) -> [MarkdownBlock] {
        located(markdown, skipFrontMatter: skipFrontMatter).map(\.block)
    }

    /// `parse`, with where in `markdown` each block came from.
    public static func located(_ markdown: String, skipFrontMatter: Bool = true) -> [LocatedBlock] {
        var source = markdown as NSString
        var frontLength = 0
        if skipFrontMatter {
            let front = MarkdownLines.frontMatterRange(in: markdown)
            if front.length > 0 { frontLength = front.length; source = source.substring(from: front.length) as NSString }
        }
        // Notes are cut out before the lines are read. `cuts` remembers where, so offsets can be put back.
        var cuts: [(at: Int, length: Int)] = []
        var cleaned = source as String
        if source.range(of: "<!--").location != NSNotFound, let pattern = try? NSRegularExpression(pattern: MarkdownLines.commentPattern) {
            let kept = NSMutableString()
            var cursor = 0
            for match in pattern.matches(in: source as String, range: NSRange(location: 0, length: source.length)) {
                kept.append(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
                cuts.append((kept.length, match.range.length))
                cursor = NSMaxRange(match.range)
            }
            kept.append(source.substring(from: cursor))
            cleaned = kept as String
        }
        var blocks: [MarkdownBlock] = []
        var spans: [(start: Int, end: Int)] = []
        var paragraph: [String] = [], paragraphSpan = (start: 0, end: 0)
        var quote: [String] = [], quoteSpan = (start: 0, end: 0)
        var table: [String] = [], tableSpan = (start: 0, end: 0)
        var fence: String?
        var fenceStart = 0
        var code: [String] = []
        func emit(_ block: MarkdownBlock, _ span: (start: Int, end: Int)) { blocks.append(block); spans.append(span) }
        func flushParagraph() {
            if !paragraph.isEmpty { emit(.paragraph(runs(paragraph.joined(separator: " "))), paragraphSpan); paragraph = [] }
        }
        func flushQuote() {
            if !quote.isEmpty { emit(.quote(runs(quote.joined(separator: " "))), quoteSpan); quote = [] }
        }
        func flushTable() {
            guard !table.isEmpty else { return }
            let header = table.count > 1 && MarkdownLines.isTableDivider(table[1])
            let rows = table.filter { !MarkdownLines.isTableDivider($0) }.map { row -> [String] in
                var cells = row.trimmingCharacters(in: .whitespaces).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if cells.first == "" { cells.removeFirst() }
                if cells.last == "" { cells.removeLast() }
                return cells
            }
            emit(.table(rows, header: header), tableSpan)
            table = []
        }
        func flushAll() { flushParagraph(); flushQuote(); flushTable() }
        var offset = 0
        for raw in cleaned.components(separatedBy: "\n") {
            let here = (start: offset, end: offset + raw.utf16.count)
            offset = here.end + 1
            let line = raw.replacingOccurrences(of: "\r", with: "")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let marker = fence {
                if trimmed.hasPrefix(marker) { emit(.code(code.joined(separator: "\n")), (fenceStart, here.end)); code = []; fence = nil } else { code.append(line) }
                continue
            }
            if let opening = MarkdownLines.isFence(trimmed) { flushAll(); fence = opening; fenceStart = here.start; continue }
            if trimmed.isEmpty { flushAll(); continue }
            if MarkdownLines.isSceneBreak(trimmed) { flushAll(); emit(.sceneBreak, here); continue }
            if MarkdownLines.isTableRow(trimmed) {
                flushParagraph(); flushQuote()
                if table.isEmpty { tableSpan.start = here.start }
                tableSpan.end = here.end
                table.append(trimmed)
                continue
            }
            flushTable()
            if let match = trimmed.range(of: "^#{1,6}\\s+", options: .regularExpression) {
                flushParagraph(); flushQuote()
                let level = trimmed[match].filter { $0 == "#" }.count
                let title = String(trimmed[match.upperBound...]).replacingOccurrences(of: "\\s+#+\\s*$", with: "", options: .regularExpression)
                emit(.heading(level, runs(title)), here)
                continue
            }
            if let image = imageLine(trimmed) { flushAll(); emit(.image(alt: image.alt, source: image.source), here); continue }
            if let prefix = MarkdownEditing.prefix(of: line) {
                let content = (line as NSString).substring(from: prefix.length)
                if case .quote = prefix.marker {
                    flushParagraph()
                    if quote.isEmpty { quoteSpan.start = here.start }
                    quoteSpan.end = here.end
                    quote.append(content)
                    continue
                }
                flushParagraph(); flushQuote()
                let depth = min(4, prefix.indentWidth / 2)
                switch prefix.marker {
                case .quote: break
                case .bullet:
                    if let task = prefix.task { emit(.task(done: task.lowercased() == "[x]", runs(content), depth: depth), here) }
                    else { emit(.bullet(runs(content), depth: depth), here) }
                case let .number(number, _): emit(.numbered(number, runs(content), depth: depth), here)
                }
                continue
            }
            flushQuote()
            if paragraph.isEmpty { paragraphSpan.start = here.start }
            paragraphSpan.end = here.end
            paragraph.append(trimmed)
        }
        if fence != nil, !code.isEmpty { emit(.code(code.joined(separator: "\n")), (fenceStart, max(fenceStart, offset - 1))) }
        flushAll()
        // Back to offsets in the whole file: past the front matter, and past every note cut out before that point. A
        // block that begins right after a note begins after it; one that ends right before a note ends before it.
        var result: [LocatedBlock] = []
        result.reserveCapacity(blocks.count)
        var cut = 0, removed = 0
        func restored(_ position: Int, startOfBlock: Bool) -> Int {
            while cut < cuts.count, cuts[cut].at < position || (startOfBlock && cuts[cut].at == position) { removed += cuts[cut].length; cut += 1 }
            return frontLength + position + removed
        }
        for (block, span) in zip(blocks, spans) {
            let start = restored(span.start, startOfBlock: true)
            let end = restored(span.end, startOfBlock: false)
            result.append(LocatedBlock(block: block, range: NSRange(location: start, length: max(0, end - start))))
        }
        return result
    }

    /// `![alt](source)` alone on a line.
    static func imageLine(_ line: String) -> (alt: String, source: String)? {
        guard line.hasPrefix("!["), line.hasSuffix(")"),
              let match = try? NSRegularExpression(pattern: "^!\\[([^\\]]*)\\]\\(([^)]*)\\)$").firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else { return nil }
        let ns = line as NSString
        return (ns.substring(with: match.range(at: 1)), ns.substring(with: match.range(at: 2)))
    }

    /// Bold, italic, code, strikethrough, and link runs. Images inside a paragraph are dropped, keeping the page to words.
    public static func runs(_ inline: String) -> [MarkdownRun] {
        let withoutImages = inline.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]*\\)", with: "", options: .regularExpression)
        guard let parsed = try? AttributedString(markdown: withoutImages, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return [MarkdownRun(text: withoutImages)]
        }
        var result: [MarkdownRun] = []
        for run in parsed.runs {
            let intent = run.inlinePresentationIntent ?? []
            let piece = MarkdownRun(text: String(parsed[run.range].characters), bold: intent.contains(.stronglyEmphasized),
                                    italic: intent.contains(.emphasized), code: intent.contains(.code), strike: intent.contains(.strikethrough),
                                    link: run.link?.absoluteString)
            if let last = result.last, last.bold == piece.bold, last.italic == piece.italic, last.code == piece.code, last.strike == piece.strike, last.link == piece.link {
                result[result.count - 1].text += piece.text
            } else { result.append(piece) }
        }
        return result
    }

    public static func plain(_ runs: [MarkdownRun]) -> String { runs.map(\.text).joined() }
}
