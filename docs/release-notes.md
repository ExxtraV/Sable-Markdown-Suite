Sable Markdown Writer 0.10.1 gives Sable its new sleeping-curl icon, keeps a file open when you rename or move it, and lets you make folders inside folders without leaving the writing desk.

- **A new icon.** The Dock, Finder, and About panel now show the sable asleep, curled nose to tail, matching the website. It's sized to macOS's icon grid, so it sits at the same size as your other apps, and the small versions in lists use a simpler black-and-white mark so the curl stays readable. macOS remembers old icons; if the previous one lingers, quit Sable and run `killall Dock Finder` in Terminal.
- **Rename or move an open file, and it stays open.** In the writing desk, renaming or moving a file that's open on the page, beside your draft, or as a card now carries it along, and your next save goes to the new name. Renames and moves you make in Finder are followed the same way. Before, Sable said the file had been deleted. The note still appears when a file really is deleted or moved to the Trash.
- **New folders, at any depth.** Hover a folder in the writing desk and click its **+**. It's now a small menu with **New Markdown File** and **New Folder**, and a folder that holds chapters, characters, or the like lists its own kind of item first. A new folder appears as "Untitled Folder" with its name ready to type, as in Finder. If the name you type is already taken, Sable says so and leaves the folder as it was. Control-clicking a folder, including a Fiction Project, offers **New Folder** too. While you're searching or filtering there's no list to type a name in, so Sable asks in a small window instead.
- **Drag from anywhere on a row.** In the writing desk's file list and the Manuscript tab, pressing anywhere on a row (icon, name, padding, or word count) now starts a drag. Before, only part of a row did.
- **Updates come from Sable's new GitHub address.** Sable's home on GitHub is now ExxtraV/Sable-Markdown-Suite, and this version checks for updates there. Earlier versions reach it automatically, so there's nothing to do.

**Fixed**

- A file you had switched to in the writing desk lost track of itself when renamed, and could follow a file you'd had open before if that one was moved, so your next save could go to the wrong file.
- Double-clicking a folder opened it and then closed it again. Now it opens.
- Renaming or moving the file open beside your draft is no longer blocked.

_Release notes written by Claude Code._
