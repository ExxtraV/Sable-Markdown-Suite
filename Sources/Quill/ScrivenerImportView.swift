import AppKit
import SwiftUI

/// A Scrivener project that has been read and is waiting for the writer to look over before anything is written.
struct ScrivenerImportRequest: Identifiable {
    let id = UUID()
    let project: ScrivenerProject
}

/// File → Import Scrivener Project…: shows what the import will make, lets the writer say where each part of the
/// binder goes, and only then asks where to save. The Scrivener project itself is never changed.
struct ScrivenerImportSheet: View {
    let request: ScrivenerImportRequest
    /// Where the save panel starts, so the new project lands on the writer's desk unless they choose otherwise.
    let writingFolder: URL?
    /// Called with the new Fiction Project once it is written.
    let finished: (URL) -> Void
    let close: () -> Void
    @State private var destinations: [ScrivenerDestination]
    @State private var failure: String?

    init(request: ScrivenerImportRequest, writingFolder: URL?, finished: @escaping (URL) -> Void, close: @escaping () -> Void) {
        self.request = request
        self.writingFolder = writingFolder
        self.finished = finished
        self.close = close
        _destinations = State(initialValue: ScrivenerImportPlanner.suggestedDestinations(for: request.project))
    }

    /// The top-level binder items that hold anything, with their place in the binder.
    private var parts: [(index: Int, item: ScrivenerItem, contents: String)] {
        request.project.binder.enumerated().compactMap { index, item in
            let contents = ScrivenerImportPlanner.contentsDescription(of: item)
            return contents == "Empty" ? nil : (index, item, contents)
        }
    }

    var body: some View {
        let plan = ScrivenerImportPlanner.plan(request.project, destinations: destinations)
        let hasContent = plan.files.count > 1
        VStack(alignment: .leading, spacing: 14) {
            Text("Import “\(request.project.title)” from Scrivener").font(.title3.weight(.semibold)).accessibilitySectionHeading()

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.summary).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                if let skipped = plan.skippedSummary {
                    Text(skipped + ". They are copied into the project where possible, and listed in Import Report.md.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 6) {
                Text("Where each part of the binder goes").font(.callout.weight(.medium)).accessibilitySectionHeading()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(parts, id: \.index) { part in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ScrivenerImportPlanner.displayTitle(part.item)).lineLimit(1).truncationMode(.middle)
                                    Text(part.contents).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Picker("Destination for \(ScrivenerImportPlanner.displayTitle(part.item))", selection: $destinations[part.index]) {
                                    ForEach(ScrivenerDestination.allCases) { Text($0.title).tag($0) }
                                }
                                .labelsHidden().frame(width: 150)
                                .accessibilityValue(destinations[part.index].title)
                            }
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .opacity(destinations[part.index] == .skip ? 0.6 : 1)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 260)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("Everything sent to Manuscript becomes chapters, in binder order: a folder of scenes is one chapter file. Notes keeps folders as they are.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            if let failure {
                Text(failure).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("Your Scrivener project isn’t changed. Sable makes a new folder of Markdown files" + (writingFolder.map { ", in “\($0.lastPathComponent)” unless you choose somewhere else." } ?? ".")).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button("Choose Where to Save…") { save(plan) }
                    .keyboardShortcut(.defaultAction).disabled(!hasContent)
                    .accessibilityHint("Asks for a name and place, then writes the new Fiction Project")
            }
        }
        .padding(22).frame(width: 560)
    }

    private func save(_ plan: ScrivenerImportPlan) {
        let panel = NSSavePanel()
        panel.title = "Save the Imported Project"
        panel.message = writingFolder == nil ? "Sable makes a new folder with this name for the Fiction Project."
            : "Sable makes a new folder with this name for the Fiction Project. Saved inside your writing folder, it stays on your desk."
        if let writingFolder { panel.directoryURL = writingFolder }
        panel.prompt = "Import"
        panel.nameFieldLabel = "Project name:"
        panel.nameFieldStringValue = ScrivenerImportPlanner.fileName(for: request.project.title)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            finished(try ScrivenerImportWriter.write(plan, project: request.project, to: destination))
        } catch {
            failure = "Could not import: \(error.localizedDescription)"
        }
    }
}

/// The first step: choosing the Scrivener project and reading it.
@MainActor enum ScrivenerImportStarter {
    /// Nil when the writer cancels. Throws when what they chose can't be read.
    static func choose() throws -> ScrivenerImportRequest? {
        let panel = NSOpenPanel()
        panel.title = "Import a Scrivener Project"
        panel.message = "Choose a Scrivener project (its name ends in .scriv). Sable reads it and makes a new Fiction Project; the Scrivener project isn’t changed."
        panel.prompt = "Continue"
        // A .scriv is a folder that Finder shows as one file when Scrivener is installed, and as a folder when not.
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let source = panel.url else { return nil }
        guard source.pathExtension.lowercased() == "scriv" else { throw ScrivenerError.notPackage }
        return ScrivenerImportRequest(project: try ScrivenerReader.read(source))
    }
}
