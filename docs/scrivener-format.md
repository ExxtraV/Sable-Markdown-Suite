# The Scrivener project format, as Sable reads it

_This document is written by Claude Code._

Scrivener's project format is not published. This is what Sable's reader
(`Sources/Quill/ScrivenerReader.swift`) relies on, and how sure we are of each part. Every statement
carries one of three marks:

- **Confirmed**: seen in real projects saved by Scrivener 3.5.2 for Mac (`Creator="SCRMAC-3.5.2-17487"`,
  binder `Version="2.0"`, `Files/version.txt` containing `23`). Four projects were read, between 33 and
  329 binder items each.
- **Assumed**: taken from public descriptions of the format or from its evident pattern, but never
  seen in a real file. The reader copes if the assumption is wrong; it just reads nothing for that part.
- **Not seen**: known to exist, absent from every project examined, and not read.

Those real projects are private. Nothing from them is in this repository: the fixtures in
`Tests/Fixtures/Scrivener` were written by hand with invented text, copying only the structure.

Sable only ever reads a Scrivener project. It never writes into one.

Most of this document is about the Scrivener 3 format. Scrivener 2's older layout has its own section near the end.

## The package

A project is a folder whose name ends in `.scriv`, shown by Finder as a single file.

| Path | What it is | Mark |
| --- | --- | --- |
| `<Name>.scrivx` | The binder: one XML file listing every item, in order | Confirmed |
| `Files/Data/<UUID>/` | One folder per binder item that has any content | Confirmed |
| `Files/Data/<UUID>/content.rtf` | The document's text | Confirmed |
| `Files/Data/<UUID>/synopsis.txt` | The index-card synopsis, plain UTF-8 | Confirmed |
| `Files/Data/<UUID>/notes.rtf` | The inspector's document notes | Confirmed |
| `Files/Data/<UUID>/content.<ext>` | The file behind a picture, PDF, web archive, or other item | Confirmed |
| `Files/Data/<UUID>/card-image.<ext>` | A picture pinned to the index card | Confirmed |
| `Files/Data/<UUID>/content.styles`, `notes.styles` | Which named styles the text uses. Not read | Confirmed to exist |
| `Files/Data/<UUID>/content.comments` | Inspector comments and footnotes | Not seen |
| `Files/Data/docs.checksum` | A checksum per file. Not read | Confirmed to exist |
| `Files/version.txt` | A format number (`23`). Not read; the binder's own `Version` is used | Confirmed |
| `Files/styles.xml` | The project's named styles, each an RTF sample. Not read | Confirmed to exist |
| `Files/search.indexes` | A plain-text copy of every document, for Scrivener's search. Not read | Confirmed to exist |
| `Files/binder.backup`, `binder.autosave`, `writing.history`, `ProjectNotes/` | Not read | Confirmed to exist |
| `Settings/`, `QuickLook/`, `Icons/` | Window layout, compile formats, previews, custom icons. Not read | Confirmed to exist |
| `Snapshots/` | Earlier versions of documents. The folder was present but empty | Not seen |
| `Mobile/` | Changes waiting to sync from Scrivener for iOS | Not seen |

The package's name and the `.scrivx` file's name normally match. The reader prefers the matching
`.scrivx` and otherwise takes the first one it finds. (Assumed: no real project had two.)

Things the real projects showed that a tidy description would not:

- **Many items have no folder in `Files/Data` at all**: the three root folders, empty folders, and
  documents nobody has typed into. Between 0 and 6 items per project. That is normal, not damage.
- A folder never appeared in `Files/Data` without a matching binder item.
- An item's folder can hold any mix of the files above, including a synopsis with no text.

## The binder file

```xml
<ScrivenerProject Identifier="…" Version="2.0" Creator="SCRMAC-3.5.2-17487" Device="…" Author="" Modified="…" ModID="…">
    <Binder>
        <BinderItem UUID="…" Type="DraftFolder" Created="2018-11-06 10:50:52 -0500" Modified="…">
            <Title>…</Title>
            <MetaData>
                <IncludeInCompile>Yes</IncludeInCompile>
                <IconFileName>Characters (Character Sheet)</IconFileName>
                <LabelID>7</LabelID>
                <StatusID>2</StatusID>
                <SectionType>EA9C9DBA-…</SectionType>
                <FileExtension>png</FileExtension>
                <IndexCardImageFileExtension>png</IndexCardImageFileExtension>
            </MetaData>
            <TextSettings>…</TextSettings>
            <Children>
                <BinderItem …>…</BinderItem>
            </Children>
        </BinderItem>
    </Binder>
    <Collections>…</Collections>
    <SectionTypes><TypeDefinitions><Type ID="…">Scene</Type>…</TypeDefinitions>…</SectionTypes>
    <LabelSettings><Title>Label</Title><DefaultLabelID>-1</DefaultLabelID><Labels><Label ID="-1" Color="…">No Label</Label>…</Labels></LabelSettings>
    <StatusSettings><Title>Status</Title><DefaultStatusID>-1</DefaultStatusID><StatusItems><Status ID="-1">No Status</Status>…</StatusItems></StatusSettings>
    <TemplateFolderUUID>…</TemplateFolderUUID>
    <BookmarksFolderUUID>…</BookmarksFolderUUID>
    …
</ScrivenerProject>
```

| Fact | Mark |
| --- | --- |
| The root is `ScrivenerProject`; `Version="2.0"` means the Scrivener 3 format | Confirmed |
| `Binder` holds `BinderItem`s; an item's children are inside its `Children`; the order in the file is the order in the binder | Confirmed |
| `UUID` is 36 characters of hex and hyphens and names the item's folder in `Files/Data` | Confirmed |
| `Type` is one of `DraftFolder`, `ResearchFolder`, `TrashFolder`, `Folder`, `Text`, `Image`, `PDF`, `WebArchive`, `Other` | Confirmed |
| Exactly one each of `DraftFolder`, `ResearchFolder`, `TrashFolder`, all at the top level | Confirmed |
| `Created` and `Modified` look like `2018-11-06 10:50:52 -0500` | Confirmed |
| `LabelID` and `StatusID` point into `LabelSettings` and `StatusSettings`; `-1` means none | Confirmed |
| An item's `SectionType` points into `SectionTypes/TypeDefinitions` by ID | Confirmed |
| `FileExtension` names the item's file, `content.<ext>`; an empty one means a file called just `content` | Confirmed |
| `TemplateFolderUUID` names the folder of blank template sheets | Confirmed |
| Project keywords are `<Keywords><Keyword ID="1"><Title>…</Title></Keyword></Keywords>` at the root, and an item lists `<Keywords><KeywordID>1</KeywordID></Keywords>` | Assumed |
| Custom metadata (`CustomMetaDataSettings`, and `CustomMetaData` inside an item's `MetaData`) | Not seen, not read |
| Other audio and video types (`Type="Media"` or similar) | Not seen; read as `other` |

What the real projects broke:

- **The manuscript is not called "Draft" or "Manuscript".** In three projects of four the writer had
  renamed it to the book's title, and it was never the first item in the binder. Only
  `Type="DraftFolder"` finds it.
- **A project can hold several books.** Ordinary top-level folders beside the Draft held other
  volumes, old drafts, and outlines, often with more text than the Draft itself (the Drafts had 6 to
  21 items; the projects had 33 to 329). An importer that takes only the Draft would leave most of
  the writing behind.
- **`Title` can be missing** (27 items in one project, 3 in another). Scrivener shows these as
  "Untitled". The reader gives them an empty title.
- **`MetaData` can be missing**, and inside it every element is optional.
- **Folders can have text of their own**, and synopses and notes. **Text items can have children.**
  The two kinds differ in their icon, not in what they can hold.
- **Nothing marks a character or location sheet as one.** The best clue is the icon, which the
  template sets and a document made from a template sheet inherits: `Characters (Character Sheet)`
  (89 items across the projects) and `Locations (Location Sheet)` (18). The enclosing folders were
  named "Characters" and "Places", with icons `Characters (Photo)` and `Locations (Map)`. Icons can
  also be custom text, including emoji.
- The label list is the writer's own (one project had 13), so labels have no fixed meaning. The
  status list was Scrivener's default six in every project: To Do, In Progress, First Draft, Revised
  Draft, Final Draft, Done.
- `IncludeInCompile` was `Yes` on nearly every item, research and character sheets included, so it
  says nothing about what belongs in the manuscript.
- A top-level folder named "Recovered Files (date)" appeared in one project, left by Scrivener after a
  sync problem.

## The text

`content.rtf` and `notes.rtf` are ordinary RTF, read with AppKit and turned into Markdown by the same
converter as File → Import Document (`RichTextMarkdown` in `Sources/Quill/Import.swift`).

| Fact | Mark |
| --- | --- |
| Two flavours of RTF header: `{\rtf1\ansi\ansicpg1252\cocoartf…` and `{\rtf1\ansi\ansicpg1252\uc1\deff0`. AppKit reads both | Confirmed |
| Scrivener leaves its own markers in the text as plain characters: `<$Scr_Ps::0>…<!$Scr_Ps::0>` (paragraph style), `<$Scr_Cs::1>…<!$Scr_Cs::1>` (character style), `<$Scr_H::2>…<!$Scr_H::2>` (heading), `<$ScrKeepWithNext>` | Confirmed |
| Pictures pasted into a document are inline in the RTF (`\pict`) | Confirmed |
| Links between documents are RTF hyperlinks to `scrivlnk://<UUID>` | Confirmed |
| Lists, tables, centred paragraphs, underline | Confirmed |
| Compile placeholders such as `<$author>`, `<$PROJECTTITLE>`, `<$year>`, `<$wc100>`, `<$BLANK_PAGE>` appear in front-matter pages | Confirmed |
| Inline annotations and inline footnotes (said to be `{\Scrv_annot …}` and `{\Scrv_fn=…}` groups) | Not seen, not read |
| Inspector comments and footnotes (`content.comments`, linked from the text by `scrivcmt://`) | Not seen, not read |
| Text written by Scrivener for Windows | Not seen (the `\uc1\deff0` header may come from it or from the iOS app) |

What the reader does with it:

- **Markers** matching `<$Scr…>` and `<!$Scr…>` are removed. Compile placeholders are left as they are;
  they only occur on title pages and template sheets.
- **Italics, bold, strikethrough, lists, and web links** come through as Markdown. Headings are the
  short lines set larger than the body text, as in any imported document.
- **Scene breaks.** A line holding nothing but a separator (`#`, `***`, `* * *`, `⁂`, `⸻`, `---`,
  `• • •`) becomes Sable's `* * *`. One real project used `⸻` this way 33 times. A blank line used as
  a scene break is not detected; neither is a break that exists only as the gap between two
  Scrivener documents, which is for the importer to decide.
- **Typewriter fonts are prose.** One project had about twenty documents drafted in Courier, which the general
  converter would have taken for code. For Scrivener text the reader ignores fixed-pitch fonts.
- **Links** survive only if they are http, https, or mailto. Links to other documents keep their
  words and lose the link.
- **Pasted pictures** are counted per document (`embeddedPictures`) and not carried: Markdown has
  nowhere to put them. One project had six.
- **Tables** arrive as one paragraph per cell. Underline, colour, highlight, alignment, and
  indentation are dropped.
- A document that is empty or all white space has no text at all (`nil`), the same as one with no file.

## What the importer does with the tree

The reader stops at an in-memory tree. `Sources/Quill/ScrivenerImport.swift` turns that into a Fiction
Project, in two steps: a plan (every file, its path, its text; nothing on disk) and a writer.

Each top-level binder item gets a destination, suggested here and changeable in the preview sheet:

| Top-level item | Suggested destination |
| --- | --- |
| The `DraftFolder` | Manuscript |
| A name Sable already reads as a card folder (Characters, People, Places, Locations, World, Lore…), or Cast, Settings | Characters, Locations, or World |
| At least half its documents carry the character-sheet or location-sheet icon | Characters or Locations |
| The `ResearchFolder`, and anything else | Notes (`Notes/<name>/…`, folders kept) |
| The `TrashFolder`, the template-sheets folder, a top-level "… Format" page with the Information icon | Don't import |

- **Manuscript.** Sable's Manuscript folder is flat, one file per chapter. A container whose children
  are all single documents is one chapter file: its own text first, then each child as a scene, divided
  by `* * *`. A container holding other containers is a part: it has no file unless it has text, and
  its title is written to its chapters as `part:`. A single document directly in the Draft is a
  chapter by itself. Chapter order goes in the project's `chapterOrder`.
- **Scene details** (title, status, label, keywords, synopsis, document notes) go in a `<!-- -->` note
  above the scene, since Sable has no per-scene metadata and a scene's working title should not reach
  an export. `-->` inside a note is defused with a zero-width space.
- **Front matter** carries what belongs to the whole file: `type` for cards, `synopsis` (up to 500
  characters; longer ones become a note in the text, so a card's opening stays within what Sable
  indexes), `status`, `label`, `tags` from keywords, `part`, and `image` for a card with an index-card
  picture. Only `type`, `tags`, and `image` mean anything to Sable today; the rest are kept for the
  writer and for later.
- **Document notes** become a `<!-- Notes: … -->` block under the heading. Comments were chosen over a
  sidecar file because Sable already dims them, hides them in Reading Mode, and drops them on export.
- **Names.** A title becomes a file name with `/ : \` turned into `-`, `* ? " < > |` and control
  characters removed, leading periods dropped, and length capped at 80; a clash gets ` 2`, ` 3`. The
  untouched title is the file's `#` heading.
- **Files that can't convert** are copied: pictures to `Images/`, the rest to `Notes/`. Every one is
  listed in `Import Report.md`, with pasted pictures, missing or unreadable documents, and what was left
  out.
- **Writing.** The project is built in a hidden folder beside its destination and renamed into place
  only when complete. A destination that exists is refused. Every planned path is checked once more
  before it is written.

## Untrusted input

A `.scriv` can come from anywhere, so:

- The binder is parsed with external entities off, and a binder that declares any entity is refused.
- An item's `UUID` and file extensions must be plain names (letters, digits, hyphens) before they are
  used in a path. Anything else is reported and its files are not read.
- Only ordinary files that really are inside the package are read; a symbolic link pointing out of it
  is treated as missing.
- If two items claim the same `UUID`, only the first is given the files.
- `content.rtf` is read strictly as RTF and must start with `{\rtf`. It is never sniffed, so an HTML
  page under that name is not loaded. Web archives, PDFs, and pictures are never opened; the reader
  only records where they are.
- Limits: 64 MB for the binder, 32 MB per document, 1 MB per synopsis, 100,000 items, 64 levels deep.
  Past a limit the reader keeps what it has and says so.
- Anything wrong with one document is a warning on that item. Only a missing or unreadable binder, or
  an unknown format version, stops the read.

## Scrivener 2

**Everything in this section is assumed.** No real Scrivener 2 project was available, so the reader
follows public descriptions of the format, and `Tests/Fixtures/Scrivener/Scrivener 2.scriv` was built by
hand from the same descriptions. It proves the reader does what this section says, not that the section
is right. The preview sheet and the import report tell the writer the format is less tested.

| Fact | Mark |
| --- | --- |
| The binder has `Version="1.0"`; the reader also treats `Files/Docs` without `Files/Data` as this layout | Assumed |
| Items are numbered, `<BinderItem ID="12" Type="Text">`, with the same `Type` names as Scrivener 3 | Assumed |
| Files sit side by side in `Files/Docs`: `12.rtf`, `12_synopsis.txt`, `12_notes.rtf`, and `12.<ext>` for a picture or PDF | Assumed |
| `Title`, `MetaData` (`LabelID`, `StatusID`, `IncludeInCompile`, `FileExtension`), `Children`, `LabelSettings`, `StatusSettings`, and keywords are shaped as in Scrivener 3 | Assumed |
| The template-sheets folder is named by `TemplateFolderID` | Assumed |
| Index-card pictures, section types | Not known; not read |
| Inline annotations and footnotes are written into the RTF as `{\Scrv_annot …}` and `{\Scrv_fn=…}` | Assumed, not converted. If `Scrv_` survives into a document's Markdown, the reader adds a warning that stray marks may show |
| Scrivener 1 for Windows uses this same layout | Assumed |

Because one folder holds every item's files, the reader builds each file name from the item's own
identifier and nothing else: item `1` reads `1.rtf` and `1_notes.rtf`, never `11.rtf`, and an identifier
that isn't plain letters, digits, and hyphens (`1_notes`, say) reads nothing. A media item whose
extension is `rtf` is not given another item's text as its file.

A writer with a real Scrivener 2 project can check this section by running the check below over a
copy; what it prints is counts only.

## Checking this document

`scripts/check-scrivener.swift` reads the two fixtures and a set of deliberately broken projects. To
read real projects as well, name them in `SABLE_SCRIVENER_REAL`, separated by colons:

```sh
SABLE_SCRIVENER_REAL="$HOME/Documents/My Novel.scriv" /tmp/quill-scrivener-checks
```

Each is copied to a temporary folder and read from the copy. The output is counts only (items by
kind, how many have text, warnings, leftover markers) and never a title or a line of the writing, and
the run fails if the original changed in any way. The last such run, over the four projects described
above: 329, 111, 33, and 95 items, every one matching the count taken from the XML by hand; no
warnings; no leftover markers; originals untouched.
