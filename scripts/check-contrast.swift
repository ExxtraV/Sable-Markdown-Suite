import Foundation

/// Measures WCAG 2 contrast for every color the editor draws text in, against each theme's page, in the default look and
/// with Increase Contrast on. The page is the paper and, in the default look, every blend toward the edge color that
/// "Darken toward the edges" can reach, at the default Edge darkness and at the slider's strongest setting. With
/// Increase Contrast or Reduce Transparency on, the app draws a flat page, so only the paper counts there.
///
/// The colors come from `Sources/QuillCore/ThemePalette.swift`, the numbers the app draws with, so a theme or a dim level
/// that stops reading fails here. Compile: swiftc Sources/QuillCore/ThemePalette.swift scripts/check-contrast.swift
///
/// What is held to what:
///   Body text                        4.5:1 (7:1 with Increase Contrast)
///   Dimmed Markdown symbols          3:1   (4.5:1)  quiet on purpose, but they have to stay findable
///   Muted words (quotes, notes)      4.5:1 (7:1)    they are words you wrote, only quieter
///   Focus: lines beside the paragraph 4.5:1 (7:1)   the brightest step of the fade
///   Focus: "Dim evenly"              3:1   (4.5:1)
///   Focus: far text                  none  (3:1)    fades out on purpose; Increase Contrast keeps it readable
///   Name and sentence colors         4.5:1 (7:1)    the app's defaults; a color you pick yourself is yours to judge
/// Not measured: the system's link color, text selection, and spelling underlines, which macOS draws, and the name
/// shimmer, which only moves a name's color toward white (dark pages) or black (light pages), away from the page.
@main enum ContrastChecks {
    struct Limits {
        var text: Double, symbols: Double, muted: Double, focusNear: Double, focusEven: Double, focusFar: Double?, highlights: Double
    }
    static let defaultLimits = Limits(text: 4.5, symbols: 3, muted: 4.5, focusNear: 4.5, focusEven: 3, focusFar: nil, highlights: 4.5)
    static let increasedLimits = Limits(text: 7, symbols: 4.5, muted: 7, focusNear: 7, focusEven: 4.5, focusFar: 3, highlights: 7)

    /// The lowest contrast of `ink`, drawn at `alpha`, over any of the page colors.
    static func lowest(_ ink: RGB, alpha: Double = 1, over pages: [RGB]) -> Double {
        pages.map { Contrast.ratio(ink.over($0, alpha: alpha), $0) }.min() ?? 1
    }

    static func main() {
        precondition(abs(Contrast.ratio(.black, .white) - 21) < 1e-9, "Black on white is 21:1")
        precondition(abs(Contrast.ratio(RGB(hex: "777777")!, .white) - 4.48) < 0.01, "#777 on white is about 4.48:1")
        precondition(Contrast.ratio(RGB(hex: "FF0000")!, .white) == Contrast.ratio(.white, RGB(hex: "FF0000")!), "Contrast doesn't depend on which color is the text")
        precondition(ThemePalette.pageColors(of: ThemePalette.named("paper"), edgeStrength: 1).count == 1, "A light theme has no shading")
        precondition(ThemePalette.pageColors(of: ThemePalette.named("graphite"), edgeStrength: 1).count > 1, "A dark theme shades toward its edges")
        precondition(ThemePalette.all.filter(\.dark).allSatisfy { $0.edgeColor != nil } && ThemePalette.all.filter { !$0.dark }.allSatisfy { $0.edgeColor == nil }, "Dark themes have an edge shade, light ones don't")

        var failures: [String] = []
        for increased in [false, true] {
            let limits = increased ? increasedLimits : defaultLimits
            print(increased ? "\nWith Increase Contrast (flat page, higher limits)" : "Default look (edge shading at its default and its strongest)")
            print("  " + pad("Theme", 11) + ["Text", "Symbols", "Muted", "Focus near", "Focus even", "Focus far", "Names", "Sentences"].map { pad($0, 11) }.joined())
            for theme in ThemePalette.all {
                let pages = increased ? [theme.paperColor]
                    : ThemePalette.pageColors(of: theme, edgeStrength: ThemePalette.defaultEdgeStrength)
                        + ThemePalette.pageColors(of: theme, edgeStrength: ThemePalette.edgeStrengthRange.upperBound)
                let dim = ThemePalette.dimLevels(dark: theme.dark, increasedContrast: increased)
                let ink = theme.inkColor
                func highlights(_ kinds: [String]) -> (Double, String) {
                    kinds.compactMap { kind in
                        ThemePalette.highlightColor(kind, dark: theme.dark, increasedContrast: increased).map { (lowest($0, over: pages), kind) }
                    }.min { $0.0 < $1.0 } ?? (0, "missing")
                }
                let names = highlights(ThemePalette.nameKinds), words = highlights(ThemePalette.wordKinds)
                let measured: [(label: String, value: Double, minimum: Double?)] = [
                    ("body text", lowest(ink, over: pages), limits.text),
                    ("dimmed Markdown symbols", lowest(ink, alpha: dim.marker, over: pages), limits.symbols),
                    ("muted words", lowest(ink, alpha: dim.muted, over: pages), limits.muted),
                    ("focus, lines beside the paragraph", lowest(ink, alpha: dim.focusNear, over: pages), limits.focusNear),
                    ("focus, Dim evenly", lowest(ink, alpha: dim.focusEven, over: pages), limits.focusEven),
                    ("focus, far text", lowest(ink, alpha: dim.focusFloor, over: pages), limits.focusFar),
                    ("name colors (\(names.1))", names.0, limits.highlights),
                    ("sentence colors (\(words.1))", words.0, limits.highlights)
                ]
                print("  " + pad(theme.name, 11) + measured.map { entry in
                    let failed = entry.minimum.map { entry.value + 1e-9 < $0 } ?? false
                    return pad(String(format: "%.1f", entry.value) + (failed ? " ✗" : (entry.minimum == nil ? " ·" : "")), 11)
                }.joined())
                for entry in measured {
                    guard let minimum = entry.minimum, entry.value + 1e-9 < minimum else { continue }
                    failures.append("\(theme.name)\(increased ? " (Increase Contrast)" : ""): \(entry.label) is \(String(format: "%.2f", entry.value)):1, needs \(minimum):1")
                }
                let kinds = [ThemePalette.nameKinds, ThemePalette.wordKinds].joined()
                if kinds.contains(where: { ThemePalette.highlightColor($0, dark: theme.dark, increasedContrast: increased) == nil }) {
                    failures.append("\(theme.name): a name or sentence color has no default")
                }
                // The dimming has to keep its order, or the fade stops reading as a fade.
                let ordered = dim.marker <= dim.muted && dim.focusFloor <= dim.focusEven && dim.focusEven <= dim.focusNear && dim.focusNear <= 1
                if !ordered { failures.append("\(theme.name): dim levels are out of order") }
            }
        }
        print("\n  · = no minimum (the far end of the focus fade is meant to disappear; Increase Contrast keeps it at 3:1)")

        guard failures.isEmpty else {
            print("\nFailed contrast checks:")
            for failure in failures { print("  - " + failure) }
            exit(1)
        }
        print("\nPassed: every theme's text, dimmed symbols, muted words, focus dimming, and highlight colors clear their limits.")
    }

    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }
}
