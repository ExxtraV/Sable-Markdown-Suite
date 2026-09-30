import Foundation

// How an export is laid out on the page. The Manuscript and Book looks are starting points: picking one fills in
// the choices below, and the writer can then adjust any of them. PDF and Word honor every choice; EPUB takes the
// heading and title page alignment, since an e-reader sets its own type, spacing, and pages.

enum ExportStyle: String, CaseIterable, Sendable {
    case manuscript, book
    var title: String { self == .manuscript ? "Manuscript" : "Book" }
    var detail: String {
        self == .manuscript
            ? "The usual shape for submissions: Times, double-spaced, with a running header."
            : "Reads like a printed book: justified text, page numbers at the foot."
    }
}

enum PageSize: String, CaseIterable, Sendable {
    case letter, a4
    var title: String { self == .letter ? "US Letter" : "A4" }
    var points: CGSize { self == .letter ? CGSize(width: 612, height: 792) : CGSize(width: 595.28, height: 841.89) }
    /// A4 in metric countries, Letter elsewhere.
    static var regional: PageSize { Locale.current.measurementSystem == .metric ? .a4 : .letter }
}

enum ExportAlignment: String, CaseIterable, Sendable {
    case left, center
    var title: String { self == .left ? "Left" : "Centered" }
}

/// Typefaces that read the same in a PDF made on this Mac and in Word on a Mac or a PC.
enum ExportFont: String, CaseIterable, Sendable {
    case times, georgia, palatino, arial, courier
    var title: String {
        switch self {
        case .times: return "Times New Roman"
        case .georgia: return "Georgia"
        case .palatino: return "Palatino"
        case .arial: return "Arial"
        case .courier: return "Courier New"
        }
    }
    /// The name CoreText knows on macOS.
    var pdfName: String { title }
    /// The name Word knows. Palatino goes by its Windows name, which Word on a Mac also recognizes.
    var wordName: String { self == .palatino ? "Palatino Linotype" : title }
}

enum LineSpacing: String, CaseIterable, Sendable {
    case single, oneAndHalf, double
    var title: String {
        switch self { case .single: return "Single"; case .oneAndHalf: return "1.5"; case .double: return "Double" }
    }
    /// A multiple of the font's natural line height, which is also how Word measures "auto" spacing.
    var multiple: CGFloat {
        switch self { case .single: return 1; case .oneAndHalf: return 1.5; case .double: return 2 }
    }
}

struct ExportLayout: Equatable, Sendable {
    var style = ExportStyle.manuscript
    var pageSize = PageSize.regional
    var titlePage = true
    var titleAlignment = ExportAlignment.center
    var headingAlignment = ExportAlignment.center
    var font = ExportFont.times
    var fontSize = 12
    var lineSpacing = LineSpacing.double
    /// Inches on every side.
    var margins = 1.0
    var pageNumbers = true
    var runningHeader = true
    var chapterPageBreaks = true

    static let fontSizes = [10, 11, 12, 13, 14]
    static let marginChoices = [0.75, 1.0, 1.25, 1.5]

    init(style: ExportStyle = .manuscript) { start(from: style) }

    /// Picking a look fills in its type, spacing, margins, alignment, and page furniture. The page size,
    /// the title page, and chapter page breaks are left as they were.
    mutating func start(from look: ExportStyle) {
        style = look
        titleAlignment = .center
        headingAlignment = .center
        margins = 1.0
        pageNumbers = true
        switch look {
        case .manuscript:
            font = .times; fontSize = 12; lineSpacing = .double; runningHeader = true
        case .book:
            font = .palatino; fontSize = 11; lineSpacing = .single; runningHeader = false
        }
    }

    /// Whether any choice differs from the look it started from.
    var isAdjusted: Bool {
        var look = self
        look.start(from: style)
        return look != self
    }

    // MARK: Saving

    /// The layout as plain strings, for a project's settings file or the app's preferences.
    var saved: [String: String] {
        [
            "style": style.rawValue, "pageSize": pageSize.rawValue, "titlePage": String(titlePage),
            "titleAlignment": titleAlignment.rawValue, "headingAlignment": headingAlignment.rawValue,
            "font": font.rawValue, "fontSize": String(fontSize), "lineSpacing": lineSpacing.rawValue,
            "margins": String(margins), "pageNumbers": String(pageNumbers), "runningHeader": String(runningHeader),
            "chapterPageBreaks": String(chapterPageBreaks),
        ]
    }

    /// Reads a saved layout. Anything missing, misspelled, or out of range keeps its value from `fallback`,
    /// so a hand-edited settings file never breaks an export.
    init(saved: [String: String]?, fallback: ExportLayout) {
        self = fallback
        guard let saved else { return }
        func flag(_ key: String) -> Bool? { saved[key].flatMap { Bool($0) } }
        if let value = saved["style"].flatMap(ExportStyle.init(rawValue:)) { style = value }
        if let value = saved["pageSize"].flatMap(PageSize.init(rawValue:)) { pageSize = value }
        if let value = flag("titlePage") { titlePage = value }
        if let value = saved["titleAlignment"].flatMap(ExportAlignment.init(rawValue:)) { titleAlignment = value }
        if let value = saved["headingAlignment"].flatMap(ExportAlignment.init(rawValue:)) { headingAlignment = value }
        if let value = saved["font"].flatMap(ExportFont.init(rawValue:)) { font = value }
        if let value = saved["fontSize"].flatMap({ Int($0) }), ExportLayout.fontSizes.contains(value) { fontSize = value }
        if let value = saved["lineSpacing"].flatMap(LineSpacing.init(rawValue:)) { lineSpacing = value }
        if let value = saved["margins"].flatMap({ Double($0) }), ExportLayout.marginChoices.contains(value) { margins = value }
        if let value = flag("pageNumbers") { pageNumbers = value }
        if let value = flag("runningHeader") { runningHeader = value }
        if let value = flag("chapterPageBreaks") { chapterPageBreaks = value }
    }

    /// The same, as one line of JSON for a single preference.
    var json: String {
        (try? JSONEncoder().encode(saved)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
    init(json: String, fallback: ExportLayout) {
        self.init(saved: try? JSONDecoder().decode([String: String].self, from: Data(json.utf8)), fallback: fallback)
    }
}
