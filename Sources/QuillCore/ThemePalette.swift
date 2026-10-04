import Foundation

/// A color as sRGB components from 0 to 1, with the contrast math WCAG 2 defines.
public struct RGB: Equatable, Sendable {
    public var red: Double, green: Double, blue: Double
    public init(_ red: Double, _ green: Double, _ blue: Double) { (self.red, self.green, self.blue) = (red, green, blue) }

    /// Six hex digits, with or without a leading #.
    public init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = UInt64(trimmed, radix: 16) else { return nil }
        self.init(Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    public static let white = RGB(1, 1, 1)
    public static let black = RGB(0, 0, 0)

    /// WCAG relative luminance.
    public var luminance: Double {
        func linear(_ value: Double) -> Double { value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// This color with `fraction` of `other` mixed in.
    public func mixed(with other: RGB, fraction: Double) -> RGB {
        RGB(red + (other.red - red) * fraction, green + (other.green - green) * fraction, blue + (other.blue - blue) * fraction)
    }

    /// What this color looks like drawn at `alpha` over `background`.
    public func over(_ background: RGB, alpha: Double) -> RGB { background.mixed(with: self, fraction: alpha) }
}

public enum Contrast {
    /// WCAG contrast ratio, from 1 (identical) to 21 (black on white).
    public static func ratio(_ first: RGB, _ second: RGB) -> Double {
        let (a, b) = (first.luminance, second.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// One writing theme: its paper, its ink, and the darker shade the page fades toward at its edges.
public struct ThemeSpec: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let paper: String
    public let ink: String
    public let dark: Bool
    /// A darker shade for the bottom status bar; nil keeps the window's own color.
    public var chrome: String? = nil
    /// Darker shade the page fades toward at its edges. Themes that set it feel "narrowed in" on the writing.
    public var edge: String? = nil
    /// A theme that drifts faint motes of light behind the text, for a quiet fantasy feel.
    public var particles: Bool = false
    public var paperColor: RGB { RGB(hex: paper)! }
    public var inkColor: RGB { RGB(hex: ink)! }
    public var edgeColor: RGB? { edge.flatMap { RGB(hex: $0) } }
}

/// Every color the editor draws text in, as numbers, so `scripts/check-contrast.swift` can measure what the app draws.
/// Change a color here and the check says whether it still reads against each theme's page.
public enum ThemePalette {
    public static let all = [
        ThemeSpec(id: "graphite", name: "Graphite", paper: "242424", ink: "E0DDD7", dark: true, chrome: "191919", edge: "121212"),
        ThemeSpec(id: "midnight", name: "Midnight", paper: "131820", ink: "D6DEE8", dark: true, chrome: "0C1015", edge: "05070A"),
        ThemeSpec(id: "chalk", name: "Chalk", paper: "2D3034", ink: "EEECE4", dark: true, chrome: "1A1C1F", edge: "121416"),
        ThemeSpec(id: "forest", name: "Forest", paper: "1D2925", ink: "DCE4D9", dark: true, edge: "0A100E"),
        ThemeSpec(id: "obsidian", name: "Obsidian", paper: "070707", ink: "D7D3CB", dark: true, chrome: "020202", edge: "000000"),
        ThemeSpec(id: "arcane", name: "Arcane", paper: "1B1330", ink: "E9DFFB", dark: true, chrome: "120B22", edge: "07040D", particles: true),
        ThemeSpec(id: "parchment", name: "Parchment", paper: "F3EBDD", ink: "40382E", dark: false),
        ThemeSpec(id: "paper", name: "Paper", paper: "FAFAF8", ink: "30302E", dark: false)
    ]
    public static func named(_ id: String) -> ThemeSpec { all.first { $0.id == id } ?? all[0] }

    // MARK: Edge shading

    /// The "Edge darkness" slider's default, and its range.
    public static let defaultEdgeStrength = 0.65
    public static let edgeStrengthRange = 0.3...1.6
    /// How opaque the edge color is at the very top and bottom, and at the very sides, for a strength. The Vignette overlay
    /// paints the two gradients one over the other, so a corner gets both.
    public static func edgeOpacity(strength: Double) -> (vertical: Double, horizontal: Double) {
        (min(1, 0.66 * strength), min(1, 0.55 * strength))
    }

    /// The colors the page can be under the text: its paper, and every blend toward the edge color the shading can reach.
    /// A theme without an edge color, and a page drawn flat, is only its paper.
    public static func pageColors(of theme: ThemeSpec, edgeStrength: Double, shaded: Bool = true) -> [RGB] {
        guard shaded, let edge = theme.edgeColor else { return [theme.paperColor] }
        let (vertical, horizontal) = edgeOpacity(strength: edgeStrength)
        var colors: [RGB] = []
        for v in 0...4 {
            for h in 0...4 {
                let top = edge.over(theme.paperColor, alpha: vertical * Double(v) / 4)
                colors.append(edge.over(top, alpha: horizontal * Double(h) / 4))
            }
        }
        return colors
    }

    // MARK: Dimmed text

    /// How much of the ink shows, from 0 to 1, for text the editor dims on purpose. The text is drawn in the ink color at
    /// this alpha, so over a shaded page it blends with the shade as well.
    public struct DimLevels: Equatable, Sendable {
        /// The symbols of Markdown (stars, hashes, brackets) while "Dim Markdown symbols" is on, and scene-break rules.
        public var marker: Double
        /// Quotes, notes to yourself, picture descriptions, and finished tasks: words, only quieter.
        public var muted: Double
        /// Paragraph focus: the lines beside the paragraph being written, which fade toward `focusFloor` with distance.
        public var focusNear: Double
        /// Paragraph focus when "Dim evenly" is chosen: everything outside the paragraph.
        public var focusEven: Double
        /// Paragraph focus: text far from the paragraph. It fades out on purpose, so it is the one level
        /// that is allowed to fall below 3:1 in the default look.
        public var focusFloor: Double
    }

    /// Dim levels by tone, chosen so every theme clears the thresholds in `scripts/check-contrast.swift`: markers 3:1,
    /// muted words and the nearest focus lines 4.5:1, "Dim evenly" 3:1. With Increase Contrast on: markers 4.5:1, muted
    /// words and nearest lines 7:1, "Dim evenly" 4.5:1, and even the far floor 3:1. Light pages need more ink to get there.
    public static func dimLevels(dark: Bool, increasedContrast: Bool) -> DimLevels {
        switch (dark, increasedContrast) {
        case (true, false): return DimLevels(marker: 0.46, muted: 0.62, focusNear: 0.62, focusEven: 0.46, focusFloor: 0.07)
        case (false, false): return DimLevels(marker: 0.62, muted: 0.76, focusNear: 0.76, focusEven: 0.62, focusFloor: 0.07)
        case (true, true): return DimLevels(marker: 0.62, muted: 0.80, focusNear: 0.80, focusEven: 0.62, focusFloor: 0.46)
        case (false, true): return DimLevels(marker: 0.76, muted: 0.93, focusNear: 0.93, focusEven: 0.76, focusFloor: 0.62)
        }
    }

    // MARK: Highlight colors

    /// Names of characters, places, and world notes (the card kinds' raw values).
    public static let nameKinds = ["character", "location", "lore"]
    /// Parts of speech for sentence colors.
    public static let wordKinds = ["noun", "verb", "adjective", "adverb", "pronoun"]

    /// The default color for a kind of name or part of speech on a dark or light page. Light pages need darker inks than
    /// the soft tints that suit dark ones; with Increase Contrast on they go darker still (and dark pages' tints are
    /// already past 7:1).
    public static func highlightColor(_ kind: String, dark: Bool, increasedContrast: Bool) -> RGB? {
        if dark { return darkHighlights[kind] }
        return (increasedContrast ? lightHighContrastHighlights : lightHighlights)[kind]
    }

    private static let darkHighlights: [String: RGB] = [
        "character": RGB(1.00, 0.83, 0.42), "location": RGB(0.45, 0.93, 0.96), "lore": RGB(0.82, 0.70, 1.00),
        "noun": RGB(0.62, 0.85, 0.86), "verb": RGB(0.93, 0.78, 0.55), "adjective": RGB(0.68, 0.78, 0.95),
        "adverb": RGB(0.93, 0.70, 0.83), "pronoun": RGB(0.72, 0.88, 0.73)
    ]
    private static let lightHighlights: [String: RGB] = [
        "character": RGB(0.58, 0.36, 0.02), "location": RGB(0.02, 0.45, 0.50), "lore": RGB(0.44, 0.26, 0.72),
        "noun": RGB(0.19, 0.45, 0.47), "verb": RGB(0.55, 0.37, 0.12), "adjective": RGB(0.24, 0.38, 0.62),
        "adverb": RGB(0.62, 0.30, 0.46), "pronoun": RGB(0.27, 0.45, 0.29)
    ]
    private static let lightHighContrastHighlights: [String: RGB] = [
        "character": RGB(0.42, 0.26, 0.01), "location": RGB(0.01, 0.33, 0.37), "lore": RGB(0.37, 0.22, 0.60),
        "noun": RGB(0.14, 0.33, 0.34), "verb": RGB(0.40, 0.27, 0.09), "adjective": RGB(0.19, 0.30, 0.49),
        "adverb": RGB(0.46, 0.22, 0.34), "pronoun": RGB(0.20, 0.33, 0.21)
    ]
}
