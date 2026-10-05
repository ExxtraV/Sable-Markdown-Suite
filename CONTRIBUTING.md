# Contributing to Sable Markdown Writer

Sable is a SwiftPM package (`Quill`/`QuillCore`) plus a set of shell and Python scripts under `scripts/`. This guide covers building it, running the checks, and how a change gets from a branch into `main`.

## Prerequisites

- macOS, with Apple Swift 6 tools (Xcode or the Command Line Tools) and a macOS SDK.
- Sparkle is the only third-party dependency; SwiftPM downloads its pinned binary framework, so local editing needs no service keys or accounts.

## Build

```sh
sh scripts/build-app.sh
swift test
```

`scripts/build-app.sh` builds a release binary with SwiftPM, packages it with Sparkle into `build/Sable Markdown Writer.app`, and ad-hoc signs it — no Apple Developer account needed. If the module cache complains on a clean checkout, clear it with `rm -rf .build/module-cache` and rebuild.

`swift test` runs `Tests/QuillCoreTests` and requires Xcode's XCTest framework. If you only have the Command Line Tools, use the standalone checks below instead.

### Command Line Tools 27.0

Command Line Tools 27.0 (Swift 6.4, macOS 27 SDK) without Xcode can't build Sable out of the box. `scripts/build-app.sh` works around the two problems below, but only when `xcode-select -p` points at the Command Line Tools. CI and anyone with Xcode are unaffected.

- **The macOS 27 SDK needs Xcode's SwiftUI macros.** In that SDK, SwiftUI's `@State` is a macro implemented by the `SwiftUIMacros` compiler plugin. Xcode ships that plugin; the Command Line Tools don't (their `usr/lib/swift/host/plugins` has only the Observation, Swift, and Testing macros). Every `@State` then fails with "plugin for module 'SwiftUIMacros' not found". The script picks the newest installed SDK whose SwiftUI doesn't need the plugin (26.5 today) and prints a `note:` naming it. You can override it by setting `SDKROOT` yourself. The real fix is to install Xcode or wait for a Command Line Tools release that includes the plugin. Once `usr/lib/swift/host/plugins/libSwiftUIMacros.dylib` exists, the script stops pinning.
- **A leftover SDK folder stops Swift Build.** Swift 6.4's default build system, Swift Build, reads every `SDKs/*.sdk` folder when it starts. If any of them has no `SDKSettings.plist`, it fails before compiling anything with "Could not initialize build system … Unknown error parsing property list", and setting `SDKROOT` doesn't help. The native build system never reads them. The one seen so far was a partial `MacOSX26.0.sdk` that no installer package owns (`pkgutil --file-info` lists none). When the script finds a folder like that, it prints the command to delete it (`sudo rm -rf …`) and falls back to `--build-system native`. That build system is deprecated and will be removed in a future SwiftPM, so treat it as a stopgap and delete the folder.

The standalone checks compile SwiftUI sources with `swiftc`, so on these tools, export the same SDK before running them. With Swift 6.4, also build the checks' release output with the native build system, because Swift Build uses a different output layout (`.build/out/Products/Release`, no `Modules/` or `QuillCore.build/`):

```sh
export SDKROOT=$(xcrun --sdk macosx26.5 --show-sdk-path)
QUILL_CHECK_BUILD=$(swift build -c release --build-system native --show-bin-path)
```

## How the check scripts work

Most of Sable's regression coverage lives outside XCTest, in `scripts/check-*.swift`. Each one is a small, self-contained `main`-style Swift file that exercises one area of the app (Markdown parsing, the folder browser, export, and so on) with plain assertions. You compile a check together with the exact source files it depends on using `swiftc`, then run the resulting binary directly — no test framework or simulator required, which is also why these checks can run with just the Command Line Tools.

Two things to know before adding or changing one:

- **A check's compile list is exact.** `swiftc` is given only the source files a check needs; a file outside that list can't be referenced. If you add a dependency to code under test, add the new file to every check command (here, in `.github/workflows/check.yml`, and in `Where to customize` in the README) that compiles it.
- **Some checks need release build artifacts.** Checks that exercise `Quill` app code (not just `QuillCore`) link against `.o` files or `Modules` from a `swift build -c release` output directory, because they use types built as part of the app target. Build first, then point `-I`/the `.o` glob at that directory (see the commands below — substitute `x86_64-apple-macosx` for `arm64-apple-macosx` on Intel).

`.github/workflows/check.yml` is the source of truth for exactly which checks run in CI and in what order; the first block below mirrors it exactly.

### Core checks (no build required, run in CI)

```sh
swiftc -O Sources/QuillCore/MarkdownSyntax.swift Sources/QuillCore/MarkdownEditing.swift Sources/QuillCore/MarkdownDocument.swift Sources/QuillCore/IncrementalStyling.swift Sources/QuillCore/Prose.swift Sources/QuillCore/FocusParagraph.swift Sources/QuillCore/SentenceStructure.swift scripts/check-styling-ranges.swift -o /tmp/quill-styling-range-checks && /tmp/quill-styling-range-checks
swiftc Sources/QuillCore/MarkdownEditing.swift Sources/QuillCore/MarkdownDocument.swift scripts/check-markdown-editing.swift -o /tmp/quill-markdown-editing-checks && /tmp/quill-markdown-editing-checks
swiftc Sources/Quill/Import.swift Sources/Quill/MarkdownFileTypes.swift scripts/check-import.swift -o /tmp/quill-import-checks && /tmp/quill-import-checks
swiftc Sources/Quill/Import.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/ScrivenerReader.swift Sources/Quill/ScrivenerImport.swift Sources/Quill/FictionProject.swift Sources/Quill/FolderBrowser.swift scripts/check-scrivener.swift -o /tmp/quill-scrivener-checks && /tmp/quill-scrivener-checks
swiftc Sources/Quill/SafeFile.swift Sources/Quill/ProjectSearch.swift Sources/Quill/MarkdownFileTypes.swift scripts/check-project-search.swift -o /tmp/quill-search-checks && /tmp/quill-search-checks
swiftc Sources/QuillCore/ThemePalette.swift scripts/check-contrast.swift -o /tmp/quill-contrast-checks && /tmp/quill-contrast-checks
swiftc Sources/Quill/ZoomSteps.swift scripts/check-zoom-steps.swift -o /tmp/quill-zoom-step-checks && /tmp/quill-zoom-step-checks
swiftc Sources/Quill/SafeFile.swift scripts/check-file-safety.swift -o /tmp/quill-file-safety-checks && /tmp/quill-file-safety-checks
swiftc Sources/Quill/SafeFile.swift Sources/Quill/Revisions.swift scripts/check-revisions.swift -o /tmp/quill-revision-checks && /tmp/quill-revision-checks
swiftc Sources/Quill/AccessibilitySupport.swift Sources/Quill/ToolbarTools.swift scripts/check-toolbar.swift -o /tmp/quill-toolbar-checks && /tmp/quill-toolbar-checks
swiftc Sources/Quill/WritingHistory.swift Sources/Quill/WritingGoal.swift scripts/check-writing-history.swift -o /tmp/quill-writing-history-checks && /tmp/quill-writing-history-checks
swiftc scripts/check-app-icon.swift -o /tmp/quill-app-icon-checks && /tmp/quill-app-icon-checks

swiftc Sources/Quill/FolderBrowser.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/FictionProject.swift scripts/check-folder.swift -o /tmp/quill-folder-checks
/tmp/quill-folder-checks
swiftc Sources/Quill/FolderBrowser.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/FictionProject.swift scripts/check-fiction.swift -o /tmp/quill-fiction-checks
/tmp/quill-fiction-checks
swiftc -parse-as-library Sources/Quill/FolderBrowser.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/FictionProject.swift scripts/check-project-browser.swift -o /tmp/quill-project-browser-checks
/tmp/quill-project-browser-checks
swiftc Sources/Quill/DefaultAppStatus.swift scripts/check-default-app.swift -o /tmp/quill-default-app-checks
/tmp/quill-default-app-checks
swiftc Sources/Quill/RecentFiles.swift scripts/check-recent-files.swift -o /tmp/quill-recent-files-checks
/tmp/quill-recent-files-checks
swiftc Sources/Quill/BugReport.swift scripts/check-bug-report.swift -o /tmp/quill-bug-report-checks
/tmp/quill-bug-report-checks
```

`check-bug-report.swift` guards Help → Report a Bug…. Run from the repository root, it confirms the GitHub link carries only the writer's words and, if the checkbox is on, the three version fields; that `&`, `#`, `+`, accents, flags, and line breaks survive the trip; that the link stays under 6,000 characters, cutting long text at a word with a note and sharing the room fairly between the two boxes; that every field in the link has a matching `id:` in `.github/ISSUE_TEMPLATE/bug_report.yml`; and that the crash-report finder only looks at names and dates (a report it can't read is still found, and reading is a separate call made only when the writer clicks). If you add a field to the link, add it to the template too. Nothing in this feature may touch the network.

`check-scrivener.swift` guards File → Import Scrivener Project…. Run from the repository root, it reads the three hand-built projects in `Tests/Fixtures/Scrivener` and a set of deliberately damaged ones, plans and writes a Fiction Project from them into a temporary folder, checks that Sable finds the chapters and cards it made, and confirms that none of it changes the Scrivener projects. The fixtures are invented text in the shape of real Scrivener 3 projects; never add anyone's real project to the repository. `docs/scrivener-format.md` describes the format and how to run the check over your own projects, which prints counts only.

The sample project the app ships is the folder `Examples/Sable Sample Project`, and `check-sample-project.swift` reads it. `scripts/package-app.py` copies it into the app as `Contents/Resources/Sample Project`; given the built app, the check also confirms the packaged copy matches the source. It checks that the sample is a valid Fiction Project with the expected cards, scene tags, outline beats, note, and snapshot. It is a real Fiction Project, so change it by opening the folder in Sable. Keep the `_Sample text written by Claude Code._` line on every file in it, and re-run the check after editing.

### Additional local-only checks (not run in CI)

`check-editor.swift` and `check-reading-reference.swift` below cover most of `MarkdownSyntax.swift` and `Prose.swift` indirectly, but these two exercise them directly and are useful in isolation:

```sh
swiftc Sources/QuillCore/Prose.swift scripts/check-prose.swift -o /tmp/quill-prose-checks
/tmp/quill-prose-checks

swiftc Sources/QuillCore/MarkdownSyntax.swift Sources/QuillCore/MarkdownEditing.swift Sources/QuillCore/MarkdownDocument.swift Sources/QuillCore/IncrementalStyling.swift scripts/check-markdown.swift -o /tmp/quill-markdown-checks
/tmp/quill-markdown-checks
```

### Checks that need a release build (run in CI)

Build once, then run all of these against the same output directory:

```sh
QUILL_CHECK_BUILD=$(swift build -c release --show-bin-path)

swiftc -I "$QUILL_CHECK_BUILD/Modules" Sources/Quill/NativeEditor.swift Sources/Quill/EditorStyling.swift Sources/Quill/Import.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/AccessibilitySupport.swift Sources/Quill/WorkspaceExperience.swift Sources/Quill/BugReport.swift Sources/Quill/ZoomSteps.swift Sources/Quill/FolderBrowser.swift Sources/Quill/FictionProject.swift Sources/Quill/WorldSidebar.swift Sources/Quill/RecentFiles.swift Sources/Quill/WritingStyle.swift scripts/check-editor.swift "$QUILL_CHECK_BUILD"/QuillCore.build/*.o -o /tmp/quill-editor-checks
/tmp/quill-editor-checks

swiftc -O -I "$QUILL_CHECK_BUILD/Modules" Sources/Quill/NativeEditor.swift Sources/Quill/EditorStyling.swift Sources/Quill/Import.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/AccessibilitySupport.swift Sources/Quill/WorkspaceExperience.swift Sources/Quill/BugReport.swift Sources/Quill/ZoomSteps.swift Sources/Quill/FolderBrowser.swift Sources/Quill/FictionProject.swift Sources/Quill/WorldSidebar.swift Sources/Quill/RecentFiles.swift Sources/Quill/WritingStyle.swift scripts/typing-fixture.swift scripts/check-incremental-styling.swift "$QUILL_CHECK_BUILD"/QuillCore.build/*.o -o /tmp/quill-incremental-styling-checks
/tmp/quill-incremental-styling-checks

swiftc -O -I "$QUILL_CHECK_BUILD/Modules" Sources/Quill/NativeEditor.swift Sources/Quill/EditorStyling.swift Sources/Quill/Import.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/AccessibilitySupport.swift Sources/Quill/WorkspaceExperience.swift Sources/Quill/BugReport.swift Sources/Quill/ZoomSteps.swift Sources/Quill/FolderBrowser.swift Sources/Quill/FictionProject.swift Sources/Quill/WorldSidebar.swift Sources/Quill/RecentFiles.swift Sources/Quill/WritingStyle.swift scripts/typing-fixture.swift scripts/bench-typing.swift "$QUILL_CHECK_BUILD"/QuillCore.build/*.o -o /tmp/quill-typing-bench
/tmp/quill-typing-bench --smoke

swiftc -I "$QUILL_CHECK_BUILD/Modules" Sources/Quill/NativeEditor.swift Sources/Quill/EditorStyling.swift Sources/Quill/Import.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/ReadingView.swift Sources/Quill/SafeFile.swift Sources/Quill/ReferenceDocument.swift Sources/Quill/ReferencePane.swift Sources/Quill/AccessibilitySupport.swift Sources/Quill/WorkspaceExperience.swift Sources/Quill/BugReport.swift Sources/Quill/ZoomSteps.swift Sources/Quill/FolderBrowser.swift Sources/Quill/FictionProject.swift Sources/Quill/WorldSidebar.swift Sources/Quill/RecentFiles.swift Sources/Quill/WritingStyle.swift scripts/check-reading-reference.swift "$QUILL_CHECK_BUILD"/QuillCore.build/*.o -o /tmp/quill-parallel-checks
/tmp/quill-parallel-checks

swiftc -I "$QUILL_CHECK_BUILD/Modules" Sources/Quill/SafeFile.swift Sources/Quill/ProjectSearch.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/StoryTimeline.swift scripts/check-outline.swift "$QUILL_CHECK_BUILD"/QuillCore.build/*.o -o /tmp/quill-outline-checks
/tmp/quill-outline-checks

swiftc -I "$QUILL_CHECK_BUILD/Modules" Sources/Quill/Export.swift Sources/Quill/ExportLayout.swift Sources/Quill/FictionProject.swift Sources/Quill/FolderBrowser.swift Sources/Quill/MarkdownFileTypes.swift scripts/check-export.swift "$QUILL_CHECK_BUILD"/QuillCore.build/*.o -o /tmp/quill-export-checks
/tmp/quill-export-checks

swiftc -I "$QUILL_CHECK_BUILD/Modules" Sources/Quill/SampleProject.swift Sources/Quill/FictionProject.swift Sources/Quill/FolderBrowser.swift Sources/Quill/MarkdownFileTypes.swift Sources/Quill/SafeFile.swift Sources/Quill/Revisions.swift Sources/Quill/ProjectSearch.swift Sources/Quill/StoryTimeline.swift scripts/check-sample-project.swift "$QUILL_CHECK_BUILD"/QuillCore.build/*.o -o /tmp/quill-sample-project-checks
/tmp/quill-sample-project-checks "build/Sable Markdown Writer.app"
```

`check-incremental-styling.swift` makes thousands of seeded random edits through the editor's real typing path and, after each one, compares every attribute against a from-scratch restyle of the same text. The editor hands typing to SwiftUI's copy of the text in batches, so the check also settles that copy each of the ways the app does (a pause, the idle timer, a real `NSDocument` save, a SwiftUI redraw with the older text, losing focus, an autosave while typing is pending) and then requires it, and the status bar's word and suggestion counts, to match the editor exactly. On a failure it prints the seed, the edit, and the first differing run, and saves the document to `$TMPDIR/quill-fuzz-failure.md`. `QUILL_FUZZ_SEED` and `QUILL_FUZZ_EDITS` change the seed and length for longer local runs; `QUILL_FUZZ_SABOTAGE=1` corrupts one attribute on purpose to confirm the comparison catches it. Random setting changes (theme, fonts, zoom, colors, sentence-color classes, names) are mixed into the edits, and each configuration ends with a run of setting changes that must all repaint from the spans and sentence tags the editor keeps between passes; `QUILL_FUZZ_SABOTAGE=cache` drops one kept span to confirm a stale cache is caught too. Both it and the benchmark share the generated manuscript in `scripts/typing-fixture.swift`.

`check-styling-ranges.swift` is the pure-logic half: on random Markdown built to hit every construct that crosses a line (fences, notes, front matter, `\r`, U+2028), it proves the range-limited grammar, prose review, sentence colors, outline, formatting exit, and focus paragraph find exactly what verbatim copies of the old whole-text code find, and that whenever the editor would restyle only a region, nothing outside it changes. `QUILL_RANGE_SEED` and `QUILL_RANGE_DOCUMENTS` change the seed and size of a run.

`bench-typing.swift` times keystrokes in a generated 10k-, 50k-, and 100k-word manuscript. CI runs it with `--smoke` only to keep it building; run it without flags for real numbers (`--out file.md` saves them, `--write-fixture path.md` writes the 100k-word manuscript to open in the app). [docs/performance/typing-baseline.md](docs/performance/typing-baseline.md) records the baseline.

`check-contrast.swift` measures the WCAG 2 contrast of every color the editor draws text in against each theme's page, in the default look and with Increase Contrast on. The numbers come from `Sources/QuillCore/ThemePalette.swift`, which the app draws with: each theme's text, the dimmed Markdown symbols, muted words (quotes, notes), paragraph focus (the lines beside the paragraph, "Dim evenly", and the far end of the fade), and the default name and sentence colors, over the paper and over every blend of the edge shading at its default strength and at the slider's maximum. It prints a table and exits non-zero on a failure. The limits are listed at the top of the script. The far end of the paragraph-focus fade has none by default because it is meant to disappear; with Increase Contrast it must stay at 3:1. A color a writer picks themselves isn't checked. Add a theme or change a color in `ThemePalette.swift` and run it; if you add a new kind of text the editor dims or colors, add its row to the script too.

### Python checks

A few checks validate the release pipeline itself rather than the app, and run with `python3` directly instead of `swiftc`:

```sh
python3 scripts/check-update-signatures.py
python3 scripts/check-release-modes.py
python3 scripts/check-merge-appcast.py
python3 scripts/check-blog.py
python3 scripts/check-site.py
python3 scripts/check-document-types.py
```

`scripts/check-blog.py` guards the website's blog: it strips the HTML from each post page and confirms its words, links, and images match the author's Markdown in `docs/blog/` exactly. See [The blog](#the-blog) below.

`scripts/check-site.py` audits every page in `website/`: one h1 and no skipped heading levels, `lang`, a canonical URL that matches the page's path, Open Graph and Twitter tags, alt text and dimensions on every image, links and `#anchors` that resolve, JSON-LD that parses, `softwareVersion` matching `Info.plist`, and a `sitemap.xml` that lists every indexable page. When you bump the app version, update `softwareVersion` in the JSON-LD in `website/index.html`; when you change a page, update its `lastmod` in `sitemap.xml`.

`scripts/check-document-types.py` reads `Info.plist` and fails if Sable stops being an `Alternate` handler for Markdown and plain text, if the two are no longer separate document types, or if a Markdown extension (`md`, `markdown`, `mdown`, `mkd`, `mkdn`, `mdwn`) goes missing. Making Sable the default is the user's choice in Settings, never something the app's registration claims.

`scripts/check-release-config.py` and `scripts/check-appcast.py` run only as part of an actual release (`.github/workflows/release.yml`); they need release-only environment variables and aren't part of the regular check suite. `scripts/verify-update.swift` is invoked by `check-appcast.py`, not run directly.

`scripts/check-updater.swift` (a check that an unconfigured `AppUpdater` stays inactive) isn't currently wired into CI or the README. `AppUpdater` links Sparkle, so this check needs the same release-build/link approach as the checks above rather than a plain `swiftc` invocation. If you touch update-check logic, work out the right compile line for it and add it to `check.yml` alongside your change.

## Accessibility

Sable aims to work with VoiceOver, with the keyboard alone, and with Increase Contrast, Reduce Transparency, and Reduce Motion. The conventions:

- **Name everything.** Give every icon-only button an `accessibilityLabel` that says what it does, and a hint where the label alone isn't enough. A control that switches something on and off reports On or Off as its value (`BarButton(toggles:)`); one that just acts doesn't. Hide purely decorative images with `accessibilityHidden(true)`.
- **Group what belongs together.** A row in the desk, a chapter, a card, and a timeline point are each one element with a label, a value for its state, and traits. Wrap related controls in `accessibilityElement(children: .contain)` with a label.
- **Nothing hover-only.** Controls that appear only under the pointer need the same thing as an `accessibilityAction`, and anything you can drag needs a keyboard or action equivalent (see the Customize Tools sheet, the Manuscript tab, and cards).
- **Every sheet and popover closes with Escape** (a `.cancelAction` button or `.onExitCommand`) and puts focus somewhere sensible when it opens.
- **Respect the display settings.** Use `quietAnimation(_:value:)` and `withQuietAnimation` instead of `animation` and `withAnimation`, `panelFill(in:)` and `panelOutline(_:)` instead of a bare material, and read `colorSchemeContrast`, `accessibilityReduceTransparency`, and `accessibilityReduceMotion` from the environment. `AccessibilitySupport.swift` has these helpers.
- **Colors come from `ThemePalette`, and `check-contrast.swift` must pass.** Don't use `tertiaryLabelColor` or other system grays for text on the writing page; they ignore the theme.
- **Say what changed when nothing else will.** `Announce.say(_:)` speaks a short message to VoiceOver (a chapter moved, a mode switched). Pure strings that a screen reader will read, such as the Story Timeline's, live in the model files so a check can cover them.

The interface can't be tested for VoiceOver by a script, so a person checks it by hand before a release. This is the short version of that pass.

### Manual VoiceOver test

Build and open the app (quit any older copy first), choose Help → Open Sample Project, and turn VoiceOver on with ⌘F5. Move with Control-Option and the arrow keys (VO-Right and VO-Left). Write down anything that is unnamed, read twice, read in the wrong order, or doesn't match what's on screen.

1. **Window order.** VO-Right through the window. Expect the writing desk (tabs, options, search, files), then the toolbar, the writing page, the scene tags, and the status bar, with the cards last. The toolbar should be in view even though auto-hide is on.
2. **Toolbar.** Writing desk, Paragraph focus, Prose suggestions, Spelling & grammar, and Highlight names read "On" or "Off" and change when pressed (VO-Space). Bold, Link, and Export read no state. The **Toolbar options** button opens a popover you can leave with Escape.
3. **Writing desk.** On a folder: "name, folder, collapsed", and VO-Space expands it. Open the Actions rotor on a file in the Characters folder and expect Show as card, Open beside current document, Rename, Pin to top, and Move to Trash (don't trash anything). In the Manuscript tab a chapter reads "Chapter 2: title", its word count and position, and offers Move up and Move down. With the row focused, ⌥↓ moves it and VoiceOver says its new position.
4. **Cards.** Show a character as a card. It reads as a group named "Character card: name". Its actions include Pin or Unpin, Move to each other corner, and Make card larger or smaller; the **Card size** control adjusts with VO-Up and VO-Down. Unpin it, move away, then activate the collapsed card: it opens and stays open.
5. **Scene tags.** The chips read "Character: name" or "Location: name", and a tag with no card says so. **Tag this scene** opens a list whose items read "name, in this scene" or "not in this scene", and toggle when pressed.
6. **Story Timeline** (⌥⌘Y). The chart reads "Story arc" with a summary of its headings and beats. Each point reads like "Chapter 3, Midpoint, point 3 of 6, medium tension"; pressing it closes the timeline and jumps to that heading. Escape closes it.
7. **Writing record** (Settings → General). The chart reads a title and summary first ("Today: … Last 30 days: …"), and its audio graph plays the days as a tone. The goal chart (turn on a goal) reads its own summary.
8. **Sheets.** *Export* (⇧⌘E): fields are named, each chapter reads as a checkbox with its words, errors are spoken, Escape cancels. *Revisions* (⌥⌘R): snapshots read their name, kind, date, and words; files read "Changed, 40 words added"; the changes text starts with a summary of words added and removed. *Find & Replace* (⌥⇧⌘F): focus lands in Find, the number of matches is spoken as you type, each match reads "Line 12: …", and Escape closes it.
9. **Customize Tools** (Toolbar options → Customize Tools…). Select a tool in "Tools on your toolbar" and press ⌥↑ or ⌥↓: it moves and VoiceOver says "moved to position 3 of 9". Each row also offers Move up and Move down; each available tool offers Add to toolbar.
10. **Writing Style** (⌥⌘,). Sliders read their name and a spoken value ("Font size, 19 points") and adjust with VO-Up and VO-Down. Each theme reads its name, "Dark theme" or "Light theme", and "selected" on the current one.
11. **Keyboard only.** Turn VoiceOver off and turn on System Settings → Keyboard → Keyboard navigation. Tab reaches the toolbar, the desk, and each sheet's controls; Escape closes every sheet and popover, including the first-launch folder sheet ("Not Now").
12. **Display settings.** Turn on each in System Settings → Accessibility → Display and look at the writing page, a card, and the toolbar. *Increase Contrast*: dimmed symbols and paragraph focus are clearly brighter, outlines are firmer, and the page is flat. *Reduce Transparency*: the toolbar, cards, and scene tags are solid. *Reduce Motion*: nothing slides or fades, and there are no particles or name shimmer.

## Preview build

`sh scripts/build-preview.sh` builds a separate **Sable Markdown Writer Preview.app** with its own preferences and copied sample documents (`QUILL_PREVIEW`), so you can exercise first-run UI without disturbing your own writing folder or closing an existing draft.

## Branch and PR flow

1. Branch from `main`.
2. Make your change, adding or updating the relevant `scripts/check-*.swift` (and its compile-list entries above and in `.github/workflows/check.yml`) alongside it.
3. Run `sh scripts/build-app.sh` and the checks that cover the area you touched, at minimum.
4. Open a pull request against `main`. `.github/workflows/check.yml` runs the full build and check suite on every push and pull request; it must pass before merging.
5. Keep PRs focused — one change per PR makes review and rollback easier.

Releases (version bumps, signing, and publishing to GitHub Releases) are cut separately by a maintainer through `.github/workflows/release.yml`; contributors don't need to touch that workflow.

## The blog

Blog posts are the maintainer's own writing, so the Markdown files in `docs/blog/` are the source of truth and are never edited to fit the site. `docs/blog/posts.json` lists the posts (`slug`, `date`, and optionally `modified` and `description`). To publish one:

1. Save the post as `docs/blog/<slug>.md`, starting with a `# Title` heading. Put any images next to it, each with alt text.
2. Add its entry to `docs/blog/posts.json`.
3. Run `python3 scripts/build-blog.py`. It writes the post page (with its BlogPosting and breadcrumb JSON-LD), the blog index, `website/blog/feed.xml`, and the blog entries in `website/sitemap.xml`, and refuses to build a post with an image that has no alt text.
4. Run `python3 scripts/check-blog.py` (CI does too). It fails if a page's words differ from the Markdown or if the committed pages are stale.

Step 3 also refreshes the "From the blog" list on the home page (the three newest posts, between the `blog-list` markers in `website/index.html`), the feed, and the sitemap.

Both scripts use only the Python standard library.
