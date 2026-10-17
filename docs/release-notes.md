Sable Markdown Writer 1.0.0-beta.4 is the fourth beta on the way to 1.0. Notes to yourself no longer count as words, Scrivener footnotes and comments now come across with the rest of the book, and a chapter opened from a menu starts at its top. Betas go only to people who turned on **Get beta updates** in Settings → General; everyone else stays on 0.10.1 until a stable release.

- **Notes to yourself don't count as words.** Text inside `<!-- -->` was already hidden in Reading Mode and left out of exports, but it was still counted, so a chapter with notes read longer than it was. Now every count leaves notes out: the footer, a selection, the desk, the Manuscript tab and its goal, the writing record, a deadline goal, the Export sheet, and snapshots. Typing inside a note no longer adds to today's words. **If you keep notes in your chapters, your counts will go down by the words in them.** A book imported from Scrivener, which keeps each scene's synopsis and notes this way, now counts only its scenes.
- **Every count agrees.** The footer used to count the front matter between the `---` lines and marks such as `#` and `* * *` as words, so it never quite matched the Manuscript tab. Now all counts follow one rule, and the footer for a file with front matter or headings drops slightly to match.
- **Scrivener footnotes, comments, and annotations come across.** A Scrivener footnote, inline or from the inspector, becomes a Markdown footnote: a mark like `[^1]` where it was and its words at the end of the chapter file, numbered from 1 in each chapter, with italics kept. A comment or an inline annotation becomes a note to yourself at the same spot. The import preview and **Import Report.md** say how many there were. Projects imported with beta.3 aren't changed; import again to pick these up.

**Fixed**

- With typewriter scrolling set to centre, a chapter opened from a menu (after importing a Scrivener project, opening the sample project, or **File → Open Fiction Project…**) could appear scrolled to its last lines. It now opens at its top. A change made outside the editor, such as Find & Replace or scene tags, also leaves the page where it was.

**Good to know**

- Days already in your writing record keep their numbers, and so do the word totals in snapshots you saved before this beta. Comparing a file with an older snapshot can show a small drop that is only the new counting rule.
- Reading Mode and exports don't lay footnotes out yet; they show the `[^1]` marks and the footnote text as typed.
- A correction to the beta.3 notes: they said the import report would tell you when Scrivener footnotes, comments, or annotations came through as stray marks. That warning never fired. In this beta those are converted, and the report lists any it couldn't convert.
- Scrivener 2 projects are still read from public descriptions of that older format and are less tested. The import report says so, and it's worth comparing the result against the original.

_Release notes written by Claude Code._
