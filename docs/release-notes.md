Sable Markdown Writer 1.0.1 is a small update that fixes Sable using far more of your Mac's processor than it should, both while you write and while you're away.

**Fixed**

- **Sable rests when you're not using it.** With Sable minimized, covered, or showing on another screen while you worked in a different app, it could still keep about a quarter of a processor core busy. The drifting lights of Arcane, Starfall, and Cosmic kept moving, names kept shimmering, and Sable kept checking your files every second or so. Now all of it pauses the moment you switch away, and picks up where it left off when you come back, so a Sable left open in the background uses next to no power. On a test Mac, Sable in the background went from about 25% CPU in Activity Monitor to about 0%.
- **Sable no longer slows down the longer it stays open.** With Arcane, Starfall, or Cosmic, each frame of the drifting lights left a little cleanup work behind, and it piled up: after an hour, Sable could keep half a processor core or more busy while you sat and wrote. The lights and Cosmic's haze are now handed to macOS's own animation system, which moves them without Sable doing anything frame by frame. On a test Mac, Sable in front with Starfall went from about 33% CPU and climbing to about 0.1%, and its memory from about 400 MB to about 70 MB.

**Good to know**

- The drifting lights now hold still whenever another app is in front, even when Sable is still showing on another screen, so nothing moves at the edge of your eye while you work elsewhere.
- Sable isn't notarized by Apple yet, so a fresh download needs **Open Anyway** in System Settings → Privacy & Security the first time; the README's Install section walks through it.

_Release notes written by Claude Code._
