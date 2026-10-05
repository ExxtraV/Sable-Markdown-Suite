# Welcome to Sable Markdown Writer

_This guide is written by Claude Code._

Your words live in ordinary Markdown files. They are plain text, so you can open them in other editors and keep them in a folder you control.

## Your writing folder

A writing folder is optional (see [Just open a file](#just-open-a-file) below). If you want one, choose it during setup. We recommend iCloud Drive, Dropbox, or OneDrive for access across devices. Your cloud service handles synchronization; let it finish before editing the same file on another device.

The writing desk has two tabs: **Files** and your **Outline**. Click a file to open it in the same window (full screen stays on); Sable asks you to save or discard unsaved changes first.

- **Create:** the **+** above the list makes a new Markdown file or folder. Hover a folder and a small **+** appears beside it: click it and choose **New Markdown File** or **New Folder** to create inside that folder. Control-click a folder offers the same. A new folder opens its parent and waits with its name ready to type. Press Return to keep the name or Esc to keep “Untitled Folder”. If the name is already taken, Sable says so and leaves the folder as it was. Folders can go inside folders as deep as you like, in plain writing folders and in Fiction Projects.
- **Rearrange:** drag files and folders onto folders to nest them. Drop on the path above the list to move things back up.
- **Rename and trash:** Control-click for Rename and Move to Trash, with an Undo shortcut just after trashing. You can rename or move a file while it's open, on the page, beside your draft, or as a card. It stays open under its new name, and the next save goes there. The same happens when you rename or move it in Finder.
- **Colors and pins:** give any file or folder a color or pin it to the top. Name your colors (Draft, Revised…) in the list options. Chips above the list filter by color or pin.
- **Focus:** Control-click a folder and choose Focus on This Folder to see only that folder. The path above the list takes you back out.
- **Search:** the search box looks through every folder beneath the one you're viewing, not only the ones that are open.
- **Keyboard:** arrow keys move through the list, → and ← open and close folders, Return opens, ⇧Return renames, ⌘Delete moves to the Trash.
- **Recent tab (optional):** off until you want it. Turn on **Recent tab** in Settings → General → Writing desk, or in the desk's sliders menu, and a **Recent** tab appears beside Files and Outline. It lists the files you have open, newest first, from any folder; click one to switch to it. Turning it off forgets the list, and **Clear Recent Files** empties it any time. The list is kept only on your Mac and is recorded only while the tab is on.
- **Make it yours:** the sliders button sets sorting, icons, file extensions, last-modified dates, word counts and compact rows. Drag the desk's right edge to resize it.

Choose another folder from the ⋯ menu at any time, or in Settings → General → Writing folder.

## Just open a file

You don't need a writing folder to use Sable. It opens any Markdown file (`.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, `.mdwn`) or plain text file from anywhere on your Mac.

- **Ways to open one:** Finder's Open With → Sable, **File → Open Markdown File…** (⌘O), **File → Open Recent**, dragging a file onto Sable's Dock icon, or dragging it onto the page.
- **First launch:** setup offers **Just Open a File** and **Explore a Sample Project** beside choosing a folder. **Just Open a File** skips the folder, hides the writing desk (⌃⌘S brings it back), and shows the Open panel, and nothing asks you to choose a folder later. **Not Now** (or Escape) closes setup without deciding, and Sable asks again next time. Opening a file from Finder skips setup altogether.
- **With no writing folder,** the writing desk shows the folder of the file you have open. An unsaved document has nothing to show yet. Choose a writing folder, or stop using one, in Settings → General → **Writing folder**. Stopping only makes Sable forget the folder; none of your files are touched.
- **A file outside your writing folder.** The desk keeps showing your writing folder and adds one quiet line saying the file is somewhere else. **Show Folder** shows that folder in the desk for now, with a **Back to** link to return. It lasts only until you go back or quit Sable, and your saved writing folder never changes. Opening a file from your writing folder also brings the desk back by itself.
- **Safe everywhere.** Saving, the notice when an open file is moved to the Trash or deleted, and **Put Back** all work the same for a file from anywhere. Snapshots of a file outside a writing folder live in a hidden `.sable-revisions` folder beside the file, created only when you save a snapshot.

### Make Sable the default for Markdown

Settings → General → **Markdown files** shows which app opens Markdown files now. **Make Sable the Default for Markdown** changes it, and macOS asks you to confirm. Plain text (`.txt`) files are a separate button, also off by default; macOS treats every plain-text file the same way, not only `.txt`. Sable never changes this on its own.

To switch back, select a Markdown file in Finder, choose **File → Get Info**, pick another app under **Open with**, and click **Change All…**. Settings notices the change when you return to Sable.

## Fiction Projects

A **Fiction Project** is a folder that Sable treats as one story world. Every new project opens on a **Start Here** note that explains how it works and how to customize it; bring it back any time from the project's ⋯ menu, which also has a **Concept** note to help you think the story through before you draft. Create a project from the **+** button → **New Fiction Project…**. It sets up **Manuscript**, **Characters**, **Locations**, **World**, **Outline**, **Notes**, and **Images** folders, with an optional sample chapter, character, and location. You can also turn any existing folder into a project: Control-click it and choose **Make Fiction Project…**. Nothing in it is moved or renamed.

- **A sample project to look around in.** First launch offers **Explore a Sample Project**, and **Help → Open Sample Project** opens it any time. It is *Northwatch*: three short chapters with scene tags, four character cards (Mara has aliases and a portrait), two locations, a world note, a Concept note, an Outline tagged for the Story Timeline, a note to yourself, and a snapshot to compare. Sable copies it into your Documents folder as **Sable Sample Project** (with a number added if that name is taken) and opens its first chapter. Your writing folder isn't changed (so setup still comes back next launch until you choose a folder or **Just Open a File**), and the copy inside Sable is never edited. Asking again opens your copy as you left it; to start fresh, move your copy to the Trash first.
- **Projects stand apart.** In a folder that holds projects, the desk lists **Fiction Projects** in their own section, above your ordinary folders and files.
- **Only the project.** Once you're inside a project, the writing desk shows only what's in it. Its header names the project and has a **Leave** button that takes you back to all your files.
- **Manuscript first.** The **Manuscript** folder is always pinned to the top and red by default, since it's where you'll spend the most time. Give it another color from its Control-click menu if you like. Opening a file that belongs to a project brings the desk into that project automatically.
- **Manuscript overview.** Inside a project the desk gains a **Manuscript** tab: your total word count (updating as you type), an optional goal with a progress bar, and every chapter with its own count and a length bar. Drag chapters to rearrange them, or Control-click for Move Up, Down, Top, and End. The order is saved in the project, and your files are never renamed or changed. The Files tab shows the Manuscript folder in the same order, and you can drag chapters there to rearrange them too.
- **Scene tags.** In a chapter, a quiet strip of chips shows the scene's location and characters. Click **Tag this scene** (or press ⌃⌘T) to choose them from your cards, and click a chip to open its card without leaving the page. Chips take the card's color (set it from the card's ⋯ menu → **Color**, or by coloring the file in the desk), which you can turn off in Writing Style. The strip fades while you type, and in paragraph focus it and any collapsed card tabs dim until you point at them. Writing Style moves the strip to a corner or turns it off. Tags are saved at the top of the chapter (`location:`, `characters:`, `world:`), and a name matches a card by file name, title, or `aliases:`.
- **The + buttons.** Point at any folder and a small **+** appears beside it. Click it for a short menu. In the Manuscript, Characters, Locations, or World folder, and folders inside them, the first choice adds the next chapter, or asks for a character, location, or world note's name. Every folder, in a project or not, also offers **New Markdown File** and **New Folder**.
- **Quick creation.** Inside a project, the **+** menu adds a chapter (numbered for you), character, location, or world note from a ready-made template.
- **Planning.** The **Outline** folder holds your own headings — acts, chapters, beats. Tag one in parentheses, like "(Climax)", and it takes its place on the **Story Timeline** (File menu, ⌥⌘Y): Inciting Incident, Rising Action, Midpoint, Climax, Falling Action, or Resolution. Untagged headings spread evenly along the arc, so even a rough outline shows a shape, and clicking a point jumps straight to it.
- **Cards.** Files in Characters, Locations, and World can float over your page as cards while you write. Hover a file and click the card icon, or Control-click → **Show as Card**. Drag a card and it snaps to the nearest corner. Pin it to keep it open, or unpin it to shrink to a small tab that opens when you point at it. Cards update as the file changes. Drag a card's corner grip to make it as large or small as you like (everything inside scales with it); double-click the grip to reset it.
- **Pictures.** Click a card's portrait (or drop an image on the card) to tag a picture. A framing window lets you drag and zoom to crop the portrait, and you can reopen it any time from the card's ⋯ menu with **Adjust Crop…**. Sable copies the picture into **Images** and adds `image:` and `image-crop:` lines to the file. Your original picture is never altered.
- **Just Markdown.** Everything is ordinary Markdown. Card details live in a small block at the top of each file (`type`, `role`, `image`, `tags`), so any other editor can open, read, and edit it all. The only extra is a hidden marker file named `.sable-project.json`.
- **Convert back.** From the project's ⋯ menu choose **Convert to Regular Folder…**. That removes only the marker; every file and folder stays exactly as it is.
- **Names & places.** Character, location, and world names take a color and a soft shimmer as you write: full names, first and last names, file names, and `aliases:`. Turn it on or off in View → Highlight Names & Places, or pick the color in Writing Style. Right-click a highlighted name to open its file or show its card.
- **Export.** On the Manuscript tab press **Export…** (⇧⌘E) to make one PDF, EPUB, Word, or Markdown file from your chapters, in your order. Choose the chapters and a Manuscript or Book look, then adjust the look under **Layout**: headings left or centered, a title page (on or off, left or centered), the font and size, single, 1.5, or double line spacing, margins, and page numbers and a running header. PDF and Word follow every choice; EPUB takes the heading and title page alignment. Picking a look again, or **Reset**, starts over from it. A project remembers its layout. File → Export This Document… exports only the open page, and remembers its own layout for the next document.

## Coming from Scrivener

**File → Import Scrivener Project…** turns a Scrivener 3 project into a new Fiction Project. Choose the project (its name ends in .scriv) and Sable shows what it found before writing anything: how many scenes, chapters, characters, locations, and notes, and anything that can't become Markdown.

- **You choose where each part goes.** Every top-level item in the binder has a menu: Manuscript, Characters, Locations, World, Notes, or Don't Import. Sable suggests the manuscript folder for Manuscript, character and location sheets for cards, Research for Notes, and leaves out the Trash and Scrivener's blank template sheets. If your project holds more than one book, send each extra book's folder wherever suits you.
- **A folder of scenes becomes one chapter file.** Scenes are divided by a scene break, in binder order. Each scene's title, synopsis, status, label, keywords, and document notes sit above it as a note to yourself (`<!-- like this -->`), which Reading Mode and exports leave out. Those notes do count toward the chapter's word count.
- **Italics, bold, and scene breaks carry over.** Fonts, colors, and spacing are left behind. A chapter's own synopsis, status, label, and keywords go at the top of its file, between the `---` lines.
- **Pictures, PDFs, and saved web pages are copied as they are**, pictures into Images and the rest into Notes. Pictures pasted into the middle of a document's text can't come along. **Import Report.md**, in the new project, lists every one.
- **Your Scrivener project is never changed.** Sable only reads it, and writes a new folder where you choose.

Projects last saved by Scrivener 2 can't be read yet; opening one in Scrivener 3 updates it.

## A little Markdown

Use **two asterisks for bold**, *one for italics*, and [a link label](https://www.markdownguide.org). Start a line with # for a heading, or ## for a smaller heading.

- A dash starts a list item.
- A blank line starts a new paragraph.

> A greater-than sign starts a quotation.

Use `backticks` for inline code and ~~two tildes~~ for a strikethrough.

## Markdown helpers

- **Lists:** press Return to continue a list, Return on an empty item to end it, and Tab or Shift-Tab to indent or outdent. ⇧⌘8 makes a bulleted list, ⇧⌘7 a numbered one, and ⇧⌘9 a task list.
- **Headings:** ⇧⌘H cycles the line through #, ##, ###, and plain. **Scene break:** ⇧⌘L. **Strikethrough** ⇧⌘X, **inline code** ⇧⌘K.
- **Notes to yourself:** `<!-- like this -->` is dimmed while you write, hidden in Reading Mode, and left out of exports.
- **Find & Replace in Project** (⌥⇧⌘F) searches every Markdown file, shows what will change, and can undo the replacement.
- **Import Document…** in the File menu converts a Word, RTF, or HTML file into Markdown, and **Paste as Markdown** (⌃⌘V) does the same for whatever you copied.
- Settings → Writing can turn on curly quotes and dashes as you type. The Help menu has a Markdown cheat sheet.

## Revisions

Before a big rewrite, save a snapshot: **File → Save Snapshot** (⌥⌘S), or the Revisions button at the bottom of the writing desk. A snapshot keeps a copy of every chapter as it is right now. **Revision History** (⌥⌘R) lists your snapshots and shows, for any of them, which chapters changed and how: words you have added are underlined green and words you have removed are struck through red. From there you can restore one chapter or the whole draft. Sable saves a safety snapshot before every restore, so a restore can be undone too. In a Fiction Project it also keeps a daily snapshot when something changed (turn that off in Settings). Snapshots live in a hidden `.sable-revisions` folder as ordinary Markdown files. For a file opened from outside a writing folder, that folder sits beside the file, and only a snapshot you save creates it.

## How Sable protects your files

- **All or nothing.** When Sable rewrites a file, it writes the new version beside the old one and swaps them in a single step. If the disk fills up or your Mac stops halfway, the old file is still whole.
- **Files from anywhere.** These protections follow the open file itself, not a folder. A file opened from Finder is saved, noticed in the Trash, and put back the same way as one in your writing folder.
- **A snapshot before big changes.** Find & Replace in Project and every restore save a safety snapshot first. If that snapshot can't be saved, nothing is changed.
- **Undo that won't erase newer words.** Undo Replace puts back only files that still read exactly as the replacement left them. Anything you changed afterwards is left alone, and Sable tells you which files those were.
- **Files open beside your draft.** When Find & Replace or a restore touches a file that's open beside your draft, that file saves your latest words first and then shows the new text. If the file changes somewhere else (another app, or another Mac through iCloud or Dropbox) while you have edits beside your draft, Sable doesn't save over it. Choose **Keep Mine** or **Use Saved File**; the version you don't keep goes to the Trash as a copy.
- **Exports never replace your writing.** An export can't be saved over the files it was made from, over a file that's open in Sable, or inside the Manuscript folder. If it replaces some other file, that file goes to the Trash as a copy first.
- **If an open file is trashed or deleted.** Renaming or moving an open file, in Sable or in Finder, just carries it along. When a file you have open is moved to the Trash or deleted outside Sable, a note appears under the page or in the side pane. For a trashed file, **Put Back** returns it to its folder. For a deleted one, **Save Again** writes it back where it was. **Save As…** keeps it somewhere else. Without one of these, Sable keeps saving a trashed file into the Trash, where emptying the Trash would delete it. The writing desk won't move a file to the Trash while it's open in another window.
- **Nothing is deleted outright.** Move to Trash sends files to the macOS Trash, with Undo right afterward. Import always makes a new file. The only things Sable deletes are snapshots: when you delete one, and daily snapshots older than the latest 20.
- **Files that aren't downloaded yet.** If iCloud is set to Optimize Mac Storage and a file hasn't been downloaded, Sable downloads it when it's opened, searched, or saved in a snapshot. While you're offline it can't be read: Sable shows an error and leaves the file alone, and Revision History may list it as deleted. Restores stop until it can be read.

## Your writing record

Settings → General charts the words you've added each day for the last 30 days, with your best day and a lifetime total. It only counts progress you keep — deleting words never counts against you — and it isn't a streak, so a quiet day changes nothing. It's kept only on this Mac, and you can clear it any time.

## A goal with a deadline

This is optional, and it's off until you want it. For a challenge like 50,000 words in November, turn on **Track a goal with a deadline** in Settings → General, just above your writing record. Until you do, nothing about goals appears in Settings or while you write; turn it off again any time, and a goal you set earlier is kept for next time. Then choose **November: 50,000 words**, or **Custom…** to pick your own word count, start date, and end date (up to a year). Only one goal is active at a time.

Once it's set, Settings shows:

- **So far:** the words you've written on the goal's days.
- **Pace today:** where an even pace, the same number of words every day, would have you at the end of today. The chart draws it as a dashed line beside your own.
- **Today's target:** what today needs to be for the goal to finish on time, spreading what's left evenly over the days left. If you've written less than an even pace, the sentence above the chart simply says what finishes on time, such as "1,900 a day finishes on time." If you're ahead, it says you're on pace. Today's target is worked out from the words you wrote before today, so it holds steady while you write.
- **Days left,** counting today and the goal's last day.

Like the writing record, it only counts words you add. Deleting words never subtracts from it, and there are no streaks, badges, or notifications. Words you write on the start date all count, even the ones you wrote before you set the goal that day. Goals are measured in calendar days, so a clock change or a trip to another time zone doesn't shift them.

Turn on **Show today's share in the footer** to see a small "1,204 / 1,667 today" beside the session goal while you write. It's off by default, and it only appears while the goal is running.

**Clear Goal** removes the goal and keeps your writing record. Clearing the record keeps your goal. Both are kept only on this Mac.

## Updates

Sable checks for updates while it's open: every day, every 3 days, or every week, as you choose in Settings → General, where you can also turn automatic checks off. **Check for Updates…** in the Sable Markdown Writer menu checks right away. Either way, you choose when to install and restart. **Get beta updates**, off by default, also offers early builds published ahead of a stable release; they may be rougher. If you turn it off again, you keep the build you have until a newer stable release arrives.

## Reporting a problem, or sharing an idea

**Help → Report a Bug…** opens a small window with two boxes, *What happened?* and *Steps to reproduce*. A checkbox, on by default, adds your Sable version, macOS version, and Mac model to the report; the exact values are shown beneath it, so you can see what would be included. **Open in GitHub** then opens your browser to a bug report with your words already filled in. Nothing is sent from Sable: you read the report on GitHub and decide whether to submit it, which needs a free GitHub account. If your text is too long to fit in a link, the end is cut with a note, and you can paste the rest on GitHub.

If Sable has closed unexpectedly in the last seven days, the window also offers **Show Latest Crash Report**. Sable doesn't open that report until you click. Then it shows it in the window, where you can read it and copy it into the GitHub report yourself. It can include file paths on your Mac, and nothing is attached for you.

**Help → Send Feedback or Ideas** opens the Ideas category of Sable's GitHub Discussions in your browser.

## Your toolbar

The toolbar starts with only the essentials. Click **⋯ → Customize Tools** to add the tools you use (headings, bold, italic, lists, quotes, scene breaks, revisions, and more) and drag them into the order you like. Dark themes shade toward the page edges to keep your eye on the text; Writing Style lets you turn that off or change how deep it is.

## Keep your hands on the story

- Command-N: new document.
- Command-O: open a file.
- Command-S: save.
- Command-B / Command-I / Command-K: bold, italic, link.
- Command-Shift-H: heading.
- Tab or Escape: move past closing formatting markers.
- Command-Backslash: leave formatting.
- Return: leave formatting and start a new line.
- Command-F: find in the manuscript.
- Command-Shift-F: focus on the current paragraph.
- Command-Shift-R: switch between writing and reading mode.
- Command-Control-S: show or hide the writing desk.
- Command-Option-Comma: fonts, themes, and writing style.
- Command-Option-J: sentence-structure colors.
- Command-Plus (the = key) / Command-Minus: zoom in or out.
- Command-0: reset zoom to 100%.

Pinch the trackpad to zoom. You can turn this off in Writing Style. With a mouse, hold ⌘ and turn the scroll wheel: away from you zooms in, toward you zooms out, 5% per notch. A two-finger horizontal swipe shows or hides the writing desk. Zoom changes the display, not your Markdown.

## A quiet writing space

Try Graphite, Midnight, Chalk, Forest, Obsidian, Arcane, Starfall, Parchment, Paper, or Mist in Writing Style. Obsidian is nearly black, for a room with the lights all the way down. Arcane is a dark purple for fantasy writing, with faint particles of light drifting up behind the text. Starfall is a deep blue with faint frost-colored particles falling slowly. Each has its own switch for the particles, which are off whenever Reduce Motion is on. Mist is a cool grey-blue light theme, for when Paper is too stark and Parchment too warm. Every dark theme shades toward the page's edges so your eye settles on the middle; Graphite, Midnight, Chalk, Obsidian, Arcane, and Starfall also darken the bar at the bottom. Pick one of five writing fonts or choose your own. The toolbar slides in when you move the pointer near its edge and never shifts your page. Put it on the top, left or right, keep it visible, or turn it off entirely with ⌥⌘T. Rest the pointer on any tool to see its name and what it does; the writing desk can be shown or hidden with its shortcut or a two-finger horizontal swipe.

**Scrolling** in Writing Style lets you scroll past the end of your text so the line you're writing can sit in the middle of the window, or, in its third setting, keeps that line centered for you as you type. Paragraph Focus fades the text above and below the paragraph you're writing, a little more with each line of distance. In Writing Style you can switch it to dim everything evenly. Reading Mode hides Markdown marks. Prose suggestions cross out possible cuts only on screen. Sentence Structure colors nouns, verbs, and other word classes on your Mac; invented names can be misclassified. None of these display features changes your saved text.

## A second file beside your draft

Control-click any Markdown file in the writing desk and choose **Open Beside Current Document**. It opens as a formatted reading view next to your draft. Each side scrolls and zooms on its own: pinch, use ⌘+ and ⌘−, or ⌘-scroll a mouse wheel, with the pointer over the one you want to scale. Choose Edit to work on it in place, then Read to return to the clean view. This stays within one focused document window: Sable does not use writing tabs.

## VoiceOver, the keyboard, and your display settings

Sable works with VoiceOver, with the keyboard alone, and with the display options in System Settings → Accessibility.

**VoiceOver.** Every button, field, and sheet has a name, and VoiceOver reads a short hint for what it does. Toolbar tools you switch on and off (Writing desk, Paragraph focus, Prose suggestions, Spelling & grammar, Highlight names) say whether they are On or Off; the rest just act. In the writing desk each file, chapter, and heading is one item that says what it is and its state, such as "folder, collapsed" or "open for writing". The buttons that otherwise appear only when the pointer hovers (Show as card, Open beside current document, adding to a folder, Rename, Pin, Move to Trash) are VoiceOver actions on the item: open the Actions rotor and choose one. Cards are named groups with actions to pin, close, move to another corner, and resize; a collapsed card opens and stays open when you activate it. On the Story Timeline each point is a button read as its heading and beat, like "Chapter 3, Midpoint", and the writing record in Settings has a spoken summary and an audio graph.

**The keyboard.** Every toolbar action is also in the menus. To Tab between buttons and fields, turn on **Keyboard navigation** in System Settings → Keyboard. Escape closes every sheet and popover. In **Customize Tools**, select a tool and press ⌥↑ or ⌥↓ to move it, and ⌘Return to add the selected tool; the Move Up and Move Down buttons do the same. In the Manuscript tab, ↑ and ↓ move between chapters, Return opens one, and ⌥↑ or ⌥↓ moves it. In a card's picture frame, the arrow keys reposition the picture. In the writing desk's file list, use the arrow keys to move, Return to open, and ⇧Return to rename.

**Staying reachable.** When VoiceOver or Keyboard navigation is on, the toolbar stays in view instead of hiding until the pointer comes near, and the page makes room for it.

**Display settings.** *Increase Contrast* brightens the dimmed text (Markdown symbols, quotes, notes, and paragraph focus), uses stronger name and sentence colors, firms up the outlines of cards and the toolbar, and gives you a flat page with no edge shading or drifting particles. *Reduce Transparency* makes the toolbar, cards, and scene tags solid instead of frosted, with the same flat page. *Reduce Motion* turns off the sliding and fading animations, the drifting particles, and the shimmer on names. Without any of them, every theme's text, dimmed symbols, and highlight colors are kept at or above the WCAG contrast ratios, and the check that guards this runs with every change to Sable.

## What comes next

Sable is a focused Markdown editor first, with Fiction Projects for writers who want one home for a whole story. A corkboard, a relationships view, and an iPad edition are on the roadmap.

You can edit this guide freely. Help → Sable Guide opens it again without overwriting your changes.
