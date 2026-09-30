import SwiftUI
import UniformTypeIdentifiers

/// Which app opens Markdown (and, separately, plain text) files, with opt-in buttons to make it Sable.
/// Sable never changes this by itself; macOS asks the writer to confirm each change.
@MainActor
final class DefaultAppModel: ObservableObject {
    @Published private(set) var markdown = DefaultAppStatus.none
    @Published private(set) var plainText = DefaultAppStatus.none
    @Published private(set) var message: String?

    init() { refresh() }

    /// Looks again. Called when Sable comes back to the front, so a change made in Finder's Get Info shows up.
    func refresh() {
        let workspace = NSWorkspace.shared
        markdown = DefaultAppStatus.from(current: workspace.urlForApplication(toOpen: .markdownDocument), sable: Bundle.main.bundleURL)
        plainText = DefaultAppStatus.from(current: workspace.urlForApplication(toOpen: .plainText), sable: Bundle.main.bundleURL)
    }

    func makeSableDefault(for type: UTType) {
        message = nil
        Task {
            do { try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type) }
            catch {
                // Declining macOS's confirmation isn't a problem worth reporting.
                let failure = error as NSError
                if !(failure.domain == NSCocoaErrorDomain && failure.code == NSUserCancelledError) {
                    message = "Could not change the default app: \(error.localizedDescription)"
                }
            }
            refresh()
        }
    }
}

struct FileHandlingSettings: View {
    @StateObject private var model = DefaultAppModel()

    var body: some View {
        Section("Markdown files") {
            row("Markdown files open with", status: model.markdown, buttonTitle: "Make Sable the Default for Markdown", type: .markdownDocument)
            Text("Sable never changes this by itself, and macOS asks you to confirm. To switch back, select a Markdown file in Finder, choose File → Get Info, pick another app under Open with, and click Change All.")
                .font(.caption).foregroundStyle(.secondary)
            row("Plain text (.txt) files open with", status: model.plainText, buttonTitle: "Make Sable the Default for Plain Text", type: .plainText)
            Text("Left as it is unless you choose. macOS treats every plain-text file this way, not only .txt.")
                .font(.caption).foregroundStyle(.secondary)
            if let message = model.message { Text(message).font(.caption).foregroundStyle(.red) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
    }

    @ViewBuilder
    private func row(_ title: String, status: DefaultAppStatus, buttonTitle: String, type: UTType) -> some View {
        LabeledContent(title, value: Self.describe(status))
        if !status.isSable {
            Button(buttonTitle) { model.makeSableDefault(for: type) }
        }
    }

    private static func describe(_ status: DefaultAppStatus) -> String {
        switch status {
        case .sable: return "Sable Markdown Writer"
        case let .other(name): return name
        case .none: return "No app chosen"
        }
    }
}

/// The writing folder is optional: choose one, or go without and work on any Markdown file from anywhere.
struct WritingFolderSettings: View {
    @EnvironmentObject private var browser: FolderBrowser
    @State private var problem: String?

    var body: some View {
        Section("Writing folder") {
            LabeledContent("Folder", value: browser.writingFolder?.lastPathComponent ?? "None")
                .help(browser.writingFolder?.path ?? "Sable is working as a plain Markdown editor.")
            HStack {
                Button(browser.writingFolder == nil ? "Choose a Writing Folder…" : "Choose Another…", action: choose)
                if browser.writingFolder != nil {
                    Button("Stop Using a Writing Folder") { browser.forgetWritingFolder() }
                }
            }
            Text(browser.writingFolder == nil
                 ? "Without a writing folder, Sable is a calm Markdown editor: open a file from anywhere and its folder appears in the writing desk."
                 : "Stopping only makes Sable forget the folder. Your files stay where they are.")
                .font(.caption).foregroundStyle(.secondary)
            if let problem { Text(problem).font(.caption).foregroundStyle(.red) }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.title = "Choose your writing folder"
        panel.prompt = "Use Writing Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try browser.choose(url); problem = nil } catch { problem = error.localizedDescription }
        }
    }
}
