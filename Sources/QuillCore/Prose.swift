import Foundation

public enum Prose {
    public static let defaultWords = "very, really, just, quite, actually, basically, literally, somewhat, rather"

    // Keep code, link destinations, and YAML metadata out of prose review. The first three can span lines.
    private static let blockPatterns = [#"(?ms)\A---\r?\n.*?^---[ \t]*$"#, "(?ms)^```[^\\n]*\\n.*?^```[^\\n]*$", "(?ms)^~~~[^\\n]*\\n.*?^~~~[^\\n]*$"]
        .map { try! NSRegularExpression(pattern: $0) }
    private static let linePatterns = ["`[^`\\n]*`", "\\]\\([^\\n)]*\\)", "https?://[^\\s>]+"].map { try! NSRegularExpression(pattern: $0) }
    private static let bounds: NSRegularExpression.MatchingOptions = [.withTransparentBounds, .withoutAnchoringBounds]

    // UTF-16 ranges match Apple's text system, including text containing emoji.
    public static func suggestions(in text: String, words: String) -> [NSRange] {
        suggestions(in: text, words: words, range: NSRange(location: 0, length: (text as NSString).length), blocks: protectedBlocks(in: text))
    }

    /// Front matter and fenced code, the protected parts of the text that can cross a line break.
    public static func protectedBlocks(in text: String) -> [NSRange] {
        let whole = NSRange(location: 0, length: (text as NSString).length)
        return blockPatterns.flatMap { $0.matches(in: text, range: whole).map(\.range) }
    }

    /// The end of the front matter as prose review sees it, or 0.
    public static func frontMatterEnd(in text: String) -> Int {
        guard text.hasPrefix("---") else { return 0 }
        return blockPatterns[0].firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map { NSMaxRange($0.range) } ?? 0
    }

    /// The suggestions a whole-text search finds inside `range`, which must be whole lines (see `TextLines`); `blocks`
    /// are the text's `protectedBlocks(in:)`.
    public static func suggestions(in text: String, words: String, range: NSRange, blocks: [NSRange]) -> [NSRange] {
        let candidates = words.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !candidates.isEmpty else { return [] }
        let protected = blocks.filter { NSIntersectionRange($0, range).length > 0 }
            + linePatterns.flatMap { $0.matches(in: text, options: bounds, range: range).map(\.range) }
        let pattern = "(?i)(?<![\\p{L}\\p{N}_])(?:" + candidates.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")(?![\\p{L}\\p{N}_])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, options: bounds, range: range).map(\.range).filter { range in
            !protected.contains { NSIntersectionRange($0, range).length > 0 }
        }
    }

    /// True when every suggestion stays on one line, which region-by-region review relies on.
    public static func wordsStayOnOneLine(_ words: String) -> Bool { !words.contains("\n") && !words.contains("\r") }

    private static let note = try! NSRegularExpression(pattern: "<!--[\\s\\S]*?(?:-->|\\z)")

    /// Words as every count in Sable sees them: runs of text between white space that hold a letter or a digit, so stray
    /// Markdown punctuation ("---", "#") isn't one. Front matter and `<!-- -->` notes aren't counted.
    public static func wordCount(_ text: String) -> Int {
        // Most text has neither, and then one pass over it is all there is to do.
        guard text.hasPrefix("---") || text.contains("<!--") else { return plainWordCount(text.unicodeScalars) }
        let source = text as NSString
        return wordCount(in: source, range: NSRange(location: 0, length: source.length), skipping: uncountedRanges(in: text))
    }

    /// The front matter and the notes: what `wordCount` leaves out, in order. A note inside a code fence is still a note
    /// here, so that a note depends only on where its `<!--` and `-->` are.
    public static func uncountedRanges(in text: String) -> [NSRange] {
        let length = (text as NSString).length
        let start = frontMatterEnd(in: text)
        var result = start > 0 ? [NSRange(location: 0, length: start)] : []
        if text.contains("<!--") {
            result += note.matches(in: text, range: NSRange(location: start, length: length - start)).map(\.range)
        }
        return result
    }

    /// The words of `range` that a count of the whole text finds there. `range` must be whole lines (see `TextLines`), and
    /// `skipping` the text's `uncountedRanges(in:)`. A note separates the words on either side of it.
    public static func wordCount(in text: NSString, range: NSRange, skipping: [NSRange]) -> Int {
        var count = 0, position = range.location
        let end = NSMaxRange(range)
        for skip in skipping where NSMaxRange(skip) > position {
            guard skip.location < end else { break }
            if skip.location > position { count += plainWordCount(text.substring(with: NSRange(location: position, length: skip.location - position)).unicodeScalars) }
            position = NSMaxRange(skip)
        }
        if position < end { count += plainWordCount(text.substring(with: NSRange(location: position, length: end - position)).unicodeScalars) }
        return count
    }

    private static func plainWordCount(_ scalars: String.UnicodeScalarView) -> Int {
        var count = 0, counted = false
        for scalar in scalars {
            if scalar.value < 128 {
                // The common case, without a property lookup.
                switch scalar.value {
                case 32, 9...13: counted = false
                case 48...57, 65...90, 97...122: if !counted { count += 1; counted = true }
                default: break
                }
            } else if scalar.properties.isWhitespace {
                counted = false
            } else if !counted, scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                count += 1
                counted = true
            }
        }
        return count
    }
}
