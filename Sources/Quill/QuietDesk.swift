import SwiftUI
import AppKit
import Combine

/// Fades the writing desk to a faint ghost during steady typing (see `DeskQuieting`). It fades in place, so the page
/// never moves, and it stays clickable and readable to VoiceOver throughout.
struct QuietWhileTyping: ViewModifier {
    /// Fires on each keystroke in the editor.
    let typing: PassthroughSubject<Void, Never>
    /// The desk is showing and the setting is on.
    let enabled: Bool
    @ObservedObject private var assistive = AssistiveTechnology.shared
    @Environment(\.colorSchemeContrast) private var contrast
    /// Held by reference so keystrokes that don't change anything don't redraw the desk.
    @State private var tracker = Tracker()
    @State private var quiet = false

    private final class Tracker { var state = DeskQuieting() }

    /// Anyone moving through the desk with the keyboard or VoiceOver needs to see it, so for them it never fades.
    private var active: Bool { enabled && !assistive.keepsToolbarVisible }

    func body(content: Content) -> some View {
        content
            // With Increase Contrast the desk never fades below something you can still read.
            .opacity(quiet ? (contrast == .increased ? 0.45 : 0.15) : 1)
            .quietAnimation(quiet ? .easeInOut(duration: 1.2) : .easeOut(duration: 0.18), value: quiet)
            .background(WindowPointerWatch(
                moved: { point in if tracker.state.pointer(x: point.x, y: point.y) { quiet = false } },
                clicked: { if tracker.state.wake() { quiet = false } }))
            .onReceive(typing) { _ in
                guard active, tracker.state.keystroke(at: ProcessInfo.processInfo.systemUptime) else { return }
                quiet = true
            }
            .onChange(of: active) { _, on in
                if !on { tracker.state.wake(); quiet = false }
            }
    }
}

/// Hears every movement and click of the mouse in its window, wherever the pointer is, without taking any of them.
struct WindowPointerWatch: NSViewRepresentable {
    let moved: (CGPoint) -> Void
    let clicked: () -> Void
    func makeNSView(context: Context) -> WindowPointerWatchView {
        let view = WindowPointerWatchView()
        view.moved = moved; view.clicked = clicked
        return view
    }
    func updateNSView(_ view: WindowPointerWatchView, context: Context) { view.moved = moved; view.clicked = clicked }
}

final class WindowPointerWatchView: NSView {
    var moved: ((CGPoint) -> Void)?
    var clicked: (() -> Void)?
    private var monitor: Any?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        guard let window else { return }
        window.acceptsMouseMovedEvents = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            switch event.type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown: self.clicked?()
            default: self.moved?(event.locationInWindow)
            }
            return event
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }
}
