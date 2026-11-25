**English** | [Türkçe](README.tr.md)

# FloatPlayer

A frameless macOS video window that floats above all desktops and full-screen apps
(Swift + AppKit + WKWebView, built with SwiftPM; Xcode not required).

## Installation

```sh
bash scripts/install.sh     # builds, installs as ~/Applications/FloatPlayer.app and launches it
bash scripts/uninstall.sh   # removes it (--purge: also deletes settings and cookies)
bash scripts/make-app.sh    # only produces dist/FloatPlayer.app
```

## Shortcuts (while the window is focused; all are also in the menu bar menu)

| Shortcut | Action |
| --- | --- |
| ⌘L | Open a URL |
| ⇧⌘V | Open the link on the clipboard directly |
| ⌘R | Reload |
| ⌘P | Show only the player: on ordinary sites the embedded player (e.g. Close/Rapid) fills the window; turn off to pick another source or episode |
| ⌘W | Hide the window (restore it from the menu) |
| ⌘] / ⌘[ | Increase / decrease opacity (30%–100%) |
| ⌘= / ⌘- | Zoom in / out |
| ⌥⌘↓ / ⌥⌘↑ | Crop top-bottom black bars / crop less |
| ⌥⌘→ / ⌥⌘← | Crop side black bars / crop less |
| ⌘0 | Reset zoom and crop |
| ⌘K | Toggle aspect-ratio lock (default 16:9) |
| ⌘1 ⌘2 ⌘3 ⌘4 | Snap to top-left, top-right, bottom-left, bottom-right corner |
| ⌘Q | Quit |

Moving the window: drag from the bar that appears at the top edge, from empty space, or from anywhere while holding ⌘.

## Development

```sh
swift test                                                         # URL translation and window geometry tests (swift-testing)
swift run FloatPlayer --check "https://youtu.be/dQw4w9WgXcQ?t=42"  # verifies the video actually plays
swift run FloatPlayer --check "<url>" --no-referer                 # without a Referer (reproduces Error 153)
swift run FloatPlayer --check "<url>" --layout [--no-focus]        # does the page's player fill the window? (Tests/Fixtures has mock pages)
```

## License

[MIT](LICENSE)
