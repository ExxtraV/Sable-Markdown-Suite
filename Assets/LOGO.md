# Sable Markdown Writer logo

The "sleeping curl": a sable asleep, curled nose to tail, with a fountain-pen nib tucked into its body.

## How it was made

Generated with Codex, using its built-in image generator, from a concept the maintainer chose. The animal is raster artwork at the resolution it was generated at, not vector paths, so don't enlarge it much beyond the sizes here. No API key or model setup is needed to use these files, and nothing in the app calls a generator.

Codex produced the tile, a transparent primary logo, a reverse (white body) logo for dark backgrounds, and a simplified black-and-white version for small sizes. The files below are the ones this repository uses, unmodified apart from the size noted. The full kit (lockups, social graphics, website heroes) isn't stored here.

## Files

| File | What it is | Used by |
| --- | --- | --- |
| `sable-icon-light-1024.png` | App-icon master: charcoal mark on a pale rounded tile, 1024 px. | `scripts/build-icon.sh` |
| `sable-icon-small-mark.png` | The mark simplified to black and white, without the gray throat patch. 640 px. | The 16, 32, and 64 px icon sizes |
| `Sable.icns` | The app icon, built from the two files above. | The app bundle (Dock, Finder, About panel) |
| `sable-logo.png` | Transparent logo for light backgrounds. 640 px, downsized from the 1254 px original. | README |
| `sable-logo-reverse.png` | Transparent logo for dark backgrounds. 640 px, downsized the same way. | README (dark mode) |

## How the app icon is built

```
sh scripts/build-icon.sh [master.png]
```

`scripts/render-icon.swift` fits the master tile onto the macOS icon grid instead of scaling it as it comes, so Sable lines up with other apps in the Dock:

- **Large sizes:** an 824-of-1024 body centered in the canvas (a 100 px margin), clipped to a continuous-corner rounded shape and given the standard soft shadow. The corner curve was matched against the system's own Notes icon; the outlines agree to within a few pixels. The tile as generated filled 92% of the canvas, which would have looked about 15% larger than its neighbors.
- **16, 32, and 64 px:** the detailed mark turns to mush, so these sizes use the simplified mark, larger in the tile and centered on what it shows, on a tile that fills the canvas, with a hairline edge so a pale tile still shows against a white window. The eye and nib don't survive at 16 px; the curled silhouette and pale face do.
- **Dark tile:** if the master's background is dark, the renderer reverses the small mark automatically.

Rebuild the icon whenever the master or the renderer changes. `scripts/check-app-icon.swift` fails if `Sable.icns` drifts off the grid, loses a size, or the mark becomes too faint to read.

macOS caches icons. If an old icon lingers after an update, see the note in the README's build section.

## Using the logo

Keep the nose and tail together; that closeness is the identity. Don't rotate, stretch, or crop the animal, and don't put the primary (dark) mark on a dark surface or the reverse on a white one. The name and logo aren't covered by the MIT License; see [TRADEMARK.md](../TRADEMARK.md).
