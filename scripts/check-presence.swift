import Foundation

@main enum PresenceChecks {
    static func main() {
        precondition(PresenceRule.inUse(active: true, hidden: false, onScreen: true), "In front and on screen is in use")
        precondition(!PresenceRule.inUse(active: false, hidden: false, onScreen: true), "Another app in front: Sable rests, even on a second screen")
        precondition(!PresenceRule.inUse(active: true, hidden: true, onScreen: true), "Hidden: Sable rests")
        precondition(!PresenceRule.inUse(active: true, hidden: false, onScreen: false), "Every window minimized or covered: Sable rests")

        var clock = MotionClock()
        precondition(clock.time(at: 100) == 100, "A clock that never rested keeps real time")
        clock.rest(at: 110)
        precondition(clock.time(at: 110) == 110 && clock.time(at: 500) == 110, "A resting clock stands still")
        clock.rest(at: 200)
        precondition(clock.time(at: 500) == 110, "Resting twice doesn't move the moment it stopped")
        clock.resume(at: 500)
        precondition(clock.time(at: 500) == 110, "Resuming carries on from the same moment, so nothing jumps")
        precondition(clock.time(at: 510) == 120, "…and then runs at the usual speed")
        clock.resume(at: 600)
        precondition(clock.time(at: 600) == 210, "Resuming a running clock changes nothing")

        print("Presence checks passed")
    }
}
