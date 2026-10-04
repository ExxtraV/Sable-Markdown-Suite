<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Assets/sable-logo-reverse.png">
    <img src="Assets/sable-logo.png" alt="The Sable logo: a sable asleep, curled nose to tail, with a fountain-pen nib tucked into its body" width="200">
  </picture>
</p>

# Sable Markdown Writer

A small, native Markdown editor for fiction, for macOS 14 or later. Source is included so the editor can evolve with your writing habits.

## Use

Open `build/Sable Markdown Writer.app` after building. Use File → New or File → Open. Choose an existing UTF-8 `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, `.mdwn`, or `.txt` file from your Mac or iCloud Drive. File → Save writes plain Markdown; prose overlays are never serialized. File coordination and document saving use Apple's SwiftUI `DocumentGroup` and `FileDocument`.

### Open any Markdown file, with or without a writing folder

A writing folder is optional. You can use Sable as a calm Markdown editor for single files:

- **Open a file from anywhere.** Finder's Open With → Sable, File → Open Markdown File… (⌘O), File → Open Recent, dragging a file onto the Dock icon, or dragging it onto the window all work. The file's own folder need not be a writing folder, and the writing folder is never changed.
- **Make Sable the default app for Markdown, if you want.** Settings → General → Markdown files shows which app opens Markdown files now and has a **Make Sable the Default for Markdown** button; macOS asks you to confirm. Plain text (`.txt`) is a separate button, also off by default. Sable never changes either by itself and registers as an alternate handler only. To switch back, select a Markdown file in Finder, choose File → Get Info, pick another app under Open with, and click Change All.
- **No writing folder needed.** First launch offers **Just Open a File** and **Explore a Sample Project** beside choosing a folder, and a window opened on a file from Finder skips setup. With no writing folder, the writing desk shows the open file's own folder. Settings → General → Writing folder chooses one later, or stops using it; that only makes Sable forget the folder, and no file is touched.
- **A file outside the writing folder.** The desk keeps showing the writing folder and adds one quiet line: the file is in another folder, with **Show Folder**. That shows the file's folder for this session only, with a **Back to** link; the saved writing folder never changes.
- **An optional Recent tab.** Settings → General → Writing desk turns on a **Recent** tab in the desk with the files you have open, newest first. It is off by default, recorded only while on, and turning it off forgets the list.
- **The same protections everywhere.** Safe saving, the moved-to-Trash or deleted notice with **Put Back**, and snapshots work from the open file itself, wherever it lives. A snapshot of a file outside a writing folder is kept in a hidden `.sable-revisions` folder beside it, and only when you save one.

The writing surface now displays bold, italic, combined emphasis, headings, links, quotes, lists, inline code, fenced code, and strikethrough. Markdown markers remain visible in a subdued color. Fonts and visual attributes never become part of the saved text. Supported web/mail links have native link attributes.

Text is centered in a 680-point column by default, including in a maximized window. Settings lets you change the width and text size. A two-finger horizontal swipe or the sidebar button (⌃⌘S) toggles the writing desk. Its outline options let you choose Chapters, Episodes, Scenes, Outline, or any custom label and filter to one heading level. Labels and filters are shared across documents and do not rename your actual headings.

The Files section's menu → Choose Writing Folder opens a persistent folder browser for Markdown and text files. Click folders to expand or collapse nested contents inline. Use the up arrow to return, and click a file to switch the active document. Sable asks macOS to save, discard, or cancel when the active document has unsaved edits, then opens the selected file in the same writing window. Automatic window tabs are disabled. The menu also refreshes the listing or returns to the root folder. Search filters loaded, visible file rows and outline headings. Folder listings refresh manually; recursive full-text search is not implemented. Hidden files, symlinks, and packages are excluded.

Any Markdown file in the writing folder can be opened beside the active document from its context menu. The split pane begins in a clean formatted reading view. Edit enables in-place Markdown editing beside the draft; Read returns to the formatted view. The secondary document saves separately and closes with the split pane. It is general-purpose, separate from Fiction Project cards, which already support characters, locations, and world notes.

Move the pointer to the top edge to reveal the quiet toolbar. Its Aa button opens font and style controls: five presets (Everyday / Georgia, Literary / Charter, Classic / Baskerville, Science fiction / Menlo, Manuscript / Courier New), a custom installed-font choice, size, page width, line spacing, and eight themes (Graphite, Midnight, Chalk, Forest, Obsidian, Arcane, Parchment, Paper). Styles are shared across documents; Markdown itself is unchanged. Some installed fonts do not include bold or italic faces, so available styles depend on the font.

Paragraph focus (target icon, ⇧⌘F) dims text outside the paragraph containing the cursor. It follows clicking, keyboard navigation, and typing. Paragraphs are separated by blank lines; soft line breaks stay in the same paragraph. Focus is per writing window and never modifies text.

A session goal shows net words added since the document window opened. Set the goal in Settings, or set it to 0 to hide it. This is a per-window session count, not a daily history or a cross-device statistic.

An optional goal with a deadline, such as 50,000 words in November, is off until you turn on "Track a goal with a deadline" in Settings → General, beside the daily writing record. It shows words so far, an even pace line, what today needs for the goal to finish on time, and days left, charted over the goal's dates. It counts only words you add, never subtracts for deletions, and has no streaks, badges, or notifications. A small "1,204 / 1,667 today" can sit beside the session goal in the footer (off by default). One goal is active at a time, and clearing it keeps your writing record. It is stored on this Mac only, like the record.

Export (the Manuscript tab's **Export…**, ⇧⌘E, or File → Export This Document…) makes one PDF, EPUB, Word, or Markdown file. The Manuscript and Book looks are starting points, and a compact **Layout** section adjusts them: headings left or centered; a title page on or off, left or centered; the font, size, and line spacing (single, 1.5, or double); margins; and page numbers and a running header. PDF and Word follow every choice; EPUB follows the heading and title page alignment, since an e-reader sets its own type and pages. A Fiction Project keeps its layout in its `.sable-project.json` marker, and exports of a single document share one remembered layout.

The toolbar toggles prose suggestions. A light strikethrough marks words you may want to cut; the underlying text is unchanged. Right-click a suggestion to remove it explicitly or stop flagging that word. Settings lets you edit the comma-separated word/phrase list and font size. Ignoring a word updates this list for all documents.

macOS checks spelling and basic grammar. Right-click flagged text for available corrections. Automatic spelling replacement is disabled to protect intentional fiction wording and invented names. Availability and quality of grammar suggestions depend on macOS and language.

Optional sentence coloring highlights nouns, verbs, adjectives, adverbs, and pronouns using macOS Natural Language locally. These are estimates, particularly for invented names, and are shown in source mode only. Color selections never alter your text.

| Shortcut | Action |
| --- | --- |
| ⌘B | Wrap/unwrap selection in bold markers |
| ⌘I | Wrap/unwrap selection in italic markers |
| ⌘K | Insert Markdown link and select its URL |
| ⇧⌘H | Insert level-two heading at start of line |
| Tab or Escape | Move past closing formatting marks when the caret is at the end of a formatted run; also exit a link URL |
| Return | Move past closing formatting marks and insert a newline |
| ⌘\ | Leave formatting (same behavior as Tab) |
| ⌃⌘S | Toggle the writing desk sidebar |
| ⇧⌘F | Toggle paragraph focus |
| ⌘F | Find in manuscript |
| ⌘Z | Undo text changes |
| ⌘S | Save |
| ⌘, | Settings |

## Build

Requires Apple Swift 6 tools (Xcode or Command Line Tools) and a macOS SDK. Sparkle is the only third-party dependency; SwiftPM downloads its pinned binary framework. Local editing needs no service keys. Community updates require a Sparkle signing key and public release feed; Apple signing is optional.

```sh
sh scripts/build-app.sh
swift test
```

The build script creates a locally ad-hoc-signed app in `build/`. Community builds can be shared without Apple notarization, with a first-launch approval step on macOS. Optional Developer ID signing and notarization are supported.

macOS remembers app icons. If the Dock or Finder still shows an old Sable icon after you rebuild or update, quit Sable and run `killall Dock Finder` (or log out and back in); if it still lingers, `sudo rm -rf /Library/Caches/com.apple.iconservices.store` followed by a restart clears the icon cache.

`swift test` requires Xcode's XCTest framework. See [CONTRIBUTING.md](CONTRIBUTING.md) for the standalone check commands that work with Command Line Tools alone, and for the full list of regression checks.

## Scope and next steps

Validation covers release builds, prose checks, Markdown checks, folder-listing checks, and native-editor checks. Native checks include focus tracking/clearing, font changes, source preservation, margins, Unicode, and formatting exits. The focused workflow also exercises first-run folder setup, saving and canceling a first save, sentence-color settings, and the parallel reading surface. Cross-device iCloud syncing remains untested.

Sable is under active development for macOS; there is no cross-platform release yet. Prose review uses an editable list, not semantic judgment: a flagged word is not necessarily needless. The lightweight matcher excludes common fenced code, inline code, YAML front matter, URLs and inline link destinations; it is not a complete Markdown parser. The source highlighter is also a lightweight grammar, not a full CommonMark renderer; complex nesting and footnotes do not have a rich rendered view there. Source mode retains Markdown markers; the Play button (⇧⌘R) switches to a formatted reading view. This reading view supports headings, emphasis, links, nested lists, quotes, code, tables, and images (shown with captions), but is not a full CommonMark renderer. Word count is whitespace-based. Large-manuscript performance is not yet benchmarked.

iCloud access uses the system file picker and ordinary files, with no custom cloud database. Actual cross-device sync and conflict behavior still need testing with your iCloud account.

For an iPad edition, reuse `QuillCore` and the document model, add a UIKit text view and document-browser target, keyboard commands, and platform-specific spelling/review menus. The current package and editor are Mac-only; building and testing the iPad app requires full Xcode.

## Where to customize

- `Sources/QuillCore/Prose.swift`: prose matching and default word list.
- `Sources/QuillCore/FocusParagraph.swift`: Markdown paragraph boundaries for focus mode.
- `Sources/Quill/ZoomSteps.swift`: zoom limits and how the mouse wheel steps through them.
- `Sources/Quill/FolderBrowser.swift`: folder access, file filtering, navigation, file menu, and the session-only view of a file's folder.
- `Sources/Quill/MarkdownFileTypes.swift`: which file extensions count as Markdown or text, shared by the desk, search, import, and the Open panel.
- `Sources/Quill/RecentFiles.swift`: the optional Recent tab's list (newest first, capped, only recorded while the tab is on).
- `Sources/Quill/FileHandlingSettings.swift`, `Sources/Quill/DefaultAppStatus.swift`: Settings → General sections for the default Markdown app and the optional writing folder.
- `Sources/Quill/SampleProject.swift`, `Examples/Sable Sample Project`: the sample Fiction Project (*Northwatch*) that ships in the app; it is copied into Documents on first launch or from Help → Open Sample Project, never edited in the app. `scripts/check-sample-project.swift` checks it.
- `Sources/Quill/ReferencePane.swift`: general parallel Markdown reading and editing pane.
- `Sources/Quill/ReferenceDocument.swift`: tracked parallel document saving, and stopping when the file changed outside Sable.
- `Sources/Quill/SafeFile.swift`: coordinated, all-or-nothing reads and writes for Find & Replace, revisions, and copies kept in the Trash.
- `Sources/Quill/ReadingView.swift`: native formatted reading view.
- `Sources/Quill/Export.swift`, `Sources/Quill/ExportLayout.swift`, `Sources/Quill/ExportViews.swift`: PDF, EPUB, Word, and Markdown export; the layout choices and the Manuscript and Book looks they start from; the Export sheet.
- `Sources/QuillCore/SentenceStructure.swift`: local parts-of-speech tagging.
- `Sources/Quill/WritingStyle.swift`: font, style, and outline controls.
- `Sources/QuillCore/MarkdownSyntax.swift`: source highlighting spans, chapter outline, and formatting exit logic.
- `Sources/Quill/WorldSidebar.swift`: writing desk with file browser and outline.
- `Sources/Quill/NativeEditor.swift`: visual overlays, text behavior, context menu, and shortcuts.
- `Sources/Quill/EditorStyling.swift`: Markdown styling, name highlights, sentence colors, and prose suggestions in the editor, restyling only the lines you edit.
- `Sources/QuillCore/IncrementalStyling.swift`: how much of the text an edit needs restyled.
- `Sources/Quill/QuillApp.swift`: document handling, settings, and interface.
- `Tests/QuillCoreTests`: Unicode and Markdown-protection checks.
- `Assets/LOGO.md`: how the logo was made with Codex, the logo files, and how `scripts/build-icon.sh` fits the icon to the macOS grid; the icon is packaged with the app.

Apple references: [document-based apps](https://developer.apple.com/documentation/swiftui/building-a-document-based-app/) and [native grammar checking](https://developer.apple.com/documentation/appkit/nstextview/isgrammarcheckingenabled).

`sh scripts/build-preview.sh` builds a separate **Sable Markdown Writer Preview.app** with its own preferences and a copy of the sample project. Its `QUILL_PREVIEW` fixture setup is excluded from the normal app, allowing UI checks without closing an existing draft. Normal app updates take effect after saving work and restarting Sable.

## In-app updates

The app now includes Sparkle, a Check for Updates menu item, and automatic-check settings. The public feed and signing key are configured in UpdateConfig.json; checks require a published release to succeed. Installation is manual. Settings → General has a **Get beta updates** option (off by default) for the occasional rougher build published ahead of a stable release. The GitHub workflow prepares Sparkle-signed community draft releases by default (stable, or beta pre-releases only opted-in users receive), with an optional Apple-notarized mode; pushing code does not release an update. See [the setup and release guide](docs/UPDATES.md). The GitHub signing secret and an end-to-end install/relaunch test are still required before relying on updates.

## Support Sable

Sable is free and always will be. If you'd like to chip in toward the Apple developer fee and ongoing work, you can [buy Sable a book](https://buymeacoffee.com/sablewriter). There's no need to, and nothing in the app is held back.

## License

[MIT](LICENSE). Bundled Sparkle retains its own license notice.

The Sable Markdown Writer name and logo aren't covered by the MIT License. Forks are welcome under their own name and icon; see [TRADEMARK.md](TRADEMARK.md).

## Minimalist editor

- First launch opens a blank document and asks you to choose or create a writing folder, or to just open a file. Cloud folders are recommended; normal files elsewhere remain supported, and no folder is required.
- Setup can include an editable **Sable Guide.md**. Open it again from Help; existing guide edits are never overwritten.
- Writing Style includes Graphite, Midnight, Chalk, Forest, Obsidian, Arcane, Parchment, and Paper themes.
- Zoom with Command-Plus/Minus, reset with Command-0, pinch the trackpad, or hold Command and turn a mouse wheel (5% per notch, 65%–200%). Pinch zoom can be disabled in Writing Style.
- Move the pointer to the top edge to reveal the toolbar. Reading mode, focus, sidebar, styling, and sentence colors remain available from the View menu.
- The footer shows save state. Explicit saves through the editor show completion time; cancellation never reports success. “Saved” refers to the local file, not a cloud-sync confirmation.
- The sentence-color crash is addressed by preventing AppKit's shared color panel from modifying the plain-text manuscript and ignoring text-change notifications with unchanged content.

See [the roadmap](docs/ROADMAP.md) for what's next, and [CHANGELOG.md](CHANGELOG.md) for what's already shipped.

_This README is written by Claude Code._
