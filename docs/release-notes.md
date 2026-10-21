Sable Markdown Writer 1.0.1 is a small update: Sable no longer keeps working hard while you aren't using it.

**Fixed**

- **Sable rests when you're not using it.** With Sable minimized, covered, or showing on another screen while you worked in a different app, it could still keep about a quarter of a processor core busy. The drifting lights of Arcane, Starfall, and Cosmic kept moving, names kept shimmering, and Sable kept checking your files every second or so. Now all of it pauses the moment you switch away, and picks up where it left off when you come back, so a Sable left open in the background uses next to no power. On a test Mac, Sable in the background went from about 25% CPU in Activity Monitor to about 0%.
- **The drifting lights cost less, too.** They used to redraw at your display's full rate, up to 120 times a second. They now redraw 30 times a second, which keeps them smooth at their slow pace and cut Sable's CPU use with Cosmic in front by about a quarter on the same Mac.

**Good to know**

- The drifting lights now hold still whenever another app is in front, even when Sable is still showing on another screen, so nothing moves at the edge of your eye while you work elsewhere.
- Sable isn't notarized by Apple yet, so a fresh download needs **Open Anyway** in System Settings → Privacy & Security the first time; the README's Install section walks through it.

_Release notes written by Claude Code._
