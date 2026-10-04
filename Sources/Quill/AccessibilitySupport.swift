import SwiftUI
import AppKit
import Combine

/// Whether VoiceOver or Full Keyboard Access is on. Neither posts a notification when it changes, so this looks again
/// when the app comes to the front, and watches VoiceOver directly where macOS allows.
@MainActor final class AssistiveTechnology: ObservableObject {
    static let shared = AssistiveTechnology()
    @Published private(set) var voiceOver = NSWorkspace.shared.isVoiceOverEnabled
    @Published private(set) var fullKeyboardAccess = NSApplication.shared.isFullKeyboardAccessEnabled
    private var watching: [AnyCancellable] = []

    private init() {
        NSWorkspace.shared.publisher(for: \.isVoiceOverEnabled).sink { [weak self] on in
            MainActor.assumeIsolated { if self?.voiceOver != on { self?.voiceOver = on } }
        }.store(in: &watching)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }.store(in: &watching)
    }

    func refresh() {
        let voice = NSWorkspace.shared.isVoiceOverEnabled, keys = NSApplication.shared.isFullKeyboardAccessEnabled
        if voiceOver != voice { voiceOver = voice }
        if fullKeyboardAccess != keys { fullKeyboardAccess = keys }
    }

    /// The toolbar that slides away until the pointer comes near can't be found by VoiceOver or the keyboard, so for
    /// anyone using either it stays where it is.
    var keepsToolbarVisible: Bool { voiceOver || fullKeyboardAccess }
}

/// Speaks a short message to VoiceOver, for a change that has no control of its own to announce it (a chapter moved,
/// a mode switched). Does nothing when VoiceOver is off.
@MainActor enum Announce {
    static func say(_ message: String, priority: NSAccessibilityPriorityLevel = .high) {
        guard NSWorkspace.shared.isVoiceOverEnabled, let target = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        NSAccessibility.post(element: target, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: priority.rawValue])
    }
}

/// `withAnimation`, except that Reduce Motion gets the change with no movement.
@MainActor func withQuietAnimation<Result>(_ animation: Animation? = .smooth, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : animation, body)
}

private struct QuietAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: Value
    func body(content: Content) -> some View { content.animation(reduceMotion ? nil : animation, value: value) }
}

private struct PanelFill<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency { shape.fill(Color(nsColor: .windowBackgroundColor)) } else { shape.fill(.regularMaterial) }
        }
    }
}

private struct PanelOutline<S: InsettableShape>: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    let shape: S
    func body(content: Content) -> some View {
        content.overlay {
            if contrast == .increased { shape.strokeBorder(Color.primary.opacity(0.75), lineWidth: 1.25) }
            else { shape.strokeBorder(.separator, lineWidth: 0.5) }
        }
    }
}

extension View {
    /// Like `.animation(_:value:)`, but still when Reduce Motion is on.
    func quietAnimation<Value: Equatable>(_ animation: Animation?, value: Value) -> some View {
        modifier(QuietAnimation(animation: animation, value: value))
    }

    /// The frosted backing for floating panels. With Reduce Transparency on it is the window's solid color instead.
    func panelFill<S: Shape>(in shape: S) -> some View { modifier(PanelFill(shape: shape)) }

    /// A hairline around a floating panel, firmer when Increase Contrast is on.
    func panelOutline<S: InsettableShape>(_ shape: S) -> some View { modifier(PanelOutline(shape: shape)) }

    /// How a heading in the interface is exposed to VoiceOver, so the Headings rotor can jump between them.
    func accessibilitySectionHeading() -> some View { accessibilityAddTraits(.isHeader) }
}
