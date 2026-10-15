import Foundation

@main
enum ProseChecks {
    static func main() {
        func matches(_ text: String, _ words: String) -> [String] {
            Prose.suggestions(in: text, words: words).map { (text as NSString).substring(with: $0) }
        }
        precondition(matches("🌙 Really, a very justifiable choice.", "really, very, just") == ["Really", "very"])
        precondition(matches("---\njust: very\n---\nReally `just` [very](https://very.test)\n```swift\njust\n```\nactually", "just, very, really, actually") == ["Really", "very", "actually"])
        precondition(matches("in order to write a+b", "in order to, a+b") == ["in order to", "a+b"])
        precondition(matches("very", " , ").isEmpty)

        // Word counts: one rule for the footer, the desk, the Manuscript tab, the writing record, goals, and exports.
        func words(_ text: String, _ expected: Int, _ what: String) {
            precondition(Prose.wordCount(text) == expected, "\(what): \(Prose.wordCount(text)), not \(expected)")
            // Counting line by line, the way the editor does after a keystroke, adds up to the same number.
            let source = text as NSString, skipping = Prose.uncountedRanges(in: text)
            var total = 0, start = 0
            while start < source.length {
                let line = source.lineRange(for: NSRange(location: start, length: 0))
                total += Prose.wordCount(in: source, range: line, skipping: skipping)
                start = NSMaxRange(line)
            }
            precondition(total == expected, "\(what), line by line: \(total), not \(expected)")
        }
        words("", 0, "Nothing")
        words("One two  three\n\nfour\tfive\u{2028}six\u{00A0}seven", 7, "Any white space separates words")
        words("# Title\n\nOne two — three ---\n\n* * *\n\n> “Four,” she said.", 7, "Punctuation alone is not a word")
        words("Chapter 12 has 3 émigrés and 東京.", 7, "Digits and letters of any script count")
        words("One <!-- a note --> two", 2, "A note on a line")
        words("One\n\n<!-- Scene: The Ferry · Status: To Do\nSynopsis: She crosses at night.\nNotes:\nCheck the tide tables.\n-->\n\nTwo three", 3, "A note over several lines")
        words("One<!-- x -->two", 2, "A note separates the words beside it")
        words("One two\n\n<!-- never closed\nthree four", 2, "An unclosed note runs to the end")
        words("One <!-- a --> two <!-- b\nc --> three --> four", 4, "Each note ends at its first -->")
        words("```\n<!-- code -->\nlet x\n```\nOne", 3, "A note in a code fence is still left out")
        words("---\ntype: note\nsynopsis: many many words here\n---\n# Title\n\nOne two three.", 4, "Front matter is not counted")
        words("---\ntitle: A\n---\n<!-- note -->\nOne", 1, "Front matter and a note together")
        words("---\nNot front matter, never closed", 5, "A lone --- line hides nothing")
        words("One\n\n---\ntitle: late\n---\n\nTwo", 4, "Only a block at the very top is front matter")
        print("Passed: Unicode ranges, whole words, Markdown exclusions, custom phrases, literal escaping, empty rules, word counts.")
    }
}
