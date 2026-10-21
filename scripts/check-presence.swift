import Foundation

@main enum PresenceChecks {
    static func main() {
        precondition(PresenceRule.inUse(active: true, hidden: false, onScreen: true), "In front and on screen is in use")
        precondition(!PresenceRule.inUse(active: false, hidden: false, onScreen: true), "Another app in front: Sable rests, even on a second screen")
        precondition(!PresenceRule.inUse(active: true, hidden: true, onScreen: true), "Hidden: Sable rests")
        precondition(!PresenceRule.inUse(active: true, hidden: false, onScreen: false), "Every window minimized or covered: Sable rests")
        print("Presence checks passed")
    }
}
