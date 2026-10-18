import Foundation

@main enum DeskQuietingChecks {
    static func main() {
        /// Types one key every `every` seconds from `start` until `end`, and returns the time the desk went quiet, if it did.
        func type(_ desk: inout DeskQuieting, from start: TimeInterval, to end: TimeInterval, every: TimeInterval = 0.2) -> TimeInterval? {
            var quietAt: TimeInterval?
            for time in stride(from: start, through: end, by: every) where desk.keystroke(at: time) { quietAt = quietAt ?? time }
            return quietAt
        }

        var desk = DeskQuieting()
        precondition(!desk.quiet, "The desk starts awake")
        precondition(type(&desk, from: 0, to: 2.8) == nil && !desk.quiet, "A couple of seconds of typing leaves the desk alone")
        let quietAt = type(&desk, from: 3.0, to: 6)
        precondition(quietAt.map { abs($0 - 3.0) < 1e-9 } == true && desk.quiet, "Three seconds of steady typing quiets the desk")
        precondition(!desk.keystroke(at: 6.2) && desk.quiet, "Further typing reports nothing new and the desk stays quiet")
        precondition(!desk.keystroke(at: 60) && desk.quiet, "A pause in typing doesn't bring the desk back")

        desk = DeskQuieting()
        precondition(type(&desk, from: 0, to: 2) == nil, "A short burst…")
        precondition(type(&desk, from: 4, to: 6) == nil && !desk.quiet, "…a pause, and another short burst don't add up")
        precondition(type(&desk, from: 7.6, to: 12, every: 1.4) != nil, "Slow but steady typing still counts")

        desk = DeskQuieting()
        _ = desk.pointer(x: 100, y: 100)
        _ = type(&desk, from: 0, to: 4)
        precondition(desk.quiet)
        precondition(!desk.pointer(x: 102, y: 101) && !desk.pointer(x: 103, y: 103) && desk.quiet, "A brushed trackpad doesn't wake the desk")
        precondition(desk.pointer(x: 108, y: 106) && !desk.quiet, "Reaching for the mouse brings the desk back")
        precondition(!desk.pointer(x: 300, y: 300), "Moving an awake desk reports nothing new")
        precondition(type(&desk, from: 10, to: 12.8) == nil, "After waking, typing starts a fresh run")
        precondition(type(&desk, from: 13, to: 14) != nil, "…and quiets the desk again after three seconds")

        _ = desk.pointer(x: 300, y: 300)
        precondition(desk.quiet)
        precondition(desk.wake() && !desk.quiet, "A click wakes the desk")
        precondition(!desk.wake(), "Waking an awake desk reports nothing new")

        desk = DeskQuieting()
        precondition(type(&desk, from: 0, to: 2) == nil)
        _ = desk.pointer(x: 0, y: 0)
        _ = desk.pointer(x: 50, y: 0)
        precondition(type(&desk, from: 2.2, to: 4.5) == nil && !desk.quiet, "Using the mouse mid-run starts the run over")

        desk = DeskQuieting()
        _ = desk.keystroke(at: 100)
        precondition(!desk.keystroke(at: 50) && type(&desk, from: 50.2, to: 52.9) == nil, "A clock that steps back starts a new run instead of counting backwards")

        print("Desk quieting checks passed")
    }
}
