import AppKit
import QuartzCore
import SwiftUI

/// One drifting light. Positions are fractions of the page, measured from the top.
struct AmbientMote: Equatable {
    let x, y, size, speed, phase: Double
    let color: Int

    /// Seconds for one trip up or down the page; nil when it doesn't drift.
    func period(drift: Double) -> Double? { speed * abs(drift) > 0 ? 1 / (speed * abs(drift)) : nil }

    /// Height of the mote above the bottom of the page, as a fraction, `time` seconds in. Rising motes (positive drift) wrap
    /// from the top back to the bottom, falling ones the other way.
    func height(at time: Double, drift: Double) -> Double {
        let fromTop = (y - time * speed * drift).truncatingRemainder(dividingBy: 1)
        return 1 - (fromTop < 0 ? fromTop + 1 : fromTop)
    }

    /// Where its repeating trip starts and ends (fractions above the bottom), and how far into the trip it is at the start.
    func trip(drift: Double) -> (from: Double, to: Double, offset: Double)? {
        guard let period = period(drift: drift) else { return nil }
        let start = height(at: 0, drift: drift)
        return drift > 0 ? (0, 1, start * period) : (1, 0, (1 - start) * period)
    }

    /// The twinkle, between 0.35 and 0.85 of the mote's brightness, as the opacity animation draws it.
    static let twinkleHalfPeriod = Double.pi / 0.6
}

/// One cloud of nebula haze. Its center circles its home point once every `period` seconds.
struct AmbientCloud: Equatable {
    let x, y, radius, wander, period, phase: Double
    let color: Int

    /// The cloud's center `time` seconds in, in points from the top left of a page of `size`.
    func center(at time: Double, in size: CGSize) -> CGPoint {
        let angle = (time / period + phase) * 2 * .pi
        return CGPoint(x: (x + wander * cos(angle)) * size.width, y: (y + wander * sin(angle)) * size.height)
    }
}

/// The drifting motes and nebula clouds behind the page, drawn as layers that Core Animation moves on its own. Sable does
/// no work per frame, so a page left open for hours costs no more than one just opened. `running` false holds every
/// layer exactly where it is, and true carries on from there.
struct AmbientLayers: NSViewRepresentable {
    enum Scene: Equatable {
        case motes([AmbientMote], colors: [NSColor], drift: Double, bokeh: Bool)
        case haze([AmbientCloud], colors: [NSColor], opacity: Double)

        static func == (a: Scene, b: Scene) -> Bool {
            switch (a, b) {
            case let (.motes(m1, c1, d1, b1), .motes(m2, c2, d2, b2)): return m1 == m2 && same(c1, c2) && d1 == d2 && b1 == b2
            case let (.haze(h1, c1, o1), .haze(h2, c2, o2)): return h1 == h2 && same(c1, c2) && o1 == o2
            default: return false
            }
        }

        /// Colors compared by value, since SwiftUI hands over a new color object on every update.
        private static func same(_ a: [NSColor], _ b: [NSColor]) -> Bool {
            func values(_ color: NSColor) -> [CGFloat] {
                guard let rgb = color.usingColorSpace(.sRGB) else { return [] }
                return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent]
            }
            return a.count == b.count && zip(a, b).allSatisfy { values($0) == values($1) }
        }
    }

    let scene: Scene
    let running: Bool

    func makeNSView(context: Context) -> AmbientLayerView { AmbientLayerView() }

    func updateNSView(_ view: AmbientLayerView, context: Context) {
        view.show(scene)
        view.setRunning(running)
    }
}

final class AmbientLayerView: NSView {
    private var scene: AmbientLayers.Scene?
    private var builtSize: CGSize = .zero
    private var running = true
    /// Holds the lights and carries the clock that pauses them, apart from the layer AppKit manages for the view.
    private let host = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(host)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func show(_ scene: AmbientLayers.Scene) {
        guard scene != self.scene else { return }
        self.scene = scene
        rebuild()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if host.superlayer == nil { layer?.addSublayer(host) }
        host.frame = bounds
        CATransaction.commit()
        if bounds.size != builtSize { rebuild() }
    }

    /// Pausing and resuming as Apple's Technical Q&A QA1673 describes: the layer's clock stops at the moment it pauses
    /// and starts again from that moment.
    func setRunning(_ wanted: Bool) {
        guard wanted != running else { return }
        running = wanted
        let layer = host
        if wanted {
            let pausedAt = layer.timeOffset
            layer.speed = 1
            layer.timeOffset = 0
            layer.beginTime = 0
            layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
        } else {
            let now = layer.convertTime(CACurrentMediaTime(), from: nil)
            layer.speed = 0
            layer.timeOffset = now
        }
    }

    private func rebuild() {
        guard let scene, bounds.width > 0, bounds.height > 0 else { return }
        builtSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // New animations start on a running clock, then the pause, if any, is put back.
        let wasRunning = running
        if !wasRunning { setRunning(true) }
        host.sublayers?.forEach { $0.removeFromSuperlayer() }
        switch scene {
        case let .motes(motes, colors, drift, bokeh): addMotes(motes, colors: colors, drift: drift, bokeh: bokeh, to: host)
        case let .haze(clouds, colors, opacity): addClouds(clouds, colors: colors, opacity: opacity, to: host)
        }
        if !wasRunning { setRunning(false) }
        CATransaction.commit()
    }

    /// A color whose alpha can be read and changed, whatever kind SwiftUI handed over.
    private static func rgb(_ color: NSColor) -> NSColor { color.usingColorSpace(.sRGB) ?? color }

    private func addMotes(_ motes: [AmbientMote], colors: [NSColor], drift: Double, bokeh: Bool, to host: CALayer) {
        let height = bounds.height
        let brightness = bokeh ? 0.22 : 0.55
        for mote in motes {
            let color = Self.rgb(colors[mote.color % colors.count])
            let dot: CALayer
            if bokeh {
                let soft = CAGradientLayer()
                soft.type = .radial
                soft.colors = [color.cgColor, color.withAlphaComponent(color.alphaComponent * 0.55).cgColor, color.withAlphaComponent(0).cgColor]
                soft.locations = [0, 0.55, 1]
                soft.startPoint = CGPoint(x: 0.5, y: 0.5)
                soft.endPoint = CGPoint(x: 1, y: 1)
                dot = soft
            } else {
                dot = CALayer()
                dot.backgroundColor = color.cgColor
                dot.cornerRadius = mote.size / 2
            }
            dot.bounds = CGRect(x: 0, y: 0, width: mote.size, height: mote.size)
            dot.position = CGPoint(x: mote.x * bounds.width, y: mote.height(at: 0, drift: drift) * height)
            dot.opacity = Float(brightness * 0.6)
            host.addSublayer(dot)

            if let trip = mote.trip(drift: drift), let period = mote.period(drift: drift) {
                let travel = CABasicAnimation(keyPath: "position.y")
                travel.fromValue = trip.from * height
                travel.toValue = trip.to * height
                travel.duration = period
                travel.timeOffset = trip.offset
                travel.repeatCount = .infinity
                dot.add(travel, forKey: "travel")
            }
            let twinkle = CABasicAnimation(keyPath: "opacity")
            twinkle.fromValue = brightness * 0.35
            twinkle.toValue = brightness * 0.85
            twinkle.duration = AmbientMote.twinkleHalfPeriod
            twinkle.timeOffset = mote.phase * 2 * AmbientMote.twinkleHalfPeriod
            twinkle.autoreverses = true
            twinkle.repeatCount = .infinity
            twinkle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dot.add(twinkle, forKey: "twinkle")
        }
    }

    private func addClouds(_ clouds: [AmbientCloud], colors: [NSColor], opacity: Double, to host: CALayer) {
        let size = bounds.size
        let span = max(size.width, size.height)
        // Points on the cloud's circle, flipped to Core Animation's bottom-up coordinates.
        let steps = 48
        func point(_ cloud: AmbientCloud, at time: Double) -> CGPoint {
            let center = cloud.center(at: time, in: size)
            return CGPoint(x: center.x, y: size.height - center.y)
        }
        for cloud in clouds {
            let color = Self.rgb(colors[cloud.color % colors.count])
            let radius = cloud.radius * span
            let glow = CAGradientLayer()
            glow.type = .radial
            glow.colors = [color.withAlphaComponent(opacity).cgColor, color.withAlphaComponent(opacity * 0.45).cgColor, color.withAlphaComponent(0).cgColor]
            glow.locations = [0, 0.45, 1]
            glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            glow.endPoint = CGPoint(x: 1, y: 1)
            glow.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
            glow.position = point(cloud, at: 0)
            host.addSublayer(glow)

            let wander = CAKeyframeAnimation(keyPath: "position")
            wander.values = (0...steps).map { NSValue(point: point(cloud, at: cloud.period * Double($0) / Double(steps))) }
            wander.calculationMode = .cubic
            wander.duration = cloud.period
            wander.repeatCount = .infinity
            glow.add(wander, forKey: "wander")
        }
    }
}
