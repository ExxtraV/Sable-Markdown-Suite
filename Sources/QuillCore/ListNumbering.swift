import Foundation

/// Numbered lists that count themselves again after an item is added, removed, moved in or out, or pasted. Only the list
/// an edit touches is renumbered, and its first item keeps its number, so a list that starts at 5 still starts at 5.
extension MarkdownEditing {
    /// Numbers above this stop being list markers (see `prefix(of:)`), so a list that reaches it is left as it is.
    private static let largestNumber = 999

    private struct Line {
        var start: Int
        var text: String
    }

    private struct OpenList {
        var indent: Int
        var delimiter: String?     // nil for a bullet list, which shares a level but never counts
        var next: Int
    }

    private struct NumberChange {
        var location: Int          // where the digits start
        var oldLength: Int
        var digits: String
    }

    /// After an edit that left new text in `range`, the numbers of the lists around it put back in order. Nil when
    /// nothing needs to change, so ordinary typing in a list costs a look at a line or two.
    public static func renumber(in text: String, around range: NSRange, selection: NSRange) -> TextEdit? {
        let ns = text as NSString
        guard ns.length > 0 else { return nil }
        let start = min(max(0, range.location), ns.length)
        let end = min(NSMaxRange(range), ns.length)

        // Is a numbered item on an edited line or just next to it? If not, there is no list to count.
        var seedStart = lineBounds(ns, start).start
        if seedStart > 0 { seedStart = lineBounds(ns, seedStart - 1).start }
        var seedEnd = lineBounds(ns, end).end
        if seedEnd < ns.length { seedEnd = lineBounds(ns, seedEnd).end }
        guard lines(ns, from: seedStart, to: seedEnd).contains(where: isNumbered) else { return nil }

        // Widen to the whole list: up and down until a line that no list could hold.
        var windowStart = seedStart
        while windowStart > 0 {
            let above = lineBounds(ns, windowStart - 1)
            guard belongsToList(ns.substring(with: NSRange(location: above.start, length: above.contentEnd - above.start))) else { break }
            windowStart = above.start
        }
        var windowEnd = seedEnd
        while windowEnd < ns.length {
            let below = lineBounds(ns, windowEnd)
            guard belongsToList(ns.substring(with: NSRange(location: below.start, length: below.contentEnd - below.start))) else { break }
            windowEnd = below.end
        }

        let changes = numberChanges(lines(ns, from: windowStart, to: windowEnd))
        guard let first = changes.first, let last = changes.last else { return nil }
        // Never count lines in the metadata block or a code block.
        if windowStart < NSMaxRange(MarkdownLines.frontMatterRange(in: text)) || insideFence(ns, before: windowStart) { return nil }

        let span = NSRange(location: first.location, length: last.location + last.oldLength - first.location)
        let replacement = NSMutableString(string: ns.substring(with: span))
        for change in changes.reversed() {
            replacement.replaceCharacters(in: NSRange(location: change.location - span.location, length: change.oldLength), with: change.digits)
        }
        func moved(_ location: Int) -> Int {
            var shift = 0
            for change in changes {
                let newLength = (change.digits as NSString).length
                if location >= change.location + change.oldLength { shift += newLength - change.oldLength }
                else if location > change.location { return min(location, change.location + newLength) + shift }
                else { break }
            }
            return location + shift
        }
        let selectionStart = moved(selection.location)
        let selectionEnd = moved(NSMaxRange(selection))
        return TextEdit(range: span, replacement: replacement as String,
                        selection: NSRange(location: selectionStart, length: max(0, selectionEnd - selectionStart)))
    }

    /// What each item's number should be, counting every list in `lines` from its first item.
    private static func numberChanges(_ lines: [Line]) -> [NumberChange] {
        var open: [OpenList] = []
        var changes: [NumberChange] = []
        var fence: String?
        for line in lines {
            let width = line.text.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            if let marker = fence {
                if line.text.trimmingCharacters(in: .whitespaces).hasPrefix(marker) { fence = nil }
                continue
            }
            if line.text.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            guard let p = prefix(of: line.text), p.isList else {
                // Prose, a quote, a heading, or a fence: it closes every list it isn't indented inside of.
                open.removeAll { $0.indent >= width }
                fence = MarkdownLines.isFence(line.text)
                continue
            }
            open.removeAll { $0.indent > p.indentWidth }
            var delimiter: String?
            var number = 0
            if case let .number(n, d) = p.marker { number = n; delimiter = d }
            if let top = open.last, top.indent == p.indentWidth, top.delimiter == delimiter {
                guard delimiter != nil else { continue }
                let expected = top.next
                if expected <= largestNumber, number != expected {
                    let digits = String(line.text.dropFirst(p.indent.count).prefix { $0.isNumber })
                    changes.append(NumberChange(location: line.start + (p.indent as NSString).length,
                                                oldLength: (digits as NSString).length, digits: String(expected)))
                }
                open[open.count - 1].next = expected + 1
            } else {
                // A new list, or a different kind of marker at the same level, which Markdown treats as a new list.
                if let top = open.last, top.indent == p.indentWidth { open.removeLast() }
                open.append(OpenList(indent: p.indentWidth, delimiter: delimiter, next: number + 1))
            }
        }
        return changes
    }

    private static func isNumbered(_ line: Line) -> Bool {
        guard let p = prefix(of: line.text), case .number = p.marker else { return false }
        return true
    }

    /// A list item, a blank line, or a line indented under an item.
    private static func belongsToList(_ line: String) -> Bool {
        if line.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if let p = prefix(of: line) { return p.isList }
        return line.first == " " || line.first == "\t"
    }

    private static func lines(_ ns: NSString, from start: Int, to end: Int) -> [Line] {
        var result: [Line] = []
        var location = start
        while location < end {
            let bounds = lineBounds(ns, location)
            result.append(Line(start: bounds.start, text: ns.substring(with: NSRange(location: bounds.start, length: bounds.contentEnd - bounds.start))))
            guard bounds.end > location else { break }
            location = bounds.end
        }
        return result
    }

    /// An odd number of fence lines before `location` means it is inside a code block.
    private static func insideFence(_ ns: NSString, before location: Int) -> Bool {
        var fence: String?
        for line in lines(ns, from: 0, to: location) {
            if let marker = fence {
                if line.text.trimmingCharacters(in: .whitespaces).hasPrefix(marker) { fence = nil }
            } else {
                fence = MarkdownLines.isFence(line.text)
            }
        }
        return fence != nil
    }
}
