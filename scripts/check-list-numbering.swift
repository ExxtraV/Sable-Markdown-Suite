import Foundation

@main enum ListNumberingChecks {
    /// `|` marks the caret. The edit is taken to have touched the caret's line, or the whole text when `whole` is true.
    static func count(_ marked: String, whole: Bool = false) -> String? {
        let ns = marked as NSString
        let caret = ns.range(of: "|")
        let text = ns.replacingCharacters(in: caret, with: "")
        let range = whole ? NSRange(location: 0, length: (text as NSString).length) : NSRange(location: caret.location, length: 0)
        guard let edit = MarkdownEditing.renumber(in: text, around: range, selection: NSRange(location: caret.location, length: 0)) else { return nil }
        let result = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        return (result as NSString).replacingCharacters(in: NSRange(location: edit.selection.location, length: 0), with: "|")
    }

    /// Runs a Return or Tab edit the way the editor does: the edit, then the list counted again around what it changed.
    static func edit(_ marked: String, _ operation: (String, NSRange) -> TextEdit?) -> String? {
        let ns = marked as NSString
        let caret = ns.range(of: "|")
        let text = ns.replacingCharacters(in: caret, with: "")
        guard let first = operation(text, NSRange(location: caret.location, length: 0)) else { return nil }
        var result = (text as NSString).replacingCharacters(in: first.range, with: first.replacement)
        var selection = first.selection
        let touched = NSRange(location: first.range.location, length: (first.replacement as NSString).length)
        if let second = MarkdownEditing.renumber(in: result, around: touched, selection: selection) {
            result = (result as NSString).replacingCharacters(in: second.range, with: second.replacement)
            selection = second.selection
        }
        return (result as NSString).replacingCharacters(in: NSRange(location: selection.location, length: 0), with: "|")
    }

    static func main() {
        // Adding and removing items
        precondition(count("1. a\n2. |\n2. b") == "1. a\n2. |\n3. b", "A new item pushes the rest down: \(count("1. a\n2. |\n2. b") ?? "nil")")
        precondition(count("1. a\n|3. c\n4. d") == "1. a\n|2. c\n3. d", "A removed item pulls the rest up: \(count("1. a\n|3. c\n4. d") ?? "nil")")
        precondition(count("1. a\n2. b|\n4. d") == "1. a\n2. b|\n3. d", "The item after a removed last line is counted too")
        precondition(count("1. a\n2. b|") == nil, "A list already in order is left alone")
        precondition(count("plain words|") == nil && count("- a\n- b|") == nil, "Prose and bullets have nothing to count")
        precondition(count("5. a\n5. |\n6. b") == "5. a\n6. |\n7. b", "The first item keeps its number: \(count("5. a\n5. |\n6. b") ?? "nil")")
        precondition(count("1) a\n1) |") == "1) a\n2) |", "Parentheses count too")
        precondition(count("1. [x] a\n1. [ ] |") == "1. [x] a\n2. [ ] |", "Numbered tasks count")
        precondition(count("1. a\n\n1. |") == "1. a\n\n2. |", "Blank lines between items keep one list")
        precondition(count("1. a\n1. b\n1. c|", whole: true) == "1. a\n2. b\n3. c|", "Pasted items are counted")

        // The caret stays with its words when a number gets wider
        precondition(count("8. a\n9. b\n9. c|") == "8. a\n9. b\n10. c|", "Caret after a wider number: \(count("8. a\n9. b\n9. c|") ?? "nil")")
        precondition(count("8. a\n9. b\n|9. c") == "8. a\n9. b\n|10. c", "Caret before the number stays put")

        // Where one list ends
        precondition(count("1. a\n2. |\n2. b\n\nProse.\n\n7. x\n9. y") == "1. a\n2. |\n3. b\n\nProse.\n\n7. x\n9. y", "Another list further down is not touched")
        precondition(count("1. a\nProse\n1. |") == nil, "Prose between two lists keeps them apart")
        precondition(count("1. a\n   more words\n1. |") == "1. a\n   more words\n2. |", "An indented paragraph stays inside the item")
        precondition(count("1. a\n1) |") == nil, "A different delimiter starts a new list")
        precondition(count("1. a\n- b\n1. |") == nil, "A bullet at the same level starts a new list")

        // Nested lists
        precondition(count("1. a\n   1. x\n   1. |\n2. b") == "1. a\n   1. x\n   2. |\n2. b", "A nested list counts on its own")
        precondition(count("1. a\n   1. x\n3. |") == "1. a\n   1. x\n2. |", "The outer list skips the nested items")
        precondition(count("1. a\n  - x\n  - y\n3. |") == "1. a\n  - x\n  - y\n2. |", "Nested bullets don't break the count")

        // Places a number isn't a list item
        precondition(count("```\n1. a\n1. |\n```") == nil, "Not inside a code block")
        precondition(count("```\ncode\n```\n1. a\n1. |") == "```\ncode\n```\n1. a\n2. |", "Fine after a code block")
        precondition(count("---\n1. a\n1. |\n---\nText") == nil, "Not inside front matter")
        precondition(count("999. a\n999. |") == nil, "Past 999 a number is no longer a list marker, so it is left alone")

        // With Return and Tab, the way the editor runs them
        func enter(_ marked: String) -> String? { edit(marked) { MarkdownEditing.newline(in: $0, selection: $1) } }
        func tab(_ marked: String, out: Bool = false) -> String? { edit(marked) { MarkdownEditing.indent(in: $0, selection: $1, outdent: out) } }
        precondition(enter("1. a|\n2. b\n3. c") == "1. a\n2. |\n3. b\n4. c", "Return in the middle of a list: \(enter("1. a|\n2. b\n3. c") ?? "nil")")
        precondition(enter("1. a\n2. b\n3. |\n4. d") == "1. a\n2. b\n|\n3. d", "Return on an empty item leaves a gap the list counts across: \(enter("1. a\n2. b\n3. |\n4. d") ?? "nil")")
        precondition(tab("1. a\n2. b|\n3. c") == "1. a\n   1. b|\n2. c", "Tab starts a nested list at 1: \(tab("1. a\n2. b|\n3. c") ?? "nil")")
        precondition(tab("1. a\n   1. x\n2. b|") == "1. a\n   1. x\n   2. b|", "Tab joins the nested list above: \(tab("1. a\n   1. x\n2. b|") ?? "nil")")
        precondition(tab("1. a\n   1. x|\n2. b", out: true) == "1. a\n2. x|\n3. b", "Shift-Tab brings it back into the count: \(tab("1. a\n   1. x|\n2. b", out: true) ?? "nil")")
        print("Passed: numbered lists count themselves again after adding, removing, pasting, and moving items.")
    }
}
