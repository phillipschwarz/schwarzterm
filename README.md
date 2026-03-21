# schwarzterm

A native macOS developer tool that combines a terminal emulator, code editor, and file browser in a single window. Built with Swift and AppKit.

---

## Install

### Homebrew (recommended)

```bash
brew tap phillipschwarz/brewedschwarz
brew install --cask schwarzterm
```

### Manual

Download `schwarzterm.zip` from the [latest release](https://github.com/phillipschwarz/schwarzterm/releases/latest), unzip it, and drag `schwarzterm.app` to your Applications folder.

> **Note:** Since the app is not notarized, macOS will show a security warning on first launch. Right-click the app and select "Open", then click "Open" in the dialog. You only need to do this once.

### Build from source

```bash
git clone https://github.com/phillipschwarz/schwarzterm.git
cd schwarzterm
xcodebuild -project schwarzterm.xcodeproj -scheme schwarzterm -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
xattr -cr build/Build/Products/Release/schwarzterm.app
codesign --force --deep --sign - build/Build/Products/Release/schwarzterm.app
open build/Build/Products/Release/schwarzterm.app
```

Requires Xcode and Swift 5.9+.

---

## Features

### Three panes, one window

| Pane | Description |
|------|-------------|
| **Terminal** | Full terminal emulator powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm). Multiple tabs, auto-restart on exit. |
| **Editor** | Multi-tab code editor powered by [STTextView](https://github.com/krzyzanowskim/STTextView). Line numbers, find & replace, undo/redo. |
| **File Browser** | Outline-view file tree with context menu for creating, renaming, and trashing files. |

### Shell integration

Two shell functions are injected automatically into your session — no setup needed:

```bash
e path/to/file.txt   # open a file in the editor
o path/to/directory   # navigate the file browser to a directory
```

The file browser also follows your terminal's working directory automatically.

### Syntax highlighting

Supported languages: **Python**, **JavaScript**, **HTML**, **CSS**, **Markdown**. Files with other extensions display without highlighting.

### Auto-pairing

Typing `(`, `[`, `{`, `"`, `'`, or `` ` `` inserts the matching closer and places the cursor in between. Typing the closer skips over it. Backspace between an empty pair deletes both.

### Keyboard shortcuts

**File**

| Shortcut | Action |
|----------|--------|
| `Cmd+S` | Save |
| `Cmd+Shift+S` | Save As |

**Tabs**

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New editor tab |
| `Cmd+W` | Close tab |
| `Cmd+]` | Next tab |
| `Cmd+[` | Previous tab |

**Navigation**

| Shortcut | Action |
|----------|--------|
| `Cmd+E` | Focus editor |
| `Cmd+J` | Focus terminal |
| `Cmd+F` | Find in file |
| `Cmd+Return` | Insert new line below |

### Configuration

Settings are stored in `~/Library/Application Support/schwarzterm/config.json`. Edit the file and restart the app to apply.

```json
{
  "fontName": "JetBrainsMono-Regular",
  "fontSize": 14.0,
  "shell": "/bin/zsh",
  "terminalBackground": { "red": 0.08, "green": 0.08, "blue": 0.08, "alpha": 1.0 },
  "terminalForeground": { "red": 0.92, "green": 0.92, "blue": 0.92, "alpha": 1.0 }
}
```

[JetBrains Mono](https://www.jetbrains.com/lp/mono/) is bundled with the app.

---

## Update

```bash
brew upgrade --cask schwarzterm
```

## Uninstall

```bash
brew uninstall --cask schwarzterm
brew untap phillipschwarz/schwarzterm
```

---

## License

MIT
