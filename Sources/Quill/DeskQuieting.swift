import Foundation

/// When the writing desk steps back. After a few seconds of steady typing it fades to a faint ghost in place, and the
/// first real movement of the pointer (or a click) brings it back. A pause in typing doesn't, so the desk stays out of
/// the way while you think about the next sentence.
struct DeskQuieting {
    static let storageKey = "deskFadeWhileTyping"
    /// How long typing has to keep going before the desk fades.
    static let steadyTyping: TimeInterval = 3
    /// A longer gap between keys ends a run of typing; the next key starts counting again.
    static let longestGap: TimeInterval = 1.5
    /// How far the pointer has to travel, in points, to wake the desk, so a brushed trackpad doesn't.
    static let wakeDistance = 6.0

    private(set) var quiet = false
    private var runStart: TimeInterval?
    private var lastKey: TimeInterval?
    private var lastPointer: (x: Double, y: Double)?
    private var travelled = 0.0

    /// A key went into the page at `time` (seconds on a steady clock). Returns true when this key quiets the desk.
    mutating func keystroke(at time: TimeInterval) -> Bool {
        if let last = lastKey, time >= last, time - last <= Self.longestGap {} else { runStart = time }
        lastKey = time
        guard !quiet, let start = runStart, time - start >= Self.steadyTyping else { return false }
        quiet = true
        travelled = 0
        return true
    }

    /// The pointer moved to (x, y) in the window. Movement adds up until it is enough to count as reaching for the
    /// mouse, which brings the desk back and starts the run of typing over. Returns true when this wakes the desk.
    mutating func pointer(x: Double, y: Double) -> Bool {
        defer { lastPointer = (x, y) }
        guard let last = lastPointer else { return wake() }
        travelled += hypot(x - last.x, y - last.y)
        return travelled >= Self.wakeDistance ? wake() : false
    }

    /// Brings the desk back at once; typing has to start a fresh run to fade it again. Returns true if it was faded.
    @discardableResult
    mutating func wake() -> Bool {
        let was = quiet
        quiet = false
        travelled = 0
        runStart = nil
        lastKey = nil
        return was
    }
}
