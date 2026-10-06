import Foundation

/// Matches places in a Markdown file with places on the Reading Mode page, so switching between writing and reading
/// can land on the same paragraph. The page leaves out front matter, notes, and the Markdown marks, so the two count
/// characters differently; this keeps, block by block, where each one sits in both.
///
/// All offsets are UTF-16, as the text views count them.
public struct ReadingMap: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        /// The block in the file.
        public let source: NSRange
        /// The same block on the page, its closing line break included.
        public let page: NSRange
        public init(source: NSRange, page: NSRange) { self.source = source; self.page = page }
    }

    /// In reading order; neither side ever runs backwards.
    public private(set) var entries: [Entry] = []

    public init() {}

    public mutating func add(source: NSRange, page: NSRange) {
        guard page.length > 0 else { return }
        entries.append(Entry(source: source, page: page))
    }

    /// Where on the page a place in the file is. A place the page leaves out (front matter, a note, a blank line)
    /// lands on the start of the next block that is shown, or on the end of the page after the last one.
    public func pageOffset(forSource offset: Int) -> Int {
        guard let index = lastEntry(where: { $0.source.location <= offset }) else { return entries.first?.page.location ?? 0 }
        let entry = entries[index]
        if offset >= NSMaxRange(entry.source) {
            return index + 1 < entries.count ? entries[index + 1].page.location : NSMaxRange(entry.page)
        }
        return entry.page.location + Self.scaled(offset - entry.source.location, from: entry.source.length, to: entry.page.length)
    }

    /// Where in the file a place on the page is: the same block, about as far through it.
    public func sourceOffset(forPage offset: Int) -> Int {
        guard let index = lastEntry(where: { $0.page.location <= offset }) else { return entries.first?.source.location ?? 0 }
        let entry = entries[index]
        if offset >= NSMaxRange(entry.page) { return NSMaxRange(entry.source) }
        return entry.source.location + Self.scaled(offset - entry.page.location, from: entry.page.length, to: entry.source.length)
    }

    /// The marks a block loses on the page are few beside its words, so a place partway through a block is found by
    /// proportion. The start of a block is always exact, and a place inside a block never leaves it.
    private static func scaled(_ distance: Int, from: Int, to: Int) -> Int {
        guard distance > 0, from > 0, to > 0 else { return 0 }
        return min(to - 1, Int((Double(distance) / Double(from) * Double(to)).rounded()))
    }

    private func lastEntry(where matches: (Entry) -> Bool) -> Int? {
        var low = 0, high = entries.count
        while low < high {
            let middle = (low + high) / 2
            if matches(entries[middle]) { low = middle + 1 } else { high = middle }
        }
        return low > 0 ? low - 1 : nil
    }
}
