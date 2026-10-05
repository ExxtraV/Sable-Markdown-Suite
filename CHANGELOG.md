# Changelog

All notable changes to Sable Markdown Writer are documented here. The app was originally called New Quill; it was rebranded to Sable Markdown Writer in 0.7.0. Entries are written by Claude Code.

## Unreleased

- **Two new writing themes: Starfall and Mist.** Starfall is a deep-blue dark theme, a relative of Midnight (paper `0E1A30`, ink `DAE5F5`, bottom bar `08111F`, edge shade `030810`). It reuses Arcane's particle field with faint icy motes that fall slowly instead of rising. `ParticleField` gained a `drift` multiplier (1 is Arcane's upward pace, negative falls) and `ThemeSpec` gained `particleDrift` (Starfall uses -0.5) and `particlesSetting`. Each particle theme now has its own on/off switch: Arcane keeps `themeParticles` and Starfall uses `themeParticles-starfall`. The "Faint drifting particles" toggle follows the chosen theme. Like Arcane, the motes stop under Reduce Motion, Increase Contrast, and Reduce Transparency. Mist is a cool grey-blue light theme (paper `E8EDF3`, ink `27303A`), distinct from Paper's neutral white and Parchment's warm cream; like the other light themes it has no edge shading. Both pass `check-contrast.swift`, including with Increase Contrast on. Mist's paper was lightened from its first draft (`E4EAF0`) because a few name and sentence colors fell just under 7:1 with Increase Contrast.

## 1.0.0-beta.2

The second beta of 1.0, for people who turn on **Get beta updates**. A sample project, readable dimmed text, VoiceOver and keyboard support, and Help → Report a Bug.

- **Help → Report a Bug… and Send Feedback or Ideas.** Report a Bug opens a small window with *What happened?* and *Steps to reproduce*, and a checkbox, on by default, to include the Sable version (with build), macOS version (with build), and Mac model and chip, with the exact values shown beneath it. **Open in GitHub** opens `github.com/ExxtraV/Sable-Markdown-Suite/issues/new` in the browser with the `bug_report.yml` template's fields filled in through the link; nothing else touches the network, and the writer submits it on GitHub. The link stays under 6,000 characters (GitHub refuses addresses past about 8,000): long text is cut at a word with "[Shortened to fit in a link. Please paste the rest here.]", the two boxes share the room fairly, and the window says so before the click. If Sable has a crash report in `~/Library/Logs/DiagnosticReports` from the last seven days, **Show Latest Crash Report** appears. Sable looks only at file names and dates until that click; then it shows the report (up to 1 MB) in the window with **Copy Report**, and never attaches it. **Send Feedback or Ideas** opens the Ideas category of GitHub Discussions. The bug report template gains an optional **Mac model** field, and the privacy page and both copies of the Sable Guide describe all of this. New `Sources/Quill/BugReport.swift` (link, details, and crash-report finder) and `BugReportView.swift`; new `check-bug-report.swift` covers encoding, the length limit and cuts, the template's field ids, and that finding a report doesn't read it.
- **Accessibility pass: VoiceOver, the keyboard, and the display settings.** Before, about 19 controls had accessibility labels. Now every control in the toolbar, desk, cards, Settings, Writing Style, Export, Revisions, Find & Replace, and the Story Timeline is named, with a value and a hint where they help.
  - **Toolbar.** Only the tools that switch on and off (Writing desk, Paragraph focus, Prose suggestions, Spelling & grammar, Highlight names) report **On** or **Off**; every button used to say "Off", Bold included. The toolbar is one named group, and with VoiceOver or Full Keyboard Access on it stays in view instead of auto-hiding (the page makes room for it). Reading mode and a few other changes are announced.
  - **Desk.** A file, folder, chapter, or heading is one item with its kind and state ("folder, collapsed", "open for writing", "marked Draft"). The buttons that appear only on hover (Show as card, Open beside current document, add to a folder) and the context-menu choices (Rename, Pin, Move to Trash, Move chapter up or down) are VoiceOver actions. Section headers are headings. The desk's width handle adjusts like a slider.
  - **Manuscript tab.** Chapters are focusable: ↑ and ↓ move between them, Return opens one, and ⌥↑ and ⌥↓ move the chapter, with the new position spoken. VoiceOver gets Move up, Move down, Move to top, and Move to end.
  - **Cards.** A card is a named group with actions to pin, close, move to another corner, and resize, in place of dragging. A collapsed card (which opened on hover) opens and stays open when activated. The crop frame moves with the arrow keys or VoiceOver actions. Scene tag chips say what they are and whether a card exists, and the tag picker reads each item as in or not in the scene.
  - **Story Timeline.** The points were buttons that did nothing (the click was a separate gesture), so the keyboard and VoiceOver couldn't use them. Each is now a real button read as its heading and beat ("Chapter 3, Midpoint, point 3 of 12, medium tension"), and the arc has a spoken summary. The summaries are in `StoryTimeline.swift` and covered by `check-outline.swift`.
  - **Writing record.** The chart has a spoken summary and an audio graph; the summary text is in `WritingHistory.swift` and covered by `check-writing-history.swift`.
  - **Sheets.** Fields, lists, and results are named (a Revisions snapshot reads its name, kind, date, and words; a Find match reads "Line 12: …"; a change reads "Changed, 40 words added"); errors and result counts are spoken; the diff text says how much was added and removed. Find & Replace opens with the cursor in Find.
  - **Keyboard.** Escape closes every sheet and popover. The first-launch folder sheet, which Escape couldn't close, has a **Not Now** button (it asks again next time). Customize Tools, whose only reordering was dragging, lets you select a tool and press ⌥↑ or ⌥↓ (or use Move Up and Move Down), add the selected tool with ⌘Return, and has Move up, Move down, and Add actions for VoiceOver. VoiceOver is set to read the window in the order toolbar, page, then cards.
  - **Increase Contrast, Reduce Transparency, and Reduce Motion.** Increase Contrast brightens dimmed Markdown symbols, quotes, notes, and paragraph focus, uses darker name and sentence colors on light themes, firms up outlines, and lifts the floor on faded cards and scene tags. Increase Contrast and Reduce Transparency both give a flat page (no edge shading, no particles) and make the toolbar, cards, and scene tags solid. Reduce Motion now also covers the toolbar and desk sliding and the card, scene tag, and tooltip animations; before it covered only the editor, the particles, and the name shimmer.
- **Contrast, measured and fixed.** New `scripts/check-contrast.swift` computes WCAG 2 contrast for each theme's text, dimmed Markdown symbols, muted words, paragraph-focus dimming, and default name and sentence colors, against the paper and every blend of the edge shading at its default and strongest. It found failures. Dimmed symbols and "Dim evenly" focus were about 2:1 on the dark themes and 1.5:1 on the light ones, and notes, quotes, and scene-break rules were about as faint (all used the system's tertiary gray; these figures are estimates, since that color is dynamic). The lines beside the focused paragraph were 3.5:1 on Parchment and 4.0:1 on Paper. Several light-theme name and sentence colors were under 4.5:1 (Parchment's character gold was 4.0:1). Dim levels are now set per tone in `ThemePalette.swift` (markers 3:1, muted words and the lines beside the paragraph 4.5:1, "Dim evenly" 3:1), and the light themes' name and sentence colors are slightly darker. The far end of paragraph focus stays nearly invisible by design; with Increase Contrast it is held at 3:1. Notes, quotes, and scene-break rules now follow the theme instead of the system's gray.
- **Under the hood:** the theme colors moved from `WorkspaceExperience.swift` into `Sources/QuillCore/ThemePalette.swift`, and the edge-shading opacities now come from it. New `Sources/Quill/AccessibilitySupport.swift` (VoiceOver and Full Keyboard Access state, announcements, motion and transparency helpers); the editor, incremental-styling, benchmark, parallel-document, and toolbar checks compile it. `check-editor.swift` now measures the dimmed colors against the palette, and the random-edit check toggles Increase Contrast. CONTRIBUTING gains an Accessibility section with the conventions and a short manual VoiceOver test.
- **A sample project.** `Examples/` is now one real Fiction Project, *Northwatch* (`Examples/Sable Sample Project`), which `scripts/package-app.py` copies into the app as `Contents/Resources/Sample Project` for both the normal and preview builds. First launch's setup sheet offers **Explore a Sample Project** and Help has **Open Sample Project**. Both copy it into `~/Documents/Sable Sample Project` (a number is added if that name is taken, and nothing existing is touched), show it on the desk for this session without changing the saved writing folder, and open its first chapter. The copy is built in a staging folder and moved into place whole, made writable, and its snapshot is dated when the copy is made so the daily automatic snapshot doesn't land on top of it. The copy is remembered, so asking again opens it instead of making another. New `Sources/Quill/SampleProject.swift`; new `check-sample-project.swift` checks the source and, given a built app, the packaged copy: a valid project, the expected seven cards, aliases and a portrait that resolves, scene tags that all match cards, all six outline beats, one note, one snapshot that compares as expected, the label on every file, and the copying rules.
- **Docs catch-up:** both copies of the Sable Guide now say what the first-launch sheet offers (the website's copy had no mention of the sample project) and that **Not Now**, or Escape, closes setup and Sable asks again next time; exploring the sample doesn't end setup. The README's first-launch line says the same, and the roadmap marks the sample project, the accessibility pass, and Report a Bug done.

## 1.0.0-beta.1

The first beta of 1.0, for people who turn on **Get beta updates**. Opening any Markdown file without a writing folder, export layout choices, and a writing goal with a deadline for challenges like 50,000 words in November.

- **A goal with a deadline**, off by default behind a **Track a goal with a deadline** switch in Settings → General, above the writing record. Turned off, nothing shows in Settings or the footer, and a stored goal is kept. When on: a **November: 50,000 words** preset or a custom word count with start and end dates (up to 366 days). One goal is active at a time. Progress shows words so far, the even pace line, today's target (what finishes on time, spread evenly over the days left), and days left, charted against the pace line.
- **Neutral wording.** Running under an even pace reads "1,900 a day finishes on time"; there's no "behind" state, and no streaks, badges, or notifications. Only words added count, as in the writing record.
- **Optional footer figure**, off by default: "1,204 / 1,667 today" beside the session goal while the goal is running.
- **Stored locally** in the same preferences as the record, as day keys (`yyyy-MM-dd`), so clock changes and time zones never shift a goal. **Clear Goal** keeps the writing record, and clearing the record keeps the goal.
- **Under the hood:** pace math lives in `Sources/Quill/WritingGoal.swift` with the views in `WritingGoalView.swift`. `check-writing-history.swift` now compiles `WritingGoal.swift` too and covers mid-day starts, the end date itself, daylight-saving changes (New York, Sydney, and São Paulo's midnight-less day), leap years, New Year, presets, and damaged stored goals.
- The roadmap marks the monthly word goal done.
- **Export layout choices.** A **Layout** section in the Export sheet: heading alignment (left or centered), title page on or off and its alignment, font (Times New Roman, Georgia, Palatino, Arial, Courier New), size (10–14 pt), line spacing (single, 1.5, double), margins (0.75–1.5 in), page numbers, and running header. The Manuscript and Book looks fill these in as starting points (**Reset** returns to the look). PDF and Word follow every choice; EPUB takes the heading and title page alignment; Markdown takes the title page. The page number joins the running header when there is one and otherwise sits centered at the foot. Saved per project in `.sable-project.json` (`exportLayout`, plain strings, read leniently so a hand edit never breaks the marker), and in preferences for single-document exports, which can now include a title page. The Book look now uses Palatino in PDF too (was Charter) and single spacing (was about 1.25), and 1-inch margins (was about 0.9). Long titles wrap on the PDF title page. New `Sources/Quill/ExportLayout.swift`; `check-export.swift` covers every choice in PDF and Word, saved layouts, and damaged saved values.
- **Open any Markdown file, with or without a writing folder.** The writing folder is now optional. First launch offers **Just Open a File** beside choosing a folder, and a window opened on a file from Finder skips setup. With no writing folder, the writing desk shows the open file's own folder. Settings → General → **Writing folder** chooses one later or stops using one (Sable only forgets the folder; no file is touched).
- **A file outside the writing folder.** The desk stays on the writing folder and adds one quiet line with **Show Folder**, which shows the file's folder for this session only, with a **Back to** link. The saved writing folder never changes, and the desk returns by itself when the open file is back inside it.
- **Make Sable the default for Markdown, only if you choose.** Settings → General → **Markdown files** shows which app opens Markdown now and has **Make Sable the Default for Markdown**; macOS asks you to confirm. Plain text (`.txt`) is a separate button, also off by default. Sable still registers as an alternate handler only, and never changes the default by itself. The setting updates when you come back from Finder's Get Info.
- **An optional Recent tab.** Turn on **Recent tab** in Settings → General → Writing desk (or the desk's sliders menu) and the desk gains a **Recent** tab listing the files you have open, newest first, from any folder. It's off by default, is recorded only while on, stays on your Mac, and turning it off forgets the list; **Clear Recent Files** empties it any time.
- **More Markdown extensions.** `.mdown`, `.mkd`, `.mkdn`, and `.mdwn` are declared in Info.plist (Markdown and plain text are now separate document types) and appear in the writing desk, search, import, and the Open panel.
- **Open Recent and dropping a file.** File → Open Markdown File… now adds to Open Recent. Dropping one Markdown or text file on the page opens it, as File → Open does, instead of pasting its path into your text.
- **The desk's tabs always fit.** With the optional Recent tab there can be four (Files, Outline, Manuscript, Recent). The strip shows names when they fit, then icons alone, then a dropdown, so it never spills past the desk's edge however narrow the desk is dragged.
- **Fixed: snapshots of the wrong files.** With a Fiction Project showing in the desk and a file from elsewhere open, Revision History and Save Snapshot used the project's chapters. The open file now decides what a snapshot covers, and the automatic daily snapshot only ever applies to a Fiction Project. Name highlights likewise follow the open file, not the desk's project.
- **Under the hood:** new `MarkdownFileTypes.swift`, `DefaultAppStatus.swift`, and `FileHandlingSettings.swift`; new `RecentFiles.swift`; new checks `check-document-types.py`, `check-default-app.swift`, and `check-recent-files.swift`; `check-project-browser.swift`, `check-folder.swift`, `check-revisions.swift`, and `check-file-safety.swift` cover visiting a folder, no writing folder, the new extensions, where snapshots go, and files from anywhere.

## 0.10.1

The new sleeping-curl icon, open files that follow a rename or move, folders inside folders from the writing desk, drag from anywhere on a row, and update checks at the renamed repository's address.

- **The app icon is the new sleeping-curl sable.** The Dock, Finder, and About panel now show the sable asleep, curled nose to tail, matching the website. The icon is sized to macOS's icon grid, so it sits at the same size as other apps in the Dock rather than a little larger, and the 16, 32, and 64 pixel versions use a simplified black-and-white mark so the curl stays readable in small lists. macOS keeps old icons in a cache; if the previous one lingers, quit Sable and run `killall Dock Finder`. The README now opens with the logo, in light and dark versions.
- **Under the hood:** `scripts/build-icon.sh` now builds `Assets/Sable.icns` through `scripts/render-icon.swift`, and a new check, `check-app-icon.swift`, fails if the icon drifts off the macOS grid, loses a size, or gets too faint to read.
- **Renaming an open file no longer says it was deleted.** Renaming or moving a file in the writing desk while it's open now carries it along, on the page, beside your draft, and as a card, and the next save goes to the new name. Renames and moves in Finder are followed the same way. The note still appears when a file really is deleted or moved to the Trash. Before, a file you had switched to in the desk lost track of its file when renamed, and could follow a *previously* open file instead if that one was moved. Renaming or moving the file open beside your draft is no longer blocked.
- **Drag from anywhere on a row.** In the writing desk's file list and the Manuscript tab, pressing anywhere on a row (icon, name, padding, or word count) now starts a drag. Before, only part of a row did. A double-click on a folder now opens it instead of opening and closing it again.
- **The hover “+” on a folder offers a file or a folder.** It was only ever a new Markdown file. Now it's a small menu: **New Markdown File** or **New Folder**, with the folder's own kind of item (a chapter, a character…) first when it has one. Control-click a folder has **New Folder** too, including on a Fiction Project's own row. A new folder is made right away as “Untitled Folder”, its parent opens, and its name is ready to type, as in Finder. If the name you type is already taken, Sable says so and leaves the folder as it was. It works at any depth, in plain writing folders and in Fiction Projects. While searching or filtering, there's no list to type a name in, so Sable asks in a small window instead.
- **Under the hood:** `check-folder.swift` and `check-fiction.swift` now cover folders made several levels deep, placeholder names, taken names (with or without matching case), and folders made inside Manuscript and Characters.
- **Updates use the renamed repository's address.** The repository is now `ExxtraV/Sable-Markdown-Suite`, and `UpdateConfig.json` points the update feed there. Sable 0.10.0 and earlier have the old address built in and reach the new one through GitHub's redirect, so the old `ExxtraV/Sable` name must never be reused for another repository. `docs/UPDATES.md` explains.
- The Sable Guide's description of the **+** buttons now matches the new folder menu, and the roadmap marks these fixes done.

## 0.10.0

Instant typing in long manuscripts, smooth pinch zoom, ⌘ + mouse wheel zoom, faster theme and font changes, safer file handling after an audit of every place Sable writes, moves, or deletes your files, and an opt-in beta update channel.

- **Instant typing, however long the file.** The editor restyles only the lines around an edit instead of the whole document, and hands text to SwiftUI after a short pause instead of on every keystroke. A keystroke in a 100,000-word file went from about 430 ms to about 5 ms with the default settings, and from about 1.8 s to about 24 ms with everything on; it now costs the same at any length. The status bar's word count and cuts update when you pause (within a third of a second) instead of on every letter. Numbers are in `docs/performance/typing-baseline.md`.
- **Smooth pinch zoom.** A pinch scales a picture of the page while your fingers move and applies the zoom once when they lift, keeping the line under the pointer in place. Before, every step of a pinch restyled the whole document.
- **Zoom with ⌘ and a mouse wheel.** Hold ⌘ and turn a notched mouse wheel over a writing or reading surface: away from you zooms in, 5% per notch, within 65%–200%. Trackpads keep scrolling.
- **Faster theme and font changes.** A setting change repaints from the Markdown spans and sentence tags the editor already keeps, instead of parsing and tagging the whole text again: well under half the time of 0.9.0 in a 100,000-word file.
- **Beta updates.** Settings → General has a **Get beta updates** checkbox, off by default. The release workflow can publish beta pre-releases that only opted-in users receive.
- **Find & Replace in Project** won't change anything if it can't save its safety snapshot first. If a replacement stops partway, it puts back the files it already changed and names any it couldn't.
- **Undo Replace won't erase newer words.** It puts back only files that still read exactly as the replacement left them, lists any it left alone, and undoes the open document directly on the page.
- **A file open beside your draft** saves your latest words before Find & Replace or a restore touches it, then shows the new text. If the file changes somewhere else while you have edits beside your draft, Sable stops instead of saving over it. Choose **Keep Mine** or **Use Saved File**; the other version goes to the Trash as a copy.
- **Export** can't be saved over the files being exported, a file open in Sable, or into the Manuscript folder. A file it replaces goes to the Trash as a copy first.
- **Restoring from Revision History** runs in the background. If it stops partway, it says how many files were restored and where the safety snapshot is.
- **Import** never replaces a file that appears with the same name at the same moment.
- **Changing a card's color or picture** no longer runs on the main thread, so it can't freeze Sable when that file is open beside your draft.
- **An open file moved to the Trash or deleted outside Sable** now gets a quiet note under the page (or in the side pane). **Put Back** returns a trashed file to its folder, **Save Again** writes a deleted file back, and **Save As…** keeps it somewhere else. Before, Sable kept saving a trashed file into the Trash without a word.
- **The writing desk won't trash a file that's open in another window**, and it checks before clearing the page in this one.
- **Switching files** reads the file's date before its text, so a change made mid-switch makes the next save ask instead of overwriting it.
- The Sable Guide has a new section, "How Sable protects your files," and a short "Updates" section.
- **Under the hood:** Sable builds again with Command Line Tools 27.0 (Swift 6.4). New checks cover typing speed, incremental styling against thousands of random edits, range-limited styling, zoom steps, and file safety.

## 0.9.0

Bug fixes (top margin, Reading Mode swipe, clearer on/off, update-check settings), a universal folder **+**, right-click a highlighted name to open its file or card, two new themes (Obsidian, Arcane with particles), a daily writing record, and Concept + Outline + Story Timeline for planning.

- **Export your manuscript.** In a Fiction Project, press **Export…** on the Manuscript tab (or File → Export Manuscript…, ⇧⌘E) to turn every chapter, in the order you arranged them, into one **PDF**, **EPUB**, **Word (.docx)**, or **Markdown** file. Pick which chapters to include, add a title page, and choose a **Manuscript** look (Courier-style, double spaced, running header, ready for editors) or a **Book** look (justified serif, page numbers). US Letter and A4 are supported. The PDF has a clickable chapter outline. File → Export This Document… exports just the page you have open.
- **Names & places highlighting.** Character, location, and world-note names take a color and a soft shimmer, a band of light drifting through the letters (strength and speed are sliders; Reduce Motion is respected). Characters are found by full name, first name, last name, file name, and aliases; locations and world notes match the whole phrase only, so "Academy" won't light up "Highlandsburg Academy". Turn characters, locations, and world notes on or off separately in Settings → Highlights, or everything at once with View → Highlight Names & Places.
- **Settings, tidied.** Settings is now a wider window with General, Writing, Highlights, and Review tabs.
- **Export at the bottom of the writing desk**, always within reach.
- **New Sable logo.**
- **Download as a disk image.** Releases now include a `.dmg` that opens with the app next to an Applications shortcut, so installing is a single drag. Automatic updates still work as before.
- **A better Markdown editor.**
  - **Lists and quotes:** Return continues them, Return on an empty item ends the list, and Tab and Shift-Tab indent and outdent.
  - **Markdown menu:** strikethrough, inline code, quote, bulleted, numbered and task lists, and scene break, with the heading command now cycling # ## ###. A web address on the clipboard becomes a link's destination.
  - **Styling:** scene breaks (`* * *`, `---`), `<!-- notes to yourself -->` (dimmed, hidden in Reading Mode, never exported), images, task boxes, table rows, and footnotes are styled. Symbols can be dimmed or left normal.
  - **Typography:** optional curly quotes, em dashes, and ellipses as you type (Settings → Writing).
  - **Status bar:** shows the word count of your selection.
- **Find & Replace in Project** (⌥⇧⌘F): search every Markdown file in your Fiction Project or writing folder, preview matches, leave files out, replace all, and undo.
- **Import Document…** (File menu) turns Word, RTF, OpenDocument, and HTML files into Markdown, and **Paste as Markdown** (⌃⌘V) keeps italics, bold, headings, lists, and links from Word, Google Docs, or a web page.
- **Markdown Cheat Sheet** in the Help menu.
- **Revisions.** Save a named snapshot of your whole manuscript (or the open document) before a big rewrite, from File → Save Snapshot (⌥⌘S) or the Revisions button at the bottom of the writing desk. Revision History (⌥⌘R) shows what changed since any snapshot, chapter by chapter, with new words underlined in green and removed words struck through in red, and restores one chapter or the whole draft. Sable saves a safety snapshot before every restore and before Find & Replace changes files, and keeps a daily snapshot of a Fiction Project when it has changed (Settings → General). Snapshots are plain Markdown copies in a hidden `.sable-revisions` folder.
- **Under the hood:** the editor, Reading Mode, and every export now read Markdown through one shared reader, so scene breaks, notes, lists, tasks, and tables mean the same thing everywhere. Reading Mode gains tables, nested lists, and images-as-captions, and exports handle nested lists, tasks, and tables.
- **Dragging** one item of a multi-item selection in the writing desk now moves the whole selection.
- **Edge shading for every dark theme.** Graphite, Midnight, Forest, and Chalk now fade darker toward the edges of the page and stay lightest around your text. Turn it off, or set how deep it is, in Writing Style → Theme.
- **A toolbar that starts minimal and grows with you.** It begins with just the writing desk, Reading Mode, Writing Style, and Paragraph Focus. Choose ⋯ → Customize Tools (or View → Toolbar) to add headings, bold, italic, links, quotes, lists, scene breaks, sentence colors, find & replace, export, snapshots, and more, and drag them into your own order.
- **Writing Style, redesigned.** Themes are picked from small page swatches, the sliders show their values, a live preview uses your theme and font, and the window is roomier and grouped.
- **More breathing room at the top of the page.**
- **Two new themes.** **Obsidian** is about as dark as a theme gets. **Arcane** is a deep purple for fantasy writing, with faint motes of light drifting behind the text.
- **A writing record.** Settings → General charts the words you've added each day for the last 30 days, plus your best day and lifetime total. It only counts progress; deleting words never counts against you. Kept only on this Mac.
- **Concept and the Story Timeline, for planning.** Every new Fiction Project gets a **Concept.md** with a few questions to think a story through before drafting, and an **Outline** folder for your own planning headings. Tag a heading with a beat in parentheses — `(Inciting Incident)`, `(Rising Action)`, `(Midpoint)`, `(Climax)`, `(Falling Action)`, `(Resolution)` — and **Story Timeline…** (File menu, ⌥⌘Y) plots it on a dramatic arc.
- **Clearer on/off.** Highlight Names & Places, spelling & grammar, and prose suggestions are checkable from the View menu, and an "on" toolbar tool shows a small dot.
- **Fixed:** the two-finger swipe to show or hide the writing desk now works in Reading Mode too.
- **Update checks, made visible.** Settings → General shows when Sable last checked for an update and lets you choose daily, every 3 days, or weekly.

## 0.8.2

Edge shading for all dark themes, a redesigned Writing Style window, and a customizable, minimal-by-default toolbar.

## 0.8.1

Manuscript export, name highlighting, a much better Markdown editor, and a disk-image download. See the 0.9.0 entry above for the shared feature descriptions (export, highlighting, editor improvements, revisions, import) that first shipped in this release.

## 0.8.0

Manuscript export (PDF/EPUB/Word/Markdown), name highlighting, and a disk-image download.

## 0.7.0

Rebrand to **Sable Markdown Writer** (from New Quill).

- **Fiction Projects (first steps):** create a project with a ready-made folder structure, see only the project once you're inside it, add chapters, characters, locations, and world notes from templates, and convert a project back to a regular folder at any time. Characters, locations, and world notes can float over the page as cards that snap to a corner, pin open or shrink to a tab, and carry a picture.
- New **Chalk** theme, and a darker bottom bar in Graphite, Midnight, and Chalk.
- Paragraph focus now fades text gradually with distance from what you're writing.
- The top toolbar is compact again, and every tool names itself and its shortcut on hover.
- A document open beside your draft scrolls and zooms on its own.

## 0.6.1

Refines the writing desk and toolbar and fixes file switching.

- Switching files no longer closes and reopens the window or leaves full screen.
- The writing desk is calmer: Files and Outline are separate tabs, extensions are hidden by default, and the list can be sorted, resized, and tuned.
- Folders can be colored, labeled, pinned, filtered, focused, searched, dragged into each other, renamed, and moved to the Trash with undo.
- The toolbar can sit on the top, left, or right; auto-hide, always show, or turn off (⌥⌘T).
- The app no longer opens a file picker at launch; it reopens your last document.

## 0.6.0

Makes the writing experience calmer and more focused.

- The Writing Desk browses nested folders; clicking a Markdown file switches the active document in the same window.
- Automatic writing tabs are disabled; Control-click a file to open it beside your draft in a parallel pane.
- New writers begin with a blank document and choose a writing folder, with an optional editable Markdown guide.
- Five themes, fiction-oriented font presets, custom fonts, zoom, optional pinch-to-zoom, paragraph focus, and a top-edge toolbar.
- The writing desk can be shown with a two-finger horizontal trackpad gesture.

## 0.5.0 / 0.5.1

Adds in-app update checks through Sparkle, with signed downloads and a choice of when to install. Your Markdown files remain separate from application updates.
