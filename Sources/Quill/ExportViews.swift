import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// What is being exported: a project's whole manuscript, or just the document in front of you.
enum ExportSource: Identifiable {
    /// `unsaved` swaps in the text of a chapter that's open with changes not yet saved, so the export is what's on screen.
    case manuscript(project: URL, title: String, unsaved: [String: String])
    /// `url` is the document's file, if it has one, so the export can't be saved over it.
    case document(title: String, markdown: String, url: URL?)
    var id: String {
        switch self { case .manuscript: return "manuscript"; case .document: return "document" }
    }
}

/// Choose a format, a look and its layout, and which chapters, then save one file.
/// A project keeps its own layout; exports of a single document share one remembered layout.
struct ExportSheet: View {
    let source: ExportSource
    let close: () -> Void
    @AppStorage("exportAuthor") private var author = NSFullUserName()
    @AppStorage("exportFormat") private var formatName = ExportFormat.pdf.rawValue
    // The last look and page size used anywhere, where a project with no layout of its own starts.
    @AppStorage("exportStyle") private var styleName = ExportStyle.manuscript.rawValue
    @AppStorage("exportPageSize") private var pageName = PageSize.regional.rawValue
    @AppStorage("exportTitlePage") private var titlePage = true
    @AppStorage("exportPageBreaks") private var pageBreaks = true
    @AppStorage("exportDocumentLayout") private var documentLayout = ""
    @State private var layout = ExportLayout()
    @State private var choicesHeight: CGFloat = 0
    @State private var title = ""
    @State private var chapters: [ExportChapter] = []
    @State private var included: Set<String> = []
    /// The project's folders that hold writing, and the one this export is made from (Manuscript unless changed).
    @State private var folders: [ExportFolder] = []
    @State private var folderID = ""
    @State private var loading = true
    @State private var working = false
    @State private var problem: String?

    private var format: ExportFormat { ExportFormat(rawValue: formatName) ?? .pdf }
    private var isManuscript: Bool { if case .manuscript = source { return true } else { return false } }
    private var chosen: [ExportChapter] { chapters.filter { included.contains($0.id) } }
    private var chosenWords: Int { chosen.reduce(0) { $0 + $1.words } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isManuscript ? "Export Manuscript" : "Export Document").font(.title3.weight(.semibold)).accessibilitySectionHeading()
            // The choices scroll when the window is too short for them, so Export and Cancel stay in view.
            ScrollView {
                choices.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { choicesHeight = $0 }
            }
            .frame(height: min(choicesHeight, room))
            .scrollBounceBehavior(.basedOnSize)

            if let problem { Text(problem).font(.caption).foregroundStyle(.orange) }
            HStack {
                Text(isManuscript ? summary : "").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if working { ProgressView().controlSize(.small).accessibilityLabel("Exporting") }
                Button("Cancel", role: .cancel, action: close).keyboardShortcut(.cancelAction)
                Button("Export…", action: save).keyboardShortcut(.defaultAction)
                    .disabled(working || loading || chosen.isEmpty || title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22).frame(width: 470)
        .task { await load() }
        .onChange(of: problem) { _, new in if let new { Announce.say(new) } }
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: 14) {
            Form {
                TextField("Title", text: $title)
                TextField("Author", text: $author)
                Picker("Format", selection: $formatName) {
                    ForEach(ExportFormat.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }.pickerStyle(.segmented)
                if format.isPaged {
                    Picker("Look", selection: Binding(get: { layout.style }, set: { layout.start(from: $0) })) {
                        ForEach(ExportStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    HStack(alignment: .firstTextBaseline) {
                        Text(layout.isAdjusted ? "Adjusted from the \(layout.style.title) look." : layout.style.detail)
                            .font(.caption).foregroundStyle(.secondary)
                        if layout.isAdjusted {
                            Button("Reset") { layout.start(from: layout.style) }
                                .buttonStyle(.link).font(.caption)
                                .accessibilityLabel("Reset the layout to the \(layout.style.title) look")
                        }
                    }
                }
                Section { layoutRows } header: { Text("Layout").font(.subheadline.weight(.medium)).padding(.top, 6).accessibilitySectionHeading() }
            }.formStyle(.columns)

            if isManuscript { chapterList }
        }
    }

    /// Height left for the choices in the window the sheet belongs to, after its title, buttons, and padding.
    private var room: CGFloat {
        guard let window = NSApp.mainWindow else { return .infinity }
        return max(180, window.contentLayoutRect.height - 150)
    }

    /// The Layout rows, in the sheet's one form so their labels line up with Title, Author, and Format.
    /// PDF and Word take every choice. EPUB takes the alignment of headings and the title page, since an
    /// e-reader sets its own type and pages. Markdown takes only the title page.
    @ViewBuilder private var layoutRows: some View {
        if format.isPaged {
            LabeledContent("Page") {
                HStack {
                    Picker("Page size", selection: $layout.pageSize) {
                        ForEach(PageSize.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().fixedSize()
                    Picker("Margins", selection: $layout.margins) {
                        ForEach(ExportLayout.marginChoices, id: \.self) { Text("\($0.formatted()) in margins").tag($0) }
                    }.labelsHidden().fixedSize()
                }
            }
            LabeledContent("Text") {
                HStack {
                    Picker("Font", selection: $layout.font) {
                        ForEach(ExportFont.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().fixedSize()
                    Picker("Size", selection: $layout.fontSize) {
                        ForEach(ExportLayout.fontSizes, id: \.self) { Text("\($0) pt").tag($0) }
                    }.labelsHidden().fixedSize()
                }
            }
            Picker("Line spacing", selection: $layout.lineSpacing) {
                ForEach(LineSpacing.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).fixedSize()
        }
        if format != .markdown {
            Picker("Headings", selection: $layout.headingAlignment) {
                ForEach(ExportAlignment.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).fixedSize()
        }
        LabeledContent("Title page") {
            HStack {
                Toggle("Include", isOn: $layout.titlePage).toggleStyle(.checkbox)
                    .accessibilityLabel("Include a title page")
                if format != .markdown {
                    Picker("Title page alignment", selection: $layout.titleAlignment) {
                        ForEach(ExportAlignment.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().fixedSize().disabled(!layout.titlePage)
                }
            }
        }
        if format.isPaged {
            LabeledContent("On each page") {
                HStack(spacing: 14) {
                    Toggle("Page numbers", isOn: $layout.pageNumbers).toggleStyle(.checkbox)
                    Toggle("Running header", isOn: $layout.runningHeader).toggleStyle(.checkbox)
                        .help("Your surname and the title at the top of each page, with the page number when page numbers are on.")
                }
            }
            if isManuscript {
                LabeledContent("Chapters") {
                    Toggle("Start each on a new page", isOn: $layout.chapterPageBreaks).toggleStyle(.checkbox)
                }
            }
        }
    }

    /// Where the layout starts before anything was saved: the last look and page size used, with the
    /// title page and chapter breaks as the Export sheet had them. A single document starts without a title page.
    private var startingLayout: ExportLayout {
        var start = ExportLayout(style: ExportStyle(rawValue: styleName) ?? .manuscript)
        start.pageSize = PageSize(rawValue: pageName) ?? .regional
        start.titlePage = isManuscript && titlePage
        start.chapterPageBreaks = pageBreaks
        return start
    }

    /// Keeps the layout with the project, or for the next single document, and notes the look and page size for new projects.
    private func rememberLayout() {
        switch source {
        case let .manuscript(project, _, _): try? FictionProject.setExportLayout(layout.saved, in: project)
        case .document: documentLayout = layout.json
        }
        styleName = layout.style.rawValue
        pageName = layout.pageSize.rawValue
        if isManuscript { titlePage = layout.titlePage; pageBreaks = layout.chapterPageBreaks }
    }

    private var summary: String {
        loading ? "Reading chapters…" : "\(chosen.count) of \(chapters.count) chapters · \(chosenWords.formatted()) words"
    }

    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Chapters").font(.subheadline.weight(.medium)).accessibilitySectionHeading()
                if folders.count > 1 {
                    Picker("Export chapters from", selection: $folderID) {
                        ForEach(folders) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden().fixedSize().controlSize(.small)
                    .help("The folder whose files are the chapters. Manuscript is your project’s own; choose another for a second book or an older draft.")
                    .onChange(of: folderID) { _, _ in Task { await loadChapters() } }
                }
                Spacer()
                Button("All") { included = Set(chapters.map(\.id)) }.buttonStyle(.link).font(.caption).accessibilityLabel("Include every chapter")
                Button("None") { included = [] }.buttonStyle(.link).font(.caption).accessibilityLabel("Include no chapters")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(chapters) { chapter in
                        Toggle(isOn: Binding(get: { included.contains(chapter.id) }, set: { on in
                            if on { included.insert(chapter.id) } else { included.remove(chapter.id) }
                        })) {
                            HStack {
                                Text(chapter.title).lineLimit(1)
                                Spacer(minLength: 8)
                                Text(chapter.words.formatted()).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                        }.toggleStyle(.checkbox)
                            .accessibilityLabel(chapter.title)
                            .accessibilityValue("\(chapter.words.formatted()) words")
                    }
                    if chapters.isEmpty && !loading { Text(chosenFolder?.isManuscript == false ? "This folder has no Markdown files." : "This project has no chapters yet.").font(.caption).foregroundStyle(.secondary) }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Chapters to export")
            Text(chosenFolder?.isManuscript == false ? "Every file in “\(chosenFolder?.name ?? "")” and its subfolders, in name order." : "In the order you arranged them in the Manuscript tab.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func load() async {
        switch source {
        case let .manuscript(project, projectTitle, unsaved):
            title = projectTitle
            layout = ExportLayout(saved: FictionProject.load(project)?.exportLayout?.values, fallback: startingLayout)
            _ = unsaved
            let found = await Task.detached { ManuscriptExport.sourceFolders(project: project) }.value
            folders = found
            folderID = found.first?.id ?? ""
            await loadChapters()
        case let .document(documentTitle, markdown, _):
            title = documentTitle
            layout = documentLayout.isEmpty ? startingLayout : ExportLayout(json: documentLayout, fallback: startingLayout)
            chapters = [ManuscriptExport.chapter(named: documentTitle + ".md", markdown: markdown)]
            included = Set(chapters.map(\.id))
        }
        loading = false
    }

    private var chosenFolder: ExportFolder? { folders.first { $0.id == folderID } }

    /// Reads the chapters of the chosen folder. In Manuscript, a chapter open with unsaved changes is exported as it is on screen.
    private func loadChapters() async {
        guard case let .manuscript(project, _, unsaved) = source else { return }
        let folder = chosenFolder
        var loaded = await Task.detached { folder?.isManuscript == false ? ManuscriptExport.chapters(in: folder!.url) : ManuscriptExport.chapters(project: project) }.value
        guard folder?.id == chosenFolder?.id else { return }
        if folder?.isManuscript != false {
            for (name, markdown) in unsaved {
                if let index = loaded.firstIndex(where: { $0.name == name }) { loaded[index] = ManuscriptExport.chapter(named: name, markdown: markdown) }
            }
        }
        chapters = loaded
        included = Set(loaded.map(\.id))
    }

    /// The files this export is made from.
    private var sourceFiles: [URL] {
        switch source {
        case let .manuscript(project, _, _):
            let folder = FictionProject.folder(for: .chapter, in: project)
            if let chosen = chosenFolder, !chosen.isManuscript { return ManuscriptExport.files(under: chosen.url) }
            return (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        case let .document(_, _, url): return url.map { [$0] } ?? []
        }
    }

    private var protectedFolders: [URL] {
        if case let .manuscript(project, _, _) = source { return [FictionProject.folder(for: .chapter, in: project)] + (chosenFolder.map { [$0.url] } ?? []) }
        return []
    }

    private func save() {
        var options = ExportOptions()
        options.title = title.trimmingCharacters(in: .whitespaces)
        options.author = author.trimmingCharacters(in: .whitespaces)
        options.format = format
        options.layout = layout
        if !isManuscript { options.layout.chapterPageBreaks = true }
        let selected = chosen
        rememberLayout()

        let panel = NSSavePanel()
        panel.title = "Export"
        panel.prompt = "Export"
        panel.nameFieldStringValue = ManuscriptExport.fileName(for: options.title, format: format)
        if let type = UTType(filenameExtension: format.fileExtension) { panel.allowedContentTypes = [type] }
        panel.canCreateDirectories = true
        // Capture a copy of `options`: a captured `var` is shared with this main-actor function, so it can't be sent to the detached export.
        panel.begin { [options] response in
            guard response == .OK, let url = panel.url else { return }
            if let refusal = ExportDestination.problem(for: url, sources: sourceFiles, open: NSDocumentController.shared.documents.compactMap(\.fileURL), protectedFolders: protectedFolders) {
                problem = refusal
                return
            }
            working = true
            problem = nil
            Task {
                let outcome = await Task.detached { () -> Result<Void, Error> in
                    Result {
                        let data = try ManuscriptExport.export(selected, options: options)
                        // A file this replaces goes to the Trash as a copy first, in case it wasn't meant to go.
                        if FileManager.default.fileExists(atPath: url.path) { try SafeFile.keepCopyInTrash(of: url, named: SafeFile.keptName(for: url)) }
                        try data.write(to: url, options: .atomic)
                    }
                }.value
                working = false
                switch outcome {
                case .success:
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    close()
                case let .failure(error): problem = error.localizedDescription
                }
            }
        }
    }
}
