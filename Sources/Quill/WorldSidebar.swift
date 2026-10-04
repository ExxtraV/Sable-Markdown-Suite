import SwiftUI
import Combine
import QuillCore

/// The writing desk deliberately stays small: one thing at a time. Files and the outline
/// live on separate tabs, so a long file list never buries your headings.
struct WritingSidebar: View {
    /// The open document, compared by revision (see LiveText).
    let text: LiveText
    let commands: EditorCommands
    let chooseFolder: () -> Void
    let currentURL: URL?
    let switchFile: (URL) -> Void
    let showParallel: (URL) -> Void
    var parallelURL: URL? = nil
    var showCard: (URL) -> Void = { _ in }
    var releaseCurrentDocument: () -> Void = {}
    var exportManuscript: () -> Void = {}
    var exportDocument: () -> Void = {}
    var showRevisions: () -> Void = {}
    @EnvironmentObject private var browser: FolderBrowser
    @AppStorage("outlineTitle") private var outlineTitle = "Outline"
    @AppStorage("outlineLevel") private var outlineLevel = 0
    @AppStorage("sidebarTab") private var tab = "files"
    @State private var showOutlineOptions = false
    @State private var showViewOptions = false
    @State private var search = ""

    private var chapters: [ChapterHeading] {
        MarkdownSyntax.headings(in: text.text).filter { outlineLevel == 0 || $0.level == outlineLevel }
    }
    private var outlineName: String {
        let trimmed = outlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Outline" : trimmed
    }
    private enum Section: String { case files, outline, manuscript, recent }
    @AppStorage(RecentFiles.enabledKey) private var showRecent = false
    /// Manuscript is a tab only inside a Fiction Project; Recent only when it has been turned on.
    private var section: Section {
        if tab == "manuscript", browser.projectURL != nil { return .manuscript }
        if tab == "recent", showRecent { return .recent }
        return tab == "outline" ? .outline : .files
    }
    private var showingFiles: Bool { section == .files }

    /// Export is always in reach at the bottom of the desk, so it doesn't take a trip to the Manuscript tab or the File menu.
    private var exportBar: some View {
        HStack {
            if browser.projectURL != nil {
                Menu {
                    Button("Export Manuscript…", action: exportManuscript)
                    Button("Export This Document…", action: exportDocument)
                } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .help("Export the manuscript or this document as PDF, EPUB, Word, or Markdown")
            } else {
                Button(action: exportDocument) { Label("Export…", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.plain).help("Export this document as PDF, EPUB, Word, or Markdown")
            }
            Spacer()
            Button(action: showRevisions) { Label("Revisions", systemImage: "clock.arrow.circlepath") }
                .buttonStyle(.plain).help("Save a snapshot of your draft, see what has changed since, and restore an earlier version")
        }
        .font(.callout).foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var searchPrompt: String {
        switch section {
        case .files: return "Search “\(browser.current?.lastPathComponent ?? "files")”"
        case .outline: return "Search headings"
        case .manuscript: return "Search chapters"
        case .recent: return "Search recent files"
        }
    }

    /// The tabs this desk has right now: Manuscript only inside a Fiction Project, Recent only when turned on.
    private var tabs: [(section: Section, title: String, icon: String)] {
        var list: [(Section, String, String)] = [(.files, "Files", "doc.text"), (.outline, outlineName, "list.bullet")]
        if browser.projectURL != nil { list.append((.manuscript, "Manuscript", "books.vertical")) }
        if showRecent { list.append((.recent, "Recent", "clock")) }
        return list
    }

    private var tabSelection: Binding<String> { Binding(get: { section.rawValue }, set: { tab = $0 }) }

    /// Names if they fit, then icons alone, then a dropdown, so the tabs never spill past the desk's edge however
    /// narrow it is dragged or however many tabs there are (Files, Outline, Manuscript, Recent).
    private var tabStrip: some View {
        ViewThatFits(in: .horizontal) {
            Picker("Writing desk section", selection: tabSelection) {
                ForEach(tabs, id: \.section) { Text($0.title).lineLimit(1).tag($0.section.rawValue) }
            }.pickerStyle(.segmented).labelsHidden().fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity)
            Picker("Writing desk section", selection: tabSelection) {
                ForEach(tabs, id: \.section) { Label($0.title, systemImage: $0.icon).labelStyle(.iconOnly).help($0.title).tag($0.section.rawValue) }
            }.pickerStyle(.segmented).labelsHidden().fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity)
            Picker("Writing desk section", selection: tabSelection) {
                ForEach(tabs, id: \.section) { Text($0.title).tag($0.section.rawValue) }
            }.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                tabStrip
                if section == .files || section == .outline {
                    Button {
                        if showingFiles { showViewOptions.toggle() } else { showOutlineOptions.toggle() }
                    } label: { Image(systemName: "slider.horizontal.3").frame(width: 24, height: 24) }
                        .buttonStyle(.plain).help(showingFiles ? "Sort, layout, and color labels" : "Name and filter your outline")
                        .accessibilityLabel(showingFiles ? "File list options" : "Outline options")
                        .accessibilityHint(showingFiles ? "Opens sorting, layout, and color label choices" : "Opens the outline's name and heading filter")
                        .popover(isPresented: $showViewOptions, arrowEdge: .bottom) { SidebarOptions().environmentObject(browser) }
                        .popover(isPresented: $showOutlineOptions, arrowEdge: .bottom) { OutlineControls() }
                }
            }.padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)

            TextField(searchPrompt, text: $search)
                .textFieldStyle(.roundedBorder).padding(.horizontal, 14).padding(.bottom, 10)
                .accessibilityLabel("Search the writing desk").accessibilityHint(searchPrompt)

            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        switch section {
                        case .files:
                            FolderBrowserSection(currentURL: currentURL, search: search, chooseFolder: chooseFolder,
                                switchFile: switchFile, showParallel: showParallel, parallelURL: parallelURL, showCard: showCard,
                                releaseCurrentDocument: releaseCurrentDocument)
                        case .outline: outline
                        case .recent: RecentTab(currentURL: currentURL, search: search, switchFile: switchFile)
                        case .manuscript: ManuscriptTab(currentURL: currentURL, liveText: text, search: search, switchFile: switchFile, exportManuscript: exportManuscript)
                        }
                    }.padding(.horizontal, 12).padding(.bottom, 16)
                }
                .onChange(of: browser.selection) { _, url in if let url { proxy.scrollTo(url) } }
            }
            Divider()
            exportBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Writing desk")
        .onChange(of: tab) { _, _ in search = "" }
    }

    private var outline: some View {
        VStack(alignment: .leading, spacing: 2) {
            let shown = chapters.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            if chapters.isEmpty {
                Text(outlineLevel == 0 ? "Add # headings to build your outline." : "No level \(outlineLevel) headings yet.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            } else if shown.isEmpty {
                Text("No headings match.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            ForEach(shown) { heading in
                Button { commands.jump(to: heading.range) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(heading.title).font(.system(size: heading.level == 1 ? 13 : 12, weight: heading.level == 1 ? .medium : .regular)).lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, CGFloat(min(heading.level - 1, 3)) * 12)
                    .padding(.vertical, 5).padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(heading.title)
                    .accessibilityValue("Heading level \(heading.level)")
                    .accessibilityHint("Jumps to this heading in your writing")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(outlineName)
    }
}

/// How the file list looks and sorts, plus the words you give each color.
struct SidebarOptions: View {
    @EnvironmentObject private var browser: FolderBrowser
    @AppStorage("sidebarCompact") private var compact = false
    @AppStorage("sidebarShowIcons") private var showIcons = true
    @AppStorage("sidebarShowExtensions") private var showExtensions = false
    @AppStorage("sidebarShowModified") private var showModified = false
    @AppStorage("sidebarShowWords") private var showWords = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("File list").font(.headline).accessibilitySectionHeading()
            VStack(alignment: .leading, spacing: 8) {
                Text("Sort by").font(.caption).foregroundStyle(.secondary)
                Picker("Sort by", selection: $browser.sort) {
                    ForEach(FileSort.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
                Toggle("Folders first", isOn: $browser.foldersFirst)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Show").font(.caption).foregroundStyle(.secondary)
                Toggle("Icons", isOn: $showIcons)
                Toggle("File extensions", isOn: $showExtensions)
                Toggle("Last modified", isOn: $showModified)
                Toggle("Word count", isOn: $showWords)
                Toggle("Compact rows", isOn: $compact)
                RecentTabToggle()
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Color labels").font(.caption).foregroundStyle(.secondary)
                ForEach(MarkColor.allCases, id: \.self) { color in
                    HStack(spacing: 8) {
                        Circle().fill(color.color).frame(width: 10, height: 10).accessibilityHidden(true)
                        TextField(color.name, text: Binding(get: { browser.colorLabels[color] ?? "" }, set: { browser.setLabel($0, for: color) }))
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("What \(color.name) means")
                    }
                }
                Text("Name what each color means to you, like Draft or Revised.").font(.caption).foregroundStyle(.secondary)
            }
            Button("Reset Layout") {
                compact = false; showIcons = true; showExtensions = false; showModified = false; showWords = false
                browser.sort = .name; browser.foldersFirst = true
            }.controlSize(.small)
        }
        .toggleStyle(.checkbox)
        .padding(18).frame(width: 270)
    }
}

// MARK: - Manuscript overview

/// Reads chapter word counts off the main thread, reusing the counts of files that haven't changed.
@MainActor
final class ManuscriptModel: ObservableObject {
    @Published private(set) var chapters: [ChapterStat] = []
    private var task: Task<Void, Never>?

    func reload(folder: URL, order: [String]?) {
        let previous = chapters
        task?.cancel()
        task = Task {
            let loaded = await Task.detached(priority: .utility) { ManuscriptStats.load(folder: folder, order: order, reusing: previous) }.value
            guard !Task.isCancelled, loaded != chapters else { return }
            chapters = loaded
        }
    }

    /// Shows a new order immediately, before the next reload confirms it.
    func apply(order names: [String]) {
        let byName = Dictionary(chapters.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        chapters = names.compactMap { byName[$0] }
    }
}

/// The manuscript at a glance: total words, progress toward a goal, and every chapter in reading order.
/// Chapters can be dragged into a new order, which is saved in the project without touching the files.
private struct ManuscriptTab: View {
    @EnvironmentObject private var browser: FolderBrowser
    let currentURL: URL?
    let liveText: LiveText
    let search: String
    let switchFile: (URL) -> Void
    let exportManuscript: () -> Void
    @StateObject private var model = ManuscriptModel()
    @State private var showGoal = false
    @State private var goalText = ""
    @State private var targetedID: URL?
    @State private var problem: String?
    @FocusState private var focusedChapter: URL?
    private let poll = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private func words(_ chapter: ChapterStat) -> Int {
        // The chapter you're typing in counts live; the rest come from disk.
        chapter.url.standardizedFileURL.path == currentURL?.standardizedFileURL.path ? ManuscriptStats.wordCount(in: liveText.text) : chapter.words
    }
    private var total: Int { model.chapters.reduce(0) { $0 + words($1) } }
    private var goal: Int? { browser.project?.wordGoal }
    private var names: [String] { model.chapters.map(\.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summary
            let shown = model.chapters.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            let longest = max(1, model.chapters.map(words).max() ?? 1)
            if model.chapters.isEmpty {
                Text("No chapters yet. Add one and it will appear here, ready to arrange.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            } else if shown.isEmpty {
                Text("No chapters match.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            VStack(alignment: .leading, spacing: 1) {
                ForEach(shown) { chapter in
                    let index = model.chapters.firstIndex(of: chapter) ?? 0
                    chapterRow(chapter, number: index + 1, longest: longest)
                }
            }
            HStack(spacing: 8) {
                Button(action: newChapter) { Label("New Chapter", systemImage: "plus") }
                Button(action: exportManuscript) { Label("Export…", systemImage: "square.and.arrow.up") }
                    .help("Export the manuscript as PDF, EPUB, Word, or Markdown")
                    .disabled(model.chapters.isEmpty)
            }.buttonStyle(.bordered).controlSize(.small)
            if !model.chapters.isEmpty {
                Text("Drag chapters to rearrange them. Your files aren’t renamed or changed.").font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            if let problem { Text(problem).font(.caption).foregroundStyle(.orange) }
        }
        .onAppear(perform: reload)
        .onReceive(poll) { _ in reload() }
        .onChange(of: browser.project?.chapterOrder) { _, _ in reload() }
        .onChange(of: browser.manuscriptURL) { _, _ in reload() }
        .onChange(of: currentURL) { _, _ in reload() }
    }

    private func reload() {
        guard let folder = browser.manuscriptURL else { return }
        model.reload(folder: folder, order: browser.project?.chapterOrder)
    }

    // MARK: Summary

    private var summary: some View {
        let count = model.chapters.count
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(total.formatted()).font(.system(size: 28, weight: .semibold, design: .serif)).monospacedDigit().accessibilityHidden(true)
                Text(total == 1 ? "word" : "words").font(.system(size: 12)).foregroundStyle(.secondary)
                    .accessibilityLabel("\(total.formatted()) \(total == 1 ? "word" : "words") in the manuscript")
                Spacer(minLength: 0)
                Button { goalText = goal.map(String.init) ?? ""; showGoal = true } label: {
                    Label(goal == nil ? "Set goal" : "Goal", systemImage: "flag").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(Color.accentColor)
                .accessibilityLabel(goal == nil ? "Set a manuscript word goal" : "Manuscript word goal")
                .accessibilityValue(goal.map { "\($0.formatted()) words" } ?? "")
                .popover(isPresented: $showGoal, arrowEdge: .bottom) { goalEditor }
            }
            if let goal {
                let fraction = min(1, Double(total) / Double(goal))
                ProgressView(value: fraction).tint(fraction >= 1 ? .green : .accentColor)
                    .accessibilityLabel("Progress toward the manuscript goal")
                    .accessibilityValue("\(Int((Double(total) / Double(goal) * 100).rounded())) percent of \(goal.formatted()) words")
                HStack {
                    Text("\(Int((Double(total) / Double(goal) * 100).rounded()))% of \(goal.formatted())")
                    Spacer()
                    Text(total >= goal ? "Goal reached" : "\((goal - total).formatted()) to go")
                }.font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            }
            Text(count == 0 ? "No chapters yet" : "\(count) \(count == 1 ? "chapter" : "chapters") · about \((total / count).formatted()) words each")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Manuscript summary")
    }

    private var goalEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manuscript goal").font(.headline)
            TextField("Words", text: $goalText).textFieldStyle(.roundedBorder).onSubmit(saveGoal)
            HStack {
                ForEach([50_000, 80_000, 100_000], id: \.self) { preset in
                    Button(preset.formatted()) { goalText = String(preset) }.controlSize(.small)
                }
            }
            HStack {
                if goal != nil { Button("Remove Goal") { setGoal(nil) } }
                Spacer()
                Button("Save", action: saveGoal).keyboardShortcut(.defaultAction)
            }
            Text("The goal is saved with the project, so it goes wherever the project goes.").font(.caption).foregroundStyle(.secondary)
        }.padding(18).frame(width: 290)
    }

    private func saveGoal() { setGoal(Int(goalText.filter(\.isNumber))) }
    private func setGoal(_ value: Int?) {
        do { try browser.setWordGoal(value); showGoal = false } catch { problem = error.localizedDescription }
    }

    // MARK: Chapters

    private func chapterRow(_ chapter: ChapterStat, number: Int, longest: Int) -> some View {
        let count = words(chapter)
        let isCurrent = chapter.url.standardizedFileURL.path == currentURL?.standardizedFileURL.path
        // A tap rather than a Button, so the whole row starts a drag: a Button keeps the mouse-down to itself.
        let content = HStack(spacing: 8) {
            Text("\(number)").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary).frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.title).font(.system(size: 12, weight: isCurrent ? .medium : .regular)).lineLimit(1)
                GeometryReader { proxy in
                    Capsule().fill(Color.accentColor.opacity(0.35))
                        .frame(width: max(2, proxy.size.width * CGFloat(count) / CGFloat(longest)), height: 3)
                }.frame(height: 3)
            }
            Spacer(minLength: 4)
            Text(count.formatted()).font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.vertical, 6).padding(.horizontal, 8).contentShape(Rectangle())
        .onTapGesture { switchFile(chapter.url) }
        return arrange(describe(content, chapter, number: number, count: count, isCurrent: isCurrent), chapter, number: number, isCurrent: isCurrent)
    }

    /// One element per chapter: "Chapter 3: Title, 1,204 words", with every way of moving it as an action. The row takes
    /// the keyboard too: Return opens it, ↑ and ↓ move between chapters, ⌥↑ and ⌥↓ move the chapter itself.
    private func describe<Row: View>(_ row: Row, _ chapter: ChapterStat, number: Int, count: Int, isCurrent: Bool) -> some View {
        let wordsText = "\(count.formatted()) " + (count == 1 ? "word" : "words")
        let spoken = wordsText + ", position \(number) of \(model.chapters.count)" + (isCurrent ? ", open now" : "")
        return row
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Chapter \(number): \(chapter.title)")
            .accessibilityValue(spoken)
            .accessibilityHint("Opens this chapter. Custom actions move it.")
            .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { switchFile(chapter.url) }
            .accessibilityAction(named: "Move up") { move(chapter, to: number - 2, spoken: true) }
            .accessibilityAction(named: "Move down") { move(chapter, to: number, spoken: true) }
            .accessibilityAction(named: "Move to top") { move(chapter, to: 0, spoken: true) }
            .accessibilityAction(named: "Move to end") { move(chapter, to: model.chapters.count - 1, spoken: true) }
            .focusable().focused($focusedChapter, equals: chapter.url).focusEffectDisabled()
            .onKeyPress(phases: .down) { press in chapterKey(press, chapter: chapter, number: number) }
    }

    /// Dragging, dropping, the menu, and how the row looks while one of them is under way.
    private func arrange<Row: View>(_ row: Row, _ chapter: ChapterStat, number: Int, isCurrent: Bool) -> some View {
        let fill: Color = targetedID == chapter.id ? Color.accentColor.opacity(0.22) : (isCurrent ? Color.accentColor.opacity(0.14) : .clear)
        return row
            .background(fill, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor, lineWidth: focusedChapter == chapter.url ? 2 : 0))
            .draggable(chapter.url)
            .dropDestination(for: URL.self) { urls, _ in reorder(urls, onto: chapter) } isTargeted: { on in
                if on { targetedID = chapter.id } else if targetedID == chapter.id { targetedID = nil }
            }
            .help("Drag to rearrange")
            .contextMenu { chapterMenu(chapter, number: number) }
    }

    @ViewBuilder private func chapterMenu(_ chapter: ChapterStat, number: Int) -> some View {
        Button("Move Up") { move(chapter, to: number - 2) }.disabled(number == 1)
        Button("Move Down") { move(chapter, to: number) }.disabled(number == model.chapters.count)
        Button("Move to Top") { move(chapter, to: 0) }.disabled(number == 1)
        Button("Move to End") { move(chapter, to: model.chapters.count - 1) }.disabled(number == model.chapters.count)
        Divider()
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([chapter.url]) }
    }

    private func chapterKey(_ press: KeyPress, chapter: ChapterStat, number: Int) -> KeyPress.Result {
        let shown = model.chapters.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
        guard let position = shown.firstIndex(of: chapter) else { return .ignored }
        switch press.key {
        case .return, .space:
            switchFile(chapter.url)
        case .upArrow where press.modifiers.contains(.option):
            move(chapter, to: number - 2, spoken: true)
        case .downArrow where press.modifiers.contains(.option):
            move(chapter, to: number, spoken: true)
        case .upArrow:
            guard position > 0 else { return .handled }
            focusedChapter = shown[position - 1].url
        case .downArrow:
            guard position + 1 < shown.count else { return .handled }
            focusedChapter = shown[position + 1].url
        default:
            return .ignored
        }
        return .handled
    }

    private func reorder(_ urls: [URL], onto target: ChapterStat) -> Bool {
        guard let dropped = urls.first, dropped.deletingLastPathComponent().standardizedFileURL.path == target.url.deletingLastPathComponent().standardizedFileURL.path,
              names.contains(dropped.lastPathComponent) else { return false }
        commit(ManuscriptStats.moved(names, dropped.lastPathComponent, to: target.name))
        return true
    }

    private func move(_ chapter: ChapterStat, to index: Int, spoken: Bool = false) {
        let target = names[min(max(0, index), names.count - 1)]
        let order = ManuscriptStats.moved(names, chapter.name, to: target)
        commit(order)
        if spoken, let place = order.firstIndex(of: chapter.name) { Announce.say("\(chapter.title) moved to position \(place + 1) of \(order.count)") }
    }

    private func commit(_ order: [String]) {
        guard order != names else { return }
        problem = nil
        do {
            try browser.setChapterOrder(order)
            withAnimation(.smooth(duration: 0.2)) { model.apply(order: order) }
            browser.reload()
        } catch { problem = "Couldn’t save the new order: \(error.localizedDescription)" }
    }

    private func newChapter() {
        do {
            let url = try browser.createProjectItem(.chapter, named: FictionProject.nextChapterName(in: browser.projectURL ?? URL(fileURLWithPath: "/")))
            reload()
            switchFile(url)
        } catch { problem = error.localizedDescription }
    }
}

/// The optional Recent tab: files you have had open, newest first. Off until you turn it on, and turning it off forgets the list.
struct RecentTab: View {
    let currentURL: URL?
    let search: String
    let switchFile: (URL) -> Void
    @AppStorage(RecentFiles.storageKey) private var stored = ""

    private var files: [URL] {
        RecentFiles.existing(in: stored).filter { search.isEmpty || $0.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if files.isEmpty {
                Text(search.isEmpty ? "Files you open appear here, newest first." : "No recent files match.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            ForEach(files, id: \.self) { url in
                let name = url.deletingPathExtension().lastPathComponent, folder = url.deletingLastPathComponent().lastPathComponent
                let isCurrent = currentURL?.standardizedFileURL == url.standardizedFileURL
                Button { switchFile(url) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name).font(.system(size: 13, weight: isCurrent ? .medium : .regular)).lineLimit(1)
                        Text(folder).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                    }
                    .padding(.vertical, 4).padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isCurrent ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(url.path)
                .accessibilityLabel("\(name), in \(folder)")
                .accessibilityHint("Opens this file")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
            if !stored.isEmpty {
                Button("Clear Recent Files") { stored = "" }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6).padding(.top, 8)
            }
        }
    }
}

/// One switch for the Recent tab, in the desk's options and in Settings. Off by default; turning it off forgets the list.
struct RecentTabToggle: View {
    @AppStorage(RecentFiles.enabledKey) private var enabled = false
    @AppStorage(RecentFiles.storageKey) private var stored = ""

    var body: some View {
        Toggle("Recent tab", isOn: Binding(get: { enabled }, set: { enabled = $0; if !$0 { stored = "" } }))
            .help("Adds a Recent tab to the writing desk with the files you have open. Turning it off forgets the list.")
    }
}
