import AppKit
import Combine
import SwiftUI

/// Whether Sable is the app you're using right now. The drifting backgrounds, the name shimmer, and the background checks
/// that watch files all rest when it isn't: another app is in front, or every Sable window is minimized, hidden, or covered.
/// A Sable left open on another screen then costs next to nothing, and nothing moves at the edge of your eye while you're
/// elsewhere. Coming back picks everything up at once.
@MainActor final class Presence: ObservableObject {
    static let shared = Presence()
    @Published private(set) var inUse: Bool
    /// Moving backgrounds run on this clock, which stops while Sable rests, so the motes carry on from where they were.
    private var clock = MotionClock()
    private var watching: [AnyCancellable] = []

    private init() {
        inUse = Self.measure()
        let names = [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification, NSApplication.didHideNotification,
                     NSApplication.didUnhideNotification, NSApplication.didChangeOcclusionStateNotification]
        for name in names {
            NotificationCenter.default.publisher(for: name).sink { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }.store(in: &watching)
        }
    }

    /// Seconds of motion so far, for a `TimelineView` date.
    func motionTime(at date: Date) -> TimeInterval { clock.time(at: date.timeIntervalSinceReferenceDate) }

    private func refresh() {
        let now = Self.measure()
        guard now != inUse else { return }
        let time = Date().timeIntervalSinceReferenceDate
        if now { clock.resume(at: time) } else { clock.rest(at: time) }
        inUse = now
    }

    private static func measure() -> Bool {
        let app = NSApplication.shared
        return PresenceRule.inUse(active: app.isActive, hidden: app.isHidden, onScreen: app.occlusionState.contains(.visible))
    }
}

enum PresenceRule {
    /// In front, and at least part of one window can be seen.
    static func inUse(active: Bool, hidden: Bool, onScreen: Bool) -> Bool { active && !hidden && onScreen }
}

/// A clock that stands still while it rests and carries on from the same moment afterward, so motion driven by it never jumps.
struct MotionClock {
    private var restingSince: TimeInterval?
    private var rested: TimeInterval = 0

    mutating func rest(at time: TimeInterval) {
        if restingSince == nil { restingSince = time }
    }

    mutating func resume(at time: TimeInterval) {
        guard let since = restingSince else { return }
        rested += max(0, time - since)
        restingSince = nil
    }

    func time(at time: TimeInterval) -> TimeInterval { (restingSince ?? time) - rested }
}

/// Runs a background check on each tick while Sable is in use, and once straight away on coming back to it, so a file
/// changed meanwhile shows up at once.
private struct InUsePolling<Ticks: Publisher>: ViewModifier where Ticks.Output == Date, Ticks.Failure == Never {
    let ticks: Ticks
    let action: () -> Void
    @ObservedObject private var presence = Presence.shared

    func body(content: Content) -> some View {
        content
            .onReceive(ticks) { _ in if presence.inUse { action() } }
            .onChange(of: presence.inUse) { _, inUse in if inUse { action() } }
    }
}

extension View {
    func whileInUse<Ticks: Publisher>(_ ticks: Ticks, perform action: @escaping () -> Void) -> some View
    where Ticks.Output == Date, Ticks.Failure == Never {
        modifier(InUsePolling(ticks: ticks, action: action))
    }
}
