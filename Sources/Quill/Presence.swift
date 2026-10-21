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

    private func refresh() {
        let now = Self.measure()
        if now != inUse { inUse = now }
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
