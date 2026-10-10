Sable Markdown Writer 1.0.0-beta.3 is the third beta on the way to 1.0. It brings your Scrivener projects into Sable, opens a Fiction Project from anywhere on your Mac, adds two writing themes, and keeps your place when you switch between Reading Mode and editing. Betas go only to people who turned on **Get beta updates** in Settings → General; everyone else stays on 0.10.1 until a stable release.

- **Bring a book over from Scrivener.** **File → Import Scrivener Project…** reads a Scrivener 3 or Scrivener 2 project (`.scriv`) and makes a new Fiction Project from it. Before anything is written, a preview shows what was found ("42 scenes in 12 chapters, 9 characters, 3 locations") and lets you choose where each top-level binder item goes: Manuscript, Characters, Locations, World, Notes, or Don't Import. Each chapter folder becomes one chapter file, its scenes divided by `* * *` in binder order. Character and location sheets become cards. Synopses, statuses, labels, and keywords are kept at the top of each file, and document notes are kept as notes in the text, which Reading Mode and exports leave out. Sable only reads the Scrivener project and never changes it.
- **What can't become Markdown is copied, and listed.** Pictures go to Images, and PDFs, web pages, and other files go to Notes, as they are. **Import Report.md** in the new project lists them, along with anything missing, unreadable, or left out. Pictures pasted into a document's text stay behind in the Scrivener project.
- **Open a Fiction Project from anywhere.** **File → Open Fiction Project…** (⇧⌘O) opens a project that lives outside your writing folder. The desk shows it for the session, your saved writing folder doesn't change, and **Back to** it is one click away. A folder that isn't a project yet can become one on the way in; nothing in it is moved or changed.
- **Recent Projects.** The desk's Files tab has a **Recent Projects** section under the file list, with the last eight Fiction Projects you opened, wherever they live. It stays folded until you click it. **File → Open Recent Project** shows the same list.
- **Export from another folder.** In a Fiction Project's Export sheet, a menu beside **Chapters** chooses where the chapters come from: Manuscript, as before, or another folder of the project, for a second book or an older draft.
- **Two new writing themes: Starfall and Mist.** Starfall is a deep-blue dark theme with faint motes that fall slowly; they have their own switch and stop under Reduce Motion. Mist is a cool grey-blue light theme. Both are in Writing Style.

**Fixed**

- Switching between Reading Mode and editing lost your place, sometimes by several paragraphs. The paragraph at the top of the window now stays at the top in both directions, in the manuscript and in the parallel pane. Your caret stays where it was unless you click on the reading page.

**Good to know**

- Words in the notes the Scrivener import keeps above each scene are counted in word counts for now, so an imported book can read a little longer than it is.
- Scrivener footnotes, comments, and inline annotations can come through as stray marks; the import report says when a document has them.
- Scrivener 2 projects are read from public descriptions of that older format and are less tested. The import report says so, and it's worth comparing the result against the original.

_Release notes written by Claude Code._
