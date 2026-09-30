import Foundation

/// The file extensions Sable treats as Markdown or plain text, in one place so the writing desk, search,
/// import, and the Open panel all agree with the document types declared in Info.plist.
enum MarkdownFileTypes {
    /// Markdown, including the less common spellings some other editors use.
    static let markdownExtensions = ["md", "markdown", "mdown", "mkd", "mkdn", "mdwn"]
    static let plainTextExtensions = ["txt"]
    /// Everything the desk lists and a new file may end in.
    static let allExtensions = markdownExtensions + plainTextExtensions

    static func isMarkdown(_ url: URL) -> Bool { markdownExtensions.contains(url.pathExtension.lowercased()) }
    static func isMarkdownOrText(_ url: URL) -> Bool { allExtensions.contains(url.pathExtension.lowercased()) }

    /// What a drop on the page means: one Markdown or text file opens, like File → Open. Several files, a folder,
    /// or anything else isn't an "open this" drop, and the page treats it as it always did.
    static func openableDrop(_ urls: [URL]) -> URL? {
        guard urls.count == 1, let url = urls.first, url.isFileURL, isMarkdownOrText(url),
              (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { return nil }
        return url
    }
}
