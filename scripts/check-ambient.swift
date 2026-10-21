import Foundation

@main enum AmbientChecks {
    static func main() {
        func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }
        /// Where Core Animation puts a mote `time` seconds in: its trip, repeated, starting `offset` seconds along.
        func drawn(_ mote: AmbientMote, at time: Double, drift: Double) -> Double {
            let trip = mote.trip(drift: drift)!, period = mote.period(drift: drift)!
            let along = ((trip.offset + time) / period).truncatingRemainder(dividingBy: 1)
            return trip.from + (trip.to - trip.from) * along
        }

        let mote = AmbientMote(x: 0.3, y: 0.25, size: 2, speed: 0.04, phase: 0.5, color: 0)
        precondition(close(mote.height(at: 0, drift: 1), 0.75), "A mote a quarter of the way down starts three quarters up")
        precondition(close(mote.height(at: 5, drift: 1), 0.95), "Rising, it climbs at its speed")
        precondition(close(mote.height(at: 5, drift: -1), 0.55), "Falling, it sinks at its speed")
        precondition(close(mote.height(at: 10, drift: 1), 0.15), "Past the top it comes back in at the bottom")
        precondition(mote.period(drift: 0) == nil && mote.trip(drift: 0) == nil, "No drift, no trip")
        precondition(close(mote.period(drift: -0.2)!, 125), "A slower pace makes a longer trip")

        for drift in [1, 0.2, -0.6, -1] {
            for time in stride(from: 0.0, through: 240, by: 3.7) {
                precondition(close(drawn(mote, at: time, drift: drift), mote.height(at: time, drift: drift)),
                             "The animated trip follows the mote's path (drift \(drift), \(time) s)")
            }
        }

        let cloud = AmbientCloud(x: 0.5, y: 0.4, radius: 0.4, wander: 0.05, period: 200, phase: 0.25, color: 0)
        let size = CGSize(width: 1000, height: 800)
        let start = cloud.center(at: 0, in: size)
        precondition(abs(start.x - 500) < 1e-6 && abs(start.y - 360) < 1e-6, "A cloud starts on its circle at its phase")
        let loop = cloud.center(at: 200, in: size)
        precondition(abs(loop.x - start.x) < 1e-6 && abs(loop.y - start.y) < 1e-6, "…and is back there after one period")
        let half = cloud.center(at: 100, in: size)
        precondition(abs(half.x - 500) < 1e-6 && abs(half.y - 280) < 1e-6, "…and halfway round it's across its circle")

        print("Ambient checks passed")
    }
}
