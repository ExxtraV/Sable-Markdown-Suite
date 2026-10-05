import AppKit
import CryptoKit
import Foundation

/// Reads the hand-built Scrivener projects in Tests/Fixtures/Scrivener and checks what comes back. Run from the
/// repository root. Set SABLE_SCRIVENER_REAL to one or more project paths (separated by ":") to also read real
/// projects from a temporary copy; that pass prints numbers only, never a title or a line of anyone's writing.
@main enum ScrivenerChecks {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        setvbuf(stdout, nil, _IOLBF, 0)
        let fm = FileManager.default
        let fixtures = URL(fileURLWithPath: "Tests/Fixtures/Scrivener", isDirectory: true)
        let before = fingerprint(fixtures)
        precondition(!before.isEmpty, "Run from the repository root: the fixtures are in Tests/Fixtures/Scrivener")

        // MARK: A novel, the way Scrivener's Novel template lays one out
        let novel = try ScrivenerReader.read(fixtures.appendingPathComponent("Novel.scriv"))
        precondition(novel.title == "Novel" && novel.formatVersion == "2.0" && novel.creator == "SCRMAC-3.5.2-17487", "Project details")
        precondition(novel.labels == ["Oona", "The Toll Keeper"], "\"No Label\" is not a label: \(novel.labels)")
        precondition(novel.statuses == ["To Do", "First Draft", "Done"], "\"No Status\" is not a status: \(novel.statuses)")
        precondition(novel.warnings.isEmpty, "A clean project reads without complaint: \(novel.warnings)")
        precondition(novel.binder.map(\.title) == ["Novel Format", "The Salt Road", "Characters", "Places", "Front Matter", "Notes", "Research", "Template Sheets", "Trash"], "Binder order")
        precondition(novel.allItems.count == 25, "Every binder item is read: \(novel.allItems.count)")

        let draft = novel.draft!
        precondition(draft.title == "The Salt Road", "The manuscript is found by kind, whatever the writer called it")
        precondition(draft.children.map(\.title) == ["Chapter One", "Chapter Two"], "Chapters in binder order")
        precondition(draft.children[0].children.map(\.title) == ["The Ferry", "Lamps"], "Scenes in binder order")
        let chapter = draft.children[0]
        precondition(chapter.kind == .folder && chapter.isContainer && chapter.sectionType == "Chapter Heading", "Chapter folder")
        precondition(chapter.synopsis == "Oona crosses the water and meets the toll keeper." && chapter.text == nil, "A folder's synopsis")

        let ferry = chapter.children[0]
        precondition(ferry.kind == .text && ferry.label == "Oona" && ferry.status == "First Draft" && ferry.sectionType == "Scene", "Label, status, section type")
        precondition(ferry.keywords == ["water", "night"], "Keywords: \(ferry.keywords)")
        precondition(ferry.includeInCompile && !ferry.isTemplate, "Flags")
        precondition(ferry.synopsis == "Oona counts the lamps and finds one missing.", "Synopsis is trimmed: \(ferry.synopsis ?? "nil")")
        precondition(ferry.text == "The ferry left at dusk. Oona counted the lamps on the far shore *twice*, and came up one short.\n\n‘Someone has put a light out,’ she said. Nobody on deck was **listening**.\n", "Italics, bold, paragraphs: \(ferry.text ?? "nil")")
        precondition(ferry.notes == "Check the tide times.\n\nIs the lamp *really* out?\n", "Document notes: \(ferry.notes ?? "nil")")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        precondition(ferry.created.map { calendar.dateComponents([.year, .month, .day, .hour], from: $0) } == DateComponents(year: 2026, month: 3, day: 1, hour: 14), "Dates keep their time zone")

        let lamps = chapter.children[1]
        precondition(lamps.text!.contains("on the rail.\n\n* * *\n\nThe toll keeper"), "A centred # is a scene break: \(lamps.text!)")
        precondition(lamps.text!.contains("She paid him in **old coin** and he let her pass."), "Style markers leave no trace: \(lamps.text!)")
        precondition(novel.allItems.allSatisfy { !(($0.text ?? "") + ($0.notes ?? "")).contains("$Scr") }, "No Scrivener marker survives")
        let tollhouse = draft.children[1].children[0]
        precondition(tollhouse.text!.contains("\n\n* * *\n\n") && tollhouse.label == nil && tollhouse.status == nil, "* * * is a scene break; -1 means none")
        let unwritten = draft.children[1].children[1]
        precondition(unwritten.text == nil && unwritten.synopsis == nil && unwritten.notes == nil, "A document with no files is simply empty")

        let oona = novel.binder[2].children[0]
        precondition(oona.iconName == "Characters (Character Sheet)" && novel.binder[2].iconName == "Characters (Photo)", "Icons, the clue to character sheets")
        precondition(oona.text!.hasPrefix("**Role in Story:** Ferry passenger with a debt."), "A sheet's bold labels: \(oona.text!)")
        precondition(oona.cardImage?.lastPathComponent == "card-image.png", "Index-card picture")
        precondition(novel.binder[3].children[0].iconName == "Locations (Location Sheet)", "Location sheet")

        let research = novel.research!
        precondition(research.children.map(\.kind) == [.pdf, .image], "Research kinds")
        precondition(research.children[0].attachment?.lastPathComponent == "content.pdf" && research.children[1].attachment?.lastPathComponent == "content.png", "Research files")
        precondition(research.children.allSatisfy { fm.fileExists(atPath: $0.attachment!.path) && $0.text == nil }, "Attachments point at real files")
        let templates = novel.binder[7]
        precondition(templates.isTemplate && templates.children.allSatisfy(\.isTemplate), "Template sheets are marked, so blank forms aren't mistaken for characters")
        precondition(novel.allItems.filter(\.isTemplate).count == 3, "Only the template folder and its sheets")
        precondition(novel.trash?.children.map(\.title) == ["Cut opening"], "Trash is read, and kept apart")

        // MARK: Everything awkward
        let edge = try ScrivenerReader.read(fixtures.appendingPathComponent("Edge Cases.scriv"))
        let scenes = edge.draft!.children
        func scene(_ title: String) -> ScrivenerItem { scenes.first { $0.title == title }! }
        precondition(scenes[0].children[0].children[0].children[0].title == "Deep scene", "Four folders deep")
        precondition(scenes[0].flattened.count == 4, "Flattening keeps binder order")
        let wordy = scene("Chapter with its own words")
        precondition(wordy.kind == .folder && wordy.text == "A folder can hold text of its own.\n" && wordy.synopsis == "Folder synopsis." && wordy.notes == "Folder notes.\n" && wordy.children.count == 1, "A folder with its own text")
        precondition(scene("Scene with children").children.map(\.title) == ["Nested under a scene"], "A document can have children")
        precondition(scene("Who/What: Why? *Stars* <&>").text == "Stars \\* and under\\_scores stay literal.\n", "Awkward titles are kept as written; Markdown characters are escaped")
        let tide = scene("🌊 Tide — café")
        precondition(tide.text == "Café — déjà vu.\n" && tide.synopsis == "Naïve résumé — 潮", "Accents and symbols: \(tide.text ?? "nil") / \(tide.synopsis ?? "nil")")
        precondition(scene(".hidden").text == nil, "A title starting with a dot")
        precondition(scenes.filter { $0.title == "Twin" }.map(\.text) == ["First twin.\n", "Second twin.\n"], "Two items with one title stay two")
        precondition(scenes.contains { $0.title.isEmpty && $0.text == "No title element at all.\n" }, "A missing title is an empty one")
        precondition(scene("No metadata").text == "No MetaData element.\n" && !scene("No metadata").includeInCompile, "Missing metadata")
        let empty = scene("Empty")
        precondition(empty.text == nil && empty.notes == nil && empty.synopsis == nil, "Blank files are no text at all")
        precondition(scene("No folder").text == nil, "No data folder")
        precondition(scene("Windows flavour").text == "Plain start, *slanted*, **heavy**.\n\n* * *\n\nSecond “quoted” paragraph.\n", "The other kind of RTF: \(scene("Windows flavour").text ?? "nil")")
        precondition(scene("Not rich text").text == nil && scene("A web page in disguise").text == nil, "Files that aren't rich text are left out, never guessed at")
        precondition(edge.warnings.count == 2 && edge.warnings.allSatisfy { $0.message.contains("content.rtf") && $0.uuid != nil }, "…and each is reported: \(edge.warnings)")
        let links = scene("Pictures and links")
        precondition(links.embeddedPictures == 1 && !links.text!.contains("\u{FFFC}"), "Pasted pictures are counted, not carried")
        precondition(links.text!.contains("See the deep scene and [the tide page](https://example.com/tides) and a local file."), "Only web links stay links: \(links.text!)")
        precondition(!links.text!.contains("scrivlnk") && !links.text!.contains("file:") && !links.text!.contains("Scr"), "No internal links or markers")
        precondition(scene("Typewriter font").text == "Some writers draft in a typewriter face.  \nIt is still prose, *not* code, and **stays** that way.\n", "Courier is prose, not code: \(scene("Typewriter font").text ?? "nil")")
        let keyworded = scene("Keyworded")
        precondition(keyworded.keywords == ["storm", "résumé"] && keyworded.label == nil && keyworded.status == nil && keyworded.sectionType == nil, "Unknown IDs are dropped: \(keyworded)")

        let odd = edge.research!.children
        precondition(odd.map(\.kind) == [.webArchive, .other, .other, .image, .other, .pdf], "Kinds: \(odd.map(\.kind))")
        precondition(odd[0].attachment?.lastPathComponent == "content.webarchive" && odd[0].text == nil, "A web archive is a file, never opened")
        precondition(odd[1].attachment?.lastPathComponent == "content.yml" && odd[2].attachment?.lastPathComponent == "content", "Other files, with and without an extension")
        precondition(odd[3].attachment == nil, "A picture whose file is gone")
        precondition(odd[4].typeName == "Hologram" && odd[4].text == "Unknown kinds keep their text.\n", "A kind Sable has never heard of")
        precondition(odd[5].attachment == nil, "An extension can't climb out of the item's folder")
        precondition(edge.trash?.children.isEmpty == true, "Empty trash")

        let dir = fm.temporaryDirectory.appendingPathComponent("sable-scrivener-\(getpid())", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        // MARK: Planning the import
        precondition(ScrivenerImportPlanner.suggestedDestinations(for: novel) == [.skip, .manuscript, .characters, .locations, .notes, .notes, .notes, .skip, .skip], "Where each top-level item is offered: \(ScrivenerImportPlanner.suggestedDestinations(for: novel))")
        let plan = ScrivenerImportPlanner.plan(novel)
        func contents(_ path: String, in plan: ScrivenerImportPlan = plan) -> String { plan.files.first { $0.path == path }?.contents ?? "MISSING \(path)" }
        precondition(plan.summary == "4 scenes in 2 chapters, 2 characters, 1 location, 2 notes", "What the preview says: \(plan.summary)")
        precondition(plan.skippedSummary == "2 items can’t become Markdown: an image, a PDF", "…and what it can't convert: \(plan.skippedSummary ?? "nil")")
        precondition(plan.chapterOrder == ["Chapter One.md", "Chapter Two.md"], "Chapters in binder order: \(plan.chapterOrder)")
        precondition(plan.files.map(\.path) == ["Manuscript/Chapter One.md", "Manuscript/Chapter Two.md", "Images/Oona Brask.png", "Characters/Oona Brask.md", "Characters/The Toll Keeper.md", "Locations/Saltmere.md",
                                                "Notes/Front Matter/Title Page.md", "Notes/Loose ends.md", "Notes/Research/Tide tables.pdf", "Images/Harbour sketch.png", "Import Report.md"], "Every file, and where: \(plan.files.map(\.path))")
        let chapterOne = contents("Manuscript/Chapter One.md")
        precondition(chapterOne.hasPrefix("---\nsynopsis: Oona crosses the water and meets the toll keeper.\n---\n\n# Chapter One\n\n<!-- Scene: The Ferry · Status: First Draft · Label: Oona · Keywords: water, night\nSynopsis: Oona counts the lamps and finds one missing.\nNotes:\nCheck the tide times.\n\nIs the lamp *really* out?\n-->\n\nThe ferry left at dusk."), "A chapter folder becomes one file; scene details are notes: \(chapterOne)")
        precondition(chapterOne.contains("**listening**.\n\n* * *\n\n<!-- Scene: Lamps · Status: To Do · Label: The Toll Keeper -->\n\nBy morning"), "Scenes are divided by a scene break: \(chapterOne)")
        precondition(FrontMatter.parse(chapterOne).value(for: "synopsis") == "Oona crosses the water and meets the toll keeper.", "Front matter Sable can read back")
        precondition(contents("Manuscript/Chapter Two.md").contains("<!-- Scene: Tollhouse -->") && contents("Manuscript/Chapter Two.md").hasSuffix("<!-- Scene: Not written yet -->\n"), "An unwritten scene keeps its place: \(contents("Manuscript/Chapter Two.md"))")
        precondition(contents("Characters/Oona Brask.md") == "---\ntype: character\nsynopsis: Counts everything twice.\nimage: Images/Oona Brask.png\n---\n\n# Oona Brask\n\n**Role in Story:** Ferry passenger with a debt.\n\n**Occupation:** Lamplighter.\n", "A character card: \(contents("Characters/Oona Brask.md"))")
        precondition(contents("Locations/Saltmere.md").hasPrefix("---\ntype: location\n---\n\n# Saltmere\n"), "A location card")
        precondition(contents("Notes/Loose ends.md") == "# Loose ends\n\nWho put the lamp out?\n", "A plain note has no front matter")
        let report = contents("Import Report.md")
        precondition(report.contains("- Tide tables: `Notes/Research/Tide tables.pdf`") && report.contains("- Harbour sketch: `Images/Harbour sketch.png`") && report.contains("- Template Sheets (2 items)") && report.contains("- Trash"), "The report lists what wasn't converted: \(report)")
        precondition(!plan.files.contains { $0.path.contains("Character Sketch") || $0.path.contains("Cut opening") || $0.path.contains("Novel Format") }, "Templates, trash, and the template's own help page stay behind")

        // The writer's choices in the preview change the plan.
        var choices = ScrivenerImportPlanner.suggestedDestinations(for: novel)
        choices[8] = .notes; choices[5] = .manuscript; choices[2] = .skip
        let chosen = ScrivenerImportPlanner.plan(novel, destinations: choices)
        precondition(contents("Notes/Trash/Cut opening.md", in: chosen).contains("dark and salty"), "Trash can be kept, as notes")
        precondition(chosen.chapterOrder == ["Chapter One.md", "Chapter Two.md", "Notes.md"] && contents("Manuscript/Notes.md", in: chosen).contains("<!-- Scene: Loose ends -->"), "Another folder can join the manuscript: \(chosen.chapterOrder)")
        precondition(chosen.characters == 0 && chosen.skipped.contains { $0.kind == .leftOut && $0.title == "Characters" && $0.count == 2 }, "…and anything can be left out")

        let edgePlan = ScrivenerImportPlanner.plan(edge)
        precondition(Array(edgePlan.chapterOrder.prefix(8)) == ["Chapter.md", "Chapter with its own words.md", "Scene with children.md", "Who-What- Why Stars &.md", "🌊 Tide — café.md", "hidden.md", "Twin.md", "Twin 2.md"], "File names are safe and never collide: \(edgePlan.chapterOrder)")
        precondition(contents("Manuscript/Chapter.md", in: edgePlan) == "---\npart: Part\n---\n\n# Chapter\n\n<!-- Scene: Deep scene -->\n\nFour folders down.\n", "Folders above a chapter are its part: \(contents("Manuscript/Chapter.md", in: edgePlan))")
        precondition(contents("Manuscript/Chapter with its own words.md", in: edgePlan).contains("<!-- Notes:\nFolder notes.\n-->\n\nA folder can hold text of its own.\n\n* * *\n\n<!-- Scene: Inside it -->"), "A folder's own text opens its chapter")
        precondition(contents("Manuscript/Who-What- Why Stars &.md", in: edgePlan).hasPrefix("# Who/What: Why? \\*Stars\\* \\<&>\n"), "The title is kept whole in the heading")
        precondition(contents("Manuscript/Untitled.md", in: edgePlan).hasPrefix("# Untitled\n") && contents("Manuscript/Empty.md", in: edgePlan) == "# Empty\n", "Untitled and empty documents")
        precondition(contents("Manuscript/Keyworded.md", in: edgePlan).hasPrefix("---\ntags: storm, résumé\n---\n"), "Keywords become tags")
        precondition(edgePlan.files.filter { $0.source != nil }.map(\.path) == ["Notes/Research/Saved page.webarchive", "Notes/Research/Settings file.yml", "Notes/Research/No extension"], "Files that can't convert are copied: \(edgePlan.files.filter { $0.source != nil }.map(\.path))")
        precondition(edgePlan.skippedSummary == "8 items can’t become Markdown: a web page, other files, a pasted picture, missing files, unreadable documents", "\(edgePlan.skippedSummary ?? "nil")")
        precondition(ScrivenerImportPlanner.fileName(for: "  ..//a:b\\c\n*?  ") == "--a-b-c" && ScrivenerImportPlanner.fileName(for: " . ") == "Untitled" && ScrivenerImportPlanner.fileName(for: String(repeating: "x", count: 300)).count == 80, "Names: \(ScrivenerImportPlanner.fileName(for: "  ..//a:b\\c\n*?  "))")

        var tricky = ScrivenerItem(uuid: "T", kind: .text, typeName: "Text", title: "Line one\n--> two")
        tricky.synopsis = String(repeating: "Long. ", count: 120)
        tricky.notes = "A note that tries to end --> early <!-- and start again.\n"
        tricky.text = "# Already Headed\n\nBody.\n"
        tricky.iconName = "Characters (Character Sheet)"
        var loose = ScrivenerItem(uuid: "L", kind: .folder, typeName: "Folder", title: "Odds and ends")
        loose.children = [tricky, ScrivenerItem(uuid: "P1", kind: .text, typeName: "Text", title: "Plain", text: "One.\n"), ScrivenerItem(uuid: "P2", kind: .text, typeName: "Text", title: "Plainer", text: "Two.\n")]
        let trickyPlan = ScrivenerImportPlanner.plan(ScrivenerProject(title: "T", creator: "", formatVersion: "2.0", binder: [loose, tricky]))
        precondition(ScrivenerImportPlanner.suggestedDestination(for: tricky) == .characters && ScrivenerImportPlanner.suggestedDestination(for: loose) == .notes && trickyPlan.characters == 2 && trickyPlan.notes == 2, "A lone character sheet is offered to Characters")
        precondition(trickyPlan.files.map(\.path).contains("Characters/Line one -- two.md"), "\(trickyPlan.files.map(\.path))")
        let trickyText = contents("Notes/Odds and ends/Line one -- two.md", in: trickyPlan)
        precondition(trickyText.hasPrefix("---\ntype: character\n---\n\n<!-- Synopsis:\nLong. ") && !trickyText.contains("# Line one"), "A character sheet anywhere is a card; a long synopsis moves into the text; a heading isn't doubled: \(trickyText.prefix(120))")
        precondition(trickyText.components(separatedBy: "-->").count == 3 && trickyText.components(separatedBy: "<!--").count == 3 && trickyText.hasSuffix("# Already Headed\n\nBody.\n"), "Notes can't break out of their comment: \(trickyText.suffix(200))")

        // MARK: Writing the Fiction Project
        let destination = dir.appendingPathComponent("Imported/The Salt Road", isDirectory: true)
        let written = try ScrivenerImportWriter.write(plan, project: novel, to: destination)
        precondition(written == destination && FictionProject.isProject(destination), "A Fiction Project is made where the writer asked")
        let made = FictionProject.load(destination)!
        precondition(made.title == "The Salt Road" && made.chapterOrder == ["Chapter One.md", "Chapter Two.md"], "Named after its folder, chapters in order")
        precondition(FictionProject.standardFolders.allSatisfy { fm.fileExists(atPath: destination.appendingPathComponent($0).path) } && fm.fileExists(atPath: FictionProject.guideURL(in: destination).path), "The usual folders and Start Here")
        precondition(plan.files.allSatisfy { fm.fileExists(atPath: destination.appendingPathComponent($0.path).path) }, "Every planned file is there")
        precondition(try! Data(contentsOf: destination.appendingPathComponent("Images/Oona Brask.png")) == (try! Data(contentsOf: oona.cardImage!)), "Pictures are copied whole")
        let chapters = ManuscriptStats.load(folder: FictionProject.folder(for: .chapter, in: destination), order: made.chapterOrder)
        precondition(chapters.map(\.name) == ["Chapter One.md", "Chapter Two.md"] && chapters[0].words > 60, "Sable lists the chapters, in order, with their words: \(chapters.map(\.words))")
        let cards = CardIndex.load(project: destination)
        precondition(cards.map(\.title) == ["Oona Brask", "Saltmere", "The Toll Keeper"] && cards.map(\.kind) == [.character, .location, .character], "Sable sees the cards: \(cards.map(\.title))")
        precondition(ScrivenerImportWriter.firstChapter(in: destination)?.lastPathComponent == "Chapter One.md", "Where the writer lands")
        precondition(try! String(contentsOf: destination.appendingPathComponent("Import Report.md"), encoding: .utf8).contains("## Copied, not converted"), "The report is in the project")
        precondition(try! fm.contentsOfDirectory(atPath: destination.deletingLastPathComponent().path) == ["The Salt Road"], "Nothing is left behind beside it")
        do { try ScrivenerImportWriter.write(plan, project: novel, to: destination); preconditionFailure("An existing folder is never written into") } catch let error as ScrivenerImportError { precondition(error.errorDescription!.contains("already exists")) }

        // A plan is only ever built here, but the writer still refuses a path that leaves the project.
        var hostile = ScrivenerImportPlan(title: "H")
        hostile.files = [.init(path: "../escaped.md", contents: "x"), .init(path: "Notes/.hidden.md", contents: "x"), .init(path: "Notes/ok.md", contents: "fine"), .init(path: "Notes/gone.pdf", source: dir.appendingPathComponent("no-such-file.pdf"))]
        let fenced = try ScrivenerImportWriter.write(hostile, project: novel, to: dir.appendingPathComponent("Fenced/Project"))
        precondition(try! fm.contentsOfDirectory(atPath: dir.appendingPathComponent("Fenced").path) == ["Project"] && fm.fileExists(atPath: fenced.appendingPathComponent("Notes/ok.md").path) && !fm.fileExists(atPath: fenced.appendingPathComponent("Notes/.hidden.md").path), "Nothing lands outside the new folder")
        let fencedReport = try String(contentsOf: fenced.appendingPathComponent("Import Report.md"), encoding: .utf8)
        precondition(fencedReport.contains("## Couldn’t be copied") && fencedReport.contains("`Notes/gone.pdf`"), "A file that can't be copied is reported, and the import still finishes: \(fencedReport)")

        // MARK: Importing never writes to the Scrivener project
        precondition(fingerprint(fixtures) == before, "The Scrivener projects are exactly as they were")

        // MARK: Damaged and hostile projects
        let rtf = "{\\rtf1\\ansi{\\fonttbl\\f0\\fswiss Helvetica;}\\f0\\fs24 Inside.}"
        func package(_ name: String, binder: String?, files: [String: String] = [:]) -> URL {
            let url = dir.appendingPathComponent(name + ".scriv", isDirectory: true)
            try! fm.createDirectory(at: url.appendingPathComponent("Files/Data"), withIntermediateDirectories: true)
            if let binder { try! binder.write(to: url.appendingPathComponent(name + ".scrivx"), atomically: true, encoding: .utf8) }
            for (path, text) in files {
                let file = url.appendingPathComponent(path)
                try! fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try! text.write(to: file, atomically: true, encoding: .utf8)
            }
            return url
        }
        func project(version: String = "2.0", _ items: String) -> String {
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<ScrivenerProject Version=\"\(version)\" Creator=\"TEST\"><Binder>\(items)</Binder></ScrivenerProject>"
        }
        func failure(_ url: URL) -> ScrivenerError? {
            do { _ = try ScrivenerReader.read(url); return nil } catch { return error as? ScrivenerError }
        }
        let secret = dir.appendingPathComponent("secret.rtf")
        try rtf.replacingOccurrences(of: "Inside", with: "Outside").write(to: secret, atomically: true, encoding: .utf8)

        precondition(failure(secret) == .notPackage && failure(dir.appendingPathComponent("Nowhere.scriv")) == .notPackage, "A file, or nothing, is not a project")
        precondition(failure(package("NoBinder", binder: nil)) == .noBinder, "No .scrivx")
        precondition(failure(package("Cut", binder: String(project("<BinderItem UUID=\"A1\" Type=\"Text\"><Title>Half").dropLast(40)))) == .unreadableBinder, "Truncated XML")
        precondition(failure(package("Wrong", binder: "<?xml version=\"1.0\"?><html><body/></html>")) == .unreadableBinder, "Some other XML")
        precondition(failure(package("Two", binder: project(version: "1.0", ""))) == .scrivener2, "Scrivener 2 is named as such")
        precondition(failure(package("Nine", binder: project(version: "9.0", ""))) == .unsupportedVersion("9.0"), "A format from the future")
        let bomb = "<?xml version=\"1.0\"?><!DOCTYPE x [<!ENTITY a \"aaaaaaaaaa\"><!ENTITY b \"&a;&a;&a;&a;&a;&a;&a;&a;\"><!ENTITY f SYSTEM \"file:///etc/hosts\">]>"
            + "<ScrivenerProject Version=\"2.0\"><Binder><BinderItem UUID=\"A1\" Type=\"Text\"><Title>&b;&f;</Title></BinderItem></Binder></ScrivenerProject>"
        precondition(failure(package("Entities", binder: bomb)) == .unreadableBinder, "A binder that declares entities is refused")

        // Identifiers that try to leave the project, and a link that does.
        let climbing = package("Climb", binder: project("""
            <BinderItem UUID="../../secret" Type="Text"><Title>Climber</Title></BinderItem>
            <BinderItem UUID="A1/../../.." Type="Text"><Title>Slash</Title></BinderItem>
            <BinderItem UUID="" Type="Text"><Title>Blank</Title></BinderItem>
            <BinderItem UUID="GOOD-1" Type="Text"><Title>Good</Title></BinderItem>
            <BinderItem UUID="GOOD-1" Type="Text"><Title>Echo</Title></BinderItem>
            <BinderItem UUID="LINK-1" Type="Text"><Title>Link</Title></BinderItem>
            """), files: ["Files/Data/GOOD-1/content.rtf": rtf])
        try fm.createDirectory(at: climbing.appendingPathComponent("Files/Data/LINK-1"), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: climbing.appendingPathComponent("Files/Data/LINK-1/content.rtf"), withDestinationURL: secret)
        let climbed = try ScrivenerReader.read(climbing)
        precondition(climbed.binder.map(\.text) == [nil, nil, nil, "Inside.\n", nil, nil], "Only files inside the project are read, and each once: \(climbed.binder.map(\.text))")
        precondition(climbed.warnings.count == 4 && climbed.warnings.allSatisfy { !$0.message.contains("secret") }, "Each refusal is reported: \(climbed.warnings)")
        precondition(!ScrivenerReader.isSafeName("..") && !ScrivenerReader.isSafeName("a/b") && !ScrivenerReader.isSafeName("a.b") && ScrivenerReader.isSafeName("F8F9FDEF-FD9F-4A8C-B33D-3434A1220ADC"), "Plain names only")

        // Far too deep: the reader stops, says so, and keeps what it had.
        let depth = 200
        let nested = String(repeating: "<BinderItem UUID=\"N\" Type=\"Folder\"><Children>", count: depth) + String(repeating: "</Children></BinderItem>", count: depth)
        let deep = try ScrivenerReader.read(package("Deep", binder: project(nested)))
        precondition(deep.allItems.count == ScrivenerReader.maxDepth && deep.warnings.contains { $0.message.contains("deeply nested") }, "Depth is capped: \(deep.allItems.count)")

        // A project with nothing in it.
        let bare = try ScrivenerReader.read(package("Bare", binder: "<ScrivenerProject Version=\"2.0\"/>"))
        precondition(bare.binder.isEmpty && bare.draft == nil && bare.warnings.isEmpty && bare.title == "Bare", "An empty project is an empty tree")

        // Markers and separators, on their own.
        func converted(_ body: String) -> String { ScrivenerText.markdown(fromRTF: Data("{\\rtf1\\ansi{\\fonttbl\\f0\\fswiss Helvetica;}\\f0\\fs24 \(body)}".utf8))!.markdown }
        precondition(converted("<$Scr_Ps::12>One<!$Scr_Ps::12> <$ScrKeepWithNext>two <$Scr_Cs::3>three<!$Scr_Cs::3>.") == "One two three.\n", "Markers: \(converted("<$Scr_Ps::12>One"))")
        precondition(converted("a < b and c > d, <$notScr> stays") == "a < b and c > d, <$notScr> stays\n", "Ordinary angle brackets are left alone")
        for separator in ["#", "###", "***", "* * *", "*", "\\u8258?", "\\u11835?", "---", "- - -", "\\u8226? \\u8226? \\u8226?"] {
            precondition(converted("Up.\\par \(separator)\\par Down.") == "Up.\n\n* * *\n\nDown.\n", "\(separator) on its own line is a scene break: \(converted("Up.\\par \(separator)\\par Down."))")
        }
        precondition(converted("Up.\\par # of items: 3\\par - a dash\\par Down.") == "Up.\n\n# of items: 3\n\n- a dash\n\nDown.\n", "Lines that merely start with a separator are text")
        precondition(ScrivenerText.markdown(fromRTF: Data()) == nil && ScrivenerText.markdown(fromRTF: Data("{\\rtf1".utf8))?.markdown ?? "" == "", "Empty and cut-off files")

        // MARK: Real projects (local only)
        if let real = ProcessInfo.processInfo.environment["SABLE_SCRIVENER_REAL"], !real.isEmpty {
            for (index, path) in real.split(separator: ":").enumerated() {
                let original = URL(fileURLWithPath: String(path))
                let stamp = fingerprint(original, contents: false)
                let copy = dir.appendingPathComponent("real-\(index).scriv", isDirectory: true)
                try fm.copyItem(at: original, to: copy)
                let started = Date()
                let project = try ScrivenerReader.read(copy)
                let items = project.allItems
                let kinds = Dictionary(grouping: items, by: \.kind).map { "\($0.key.rawValue) \($0.value.count)" }.sorted().joined(separator: ", ")
                let leftovers = items.filter { (($0.text ?? "") + ($0.notes ?? "")).contains("$Scr") }.count
                let rtfFiles = (fm.enumerator(at: copy.appendingPathComponent("Files/Data"), includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []).filter { $0.pathExtension == "rtf" }.count
                print("""
                real project \(index + 1): \(project.creator), format \(project.formatVersion), read in \(String(format: "%.2f", Date().timeIntervalSince(started)))s
                  items \(items.count) (\(kinds))
                  draft: \(project.draft.map { "\($0.flattened.count - 1) items, \($0.flattened.filter { $0.text != nil }.count) with text" } ?? "none"); top-level items \(project.binder.count); templates \(items.filter(\.isTemplate).count); trash \(project.trash.map { $0.flattened.count - 1 } ?? 0)
                  with text \(items.filter { $0.text != nil }.count), notes \(items.filter { $0.notes != nil }.count), synopsis \(items.filter { $0.synopsis != nil }.count), attachments \(items.filter { $0.attachment != nil }.count), card images \(items.filter { $0.cardImage != nil }.count); rtf files on disk \(rtfFiles)
                  labels \(project.labels.count), statuses \(project.statuses.count); items with label \(items.filter { $0.label != nil }.count), status \(items.filter { $0.status != nil }.count), keywords \(items.filter { !$0.keywords.isEmpty }.count), section type \(items.filter { $0.sectionType != nil }.count), untitled \(items.filter(\.title.isEmpty).count)
                  scene breaks \(items.reduce(0) { $0 + (($1.text ?? "").components(separatedBy: "\n* * *\n").count - 1) }), pasted pictures \(items.reduce(0) { $0 + $1.embeddedPictures }), headings \(items.reduce(0) { $0 + ($1.text ?? "").components(separatedBy: "\n").filter { $0.hasPrefix("#") }.count })
                  warnings \(project.warnings.count)\(project.warnings.isEmpty ? "" : ": " + Dictionary(grouping: project.warnings, by: \.message).map { "\($0.value.count)× \($0.key)" }.joined(separator: "; ")), leftover markers \(leftovers)
                """)
                let plan = ScrivenerImportPlanner.plan(project)
                let imported = try ScrivenerImportWriter.write(plan, project: project, to: dir.appendingPathComponent("real-out-\(index)/Imported", isDirectory: true))
                let stats = ManuscriptStats.load(folder: FictionProject.folder(for: .chapter, in: imported), order: FictionProject.load(imported)?.chapterOrder)
                let foundCards = CardIndex.load(project: imported)
                print("""
                  import: \(plan.summary); \(plan.skippedSummary ?? "everything converts")
                  destinations \(Dictionary(grouping: ScrivenerImportPlanner.suggestedDestinations(for: project), by: \.rawValue).map { "\($0.key) \($0.value.count)" }.sorted().joined(separator: ", ")); files written \(plan.files.count), copied \(plan.files.filter { $0.source != nil }.count)
                  Sable sees \(stats.count) chapters (\(stats.reduce(0) { $0 + $1.words }) words), \(foundCards.filter { $0.kind == .character }.count) characters, \(foundCards.filter { $0.kind == .location }.count) locations, \(foundCards.filter { $0.kind == .lore }.count) world notes
                """)
                precondition(leftovers == 0 && fingerprint(original, contents: false) == stamp, "Real project \(index + 1)")
                print("  original untouched: \(fingerprint(original, contents: false) == stamp)")
                precondition(stats.count == plan.chapters && foundCards.count == plan.characters + plan.locations + plan.worldNotes, "Real project \(index + 1): Sable finds what was planned")
            }
        }

        print("Scrivener checks passed")
    }

    /// Every file's path, size, and modification time (and, for the fixtures, a hash of what is in it).
    static func fingerprint(_ folder: URL, contents: Bool = true) -> [String] {
        let base = folder.path
        let urls = (FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey])?.compactMap { $0 as? URL } ?? [])
        return urls.compactMap { url -> String? in
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]), values.isRegularFile == true else { return nil }
            let hash = contents ? (try? Data(contentsOf: url)).map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? "" : ""
            return "\(url.path.dropFirst(base.count)) \(values.fileSize ?? 0) \(values.contentModificationDate?.timeIntervalSince1970 ?? 0) \(hash)"
        }.sorted()
    }
}
