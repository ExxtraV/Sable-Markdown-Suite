import Foundation

@main enum DefaultAppChecks {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("quill-default-app-\(getpid())")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        func makeApp(_ path: String, id: String) throws -> URL {
            let app = root.appendingPathComponent(path, isDirectory: true)
            let contents = app.appendingPathComponent("Contents", isDirectory: true)
            try fm.createDirectory(at: contents, withIntermediateDirectories: true)
            let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundlePackageType": "APPL"]
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
            return app
        }

        let sable = try makeApp("Build/Sable Markdown Writer.app", id: "local.quill.editor")
        let installedSable = try makeApp("Applications/Sable Markdown Writer.app", id: "local.quill.editor")
        let typora = try makeApp("Applications/Typora.app", id: "abnerworks.Typora")

        precondition(DefaultAppStatus.from(current: nil, sable: sable) == .none, "No app chosen")
        precondition(DefaultAppStatus.from(current: sable, sable: sable) == .sable, "Sable itself")
        precondition(DefaultAppStatus.from(current: installedSable, sable: sable) == .sable, "Another copy of Sable, by bundle identifier, not by where it sits")
        precondition(DefaultAppStatus.from(current: typora, sable: sable) == .other(name: "Typora"), "Another app is named without .app")
        precondition(DefaultAppStatus.from(current: typora, sable: sable).isSable == false && DefaultAppStatus.from(current: sable, sable: sable).isSable)
        precondition(DefaultAppStatus.from(current: root.appendingPathComponent("Missing.app"), sable: sable) == .other(name: "Missing"), "An app that isn't there is still named, never mistaken for Sable")
        print("Passed: default app status (none, Sable by bundle identifier, another app).")
    }
}
