import Foundation

/// Which app opens a kind of file, as far as Settings needs to say: Sable, someone else, or nobody.
enum DefaultAppStatus: Equatable {
    case sable
    case other(name: String)
    case none

    /// Apps are compared by bundle identifier, not by where they sit on disk: a copy of Sable in Downloads and one in
    /// Applications are the same app to macOS, and Settings should say "Sable" for either.
    static func from(current: URL?, sable: URL) -> DefaultAppStatus {
        guard let current else { return .none }
        if let id = Bundle(url: current)?.bundleIdentifier, id == Bundle(url: sable)?.bundleIdentifier { return .sable }
        let name = FileManager.default.displayName(atPath: current.path)
        return .other(name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name)
    }

    var isSable: Bool { self == .sable }
}
