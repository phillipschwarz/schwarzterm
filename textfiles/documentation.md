# schwarzterm — Documentation

> **Version:** 0.2 (in development)
> **Platform:** macOS
> **Language:** Swift 5.9+, AppKit
> **Last updated:** 2026-03-18

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Panes](#panes)
   - [Terminal Pane](#terminal-pane)
   - [Editor Pane](#editor-pane)
   - [File Pane](#file-pane)
5. [Layout System](#layout-system)
6. [Configuration](#configuration)
7. [Notifications](#notifications)
8. [Shell Integration](#shell-integration)
9. [Keyboard Shortcuts](#keyboard-shortcuts)
10. [Syntax Highlighting](#syntax-highlighting)
11. [Editor Features](#editor-features)
12. [External Dependencies](#external-dependencies)
13. [Persistence](#persistence)
14. [Known Limitations](#known-limitations)

---

## Overview

schwarzterm is a native macOS developer tool that unifies a terminal emulator, a code editor, and a file browser into a single window. It is built entirely with AppKit for full control over layout, events, and rendering. There is no SwiftUI.

The three panes operate independently but communicate with each other through `NotificationCenter`, keeping them loosely coupled. The layout is a persistent tree that users can resize freely; positions are restored on the next launch.

---

## Architecture

### High-level structure

```
NSWindow (MainWindowController)
└── Root NSViewController (built by LayoutManager)
    └── SplitViewController (horizontal, 50/50)
        ├── SplitViewController (vertical, 40/60)
        │   ├── FilePaneVC
        │   └── TerminalPaneVC
        └── EditorPaneVC
```

The layout tree is defined by `PaneLayout`, a recursive enum. On launch, `LayoutManager` deserialises the saved JSON tree and builds the matching view controller hierarchy.

### Communication

Panes never hold direct references to each other. All cross-pane communication happens through `NotificationCenter` using the names declared in `Notifications.swift`. This means new panes can be added without modifying existing ones.

### Thread model

All UI work runs on the main thread. `ConfigManager` is a plain class (no actor isolation) accessed only from the main thread. Network and file I/O that could block are either synchronous-on-launch (config load) or dispatched to the main queue from callbacks.

---

## Project Structure

```
schwarzterm/
├── App/
│   ├── AppDelegate.swift           — Entry point, main menu, responder chain stubs, font registration
│   └── MainWindowController.swift  — Window configuration and root VC assembly
│
├── Config/
│   ├── AppConfig.swift             — Codable settings struct (font, shell, colors)
│   ├── ConfigManager.swift         — Singleton; loads/saves config.json
│   └── Notifications.swift         — All Notification.Name constants
│
├── Layout/
│   ├── PaneProtocol.swift          — Protocol all pane VCs conform to
│   ├── PaneLayout.swift            — Recursive layout tree (Codable)
│   ├── LayoutManager.swift         — Builds VC tree from layout; persists layout.json
│   └── SplitViewController.swift   — Two-pane split with proportional resize
│
├── Resources/
│   └── Fonts/
│       ├── JetBrainsMono-Regular.ttf
│       ├── JetBrainsMono-Italic.ttf
│       ├── JetBrainsMono-Bold.ttf
│       └── JetBrainsMono-BoldItalic.ttf
│
└── Panes/
    ├── Terminal/
    │   ├── TerminalPaneVC.swift        — Tab bar + session container
    │   └── TerminalSessionView.swift   — Single PTY session (SwiftTerm wrapper)
    ├── Editor/
    │   ├── EditorPaneVC.swift          — Multi-tab editor, find bar, welcome screen
    │   ├── EditorDocument.swift        — Document model (URL, content, modified flag)
    │   ├── TabBarView.swift            — Custom tab bar (no NSControl subviews)
    │   ├── FindBarView.swift           — Inline search bar
    │   ├── AutoPairHandler.swift       — Auto-closing brackets and quotes
    │   └── Syntax/
    │       ├── SyntaxHighlighter.swift     — Protocol, color palette, factory function
    │       ├── MarkdownHighlighter.swift
    │       ├── PythonHighlighter.swift
    │       ├── HTMLHighlighter.swift
    │       ├── JavaScriptHighlighter.swift
    │       └── CSSHighlighter.swift
    └── FileManager/
        ├── FilePaneVC.swift            — Outline view browser + toolbar + context menu
        ├── FileItem.swift              — Lazy-loading file tree node
        └── FileOperations.swift        — Static CRUD helpers (create, rename, trash, move)
```

---

## Panes

### Terminal Pane

**File:** `Panes/Terminal/TerminalPaneVC.swift` + `TerminalSessionView.swift`

The terminal pane hosts one or more independent shell sessions, each displayed as a `TerminalSessionView`. Only one session is visible at a time; the others remain alive in the background (preserving scrollback and process state). A tab bar at the top lets the user switch between sessions or open new ones.

#### Sessions

Each session (`TerminalSessionView`) is a subclass of SwiftTerm's `LocalProcessTerminalView`. The shell is started in `viewDidAppear` (not `viewDidLoad`) to ensure the view has a valid frame before the PTY is allocated.

The shell process is started with:
- The full login `$PATH` (captured by running the shell with `-l -c "echo $PATH"`)
- A temporary `ZDOTDIR` / `BASH_ENV` pointing to a temp directory containing `.zshrc` / `.bashrc` files that define the `e` and `o` integration functions before sourcing the user's real rc files

If the shell exits, it is automatically restarted after a 500 ms delay.

#### OSC sequences

The terminal intercepts two custom OSC sequences injected by the shell integration functions:

| Code | Emitted by | Effect |
|------|-----------|--------|
| OSC 5000 | `e <file>` shell function | Opens the file in the editor pane and focuses the editor |
| OSC 5001 | `o <dir>` shell function | Navigates the file pane to that directory |

Standard OSC 7 (working directory update, emitted by modern shells) is used to keep the file pane in sync with the terminal's current directory automatically.

---

### Editor Pane

**File:** `Panes/Editor/EditorPaneVC.swift`

The editor pane manages a collection of open files as tabs. Each tab has a persistent `STTextView` + `NSScrollView` that lives for the lifetime of the tab. Switching tabs hides the outgoing scroll view and shows the incoming one — scroll position and undo history are preserved.

#### Tab bar

The tab bar (`TabBarView`) contains no `NSControl` subviews. Titles and the `×` close glyph are drawn manually in `draw(_:)`. Click handling is done in `mouseDown(with:)` which checks whether the click fell inside the stored `closeHitRect` to decide between "select tab" and "close tab".

#### Welcome screen

When no files are open the tab bar is hidden and a welcome screen fills the editor area. The welcome screen disappears as soon as the first tab is opened. If all tabs are closed, the welcome screen returns.

#### Find bar

`Cmd+F` opens the find bar. Search wraps around the document; results are scrolled into view. `Escape` closes the bar.

#### Document model

`EditorDocument` is a thin struct holding a `URL?`, the current content string, and a modified flag. Saving calls `FileManager` directly. Undo/redo is handled entirely by `STTextView`'s built-in undo manager.

---

### File Pane

**File:** `Panes/FileManager/FilePaneVC.swift`

The file pane shows a single-column `NSOutlineView` rooted at a directory. It starts at the user's home directory. The toolbar contains a Home button, an Up button, and a path label.

#### Navigation

- **Double-click a folder** — navigates into it (makes it the new root)
- **Double-click a file** — opens it in the editor pane
- **Home button** — returns to `~`
- **Up button** — moves to the parent directory
- **Terminal sync** — the pane follows the terminal's current directory automatically (debounced 500 ms; ignores `/tmp`, `/private/tmp`, `/var/folders`)
- **`o` command** — navigates immediately without debounce

#### File operations (context menu)

Right-clicking shows:

- **Open in Editor** — opens the selected file in the editor
- **Reveal in Finder** — opens Finder selection
- **New File** — prompts for name, creates empty file in the clicked directory
- **New Folder** — prompts for name, creates directory
- **Rename** — sheet with current name pre-filled
- **Move to Trash** — confirmation dialog, uses `FileManager.trashItem()`

#### File tree model

`FileItem` is an `NSObject` subclass used as outline view items. Children are loaded lazily (on first expansion). On reload, existing `FileItem` objects are reused by matching URL, preserving outline view selection and expansion state. Hidden files (names starting with `.`) are excluded. Entries are sorted with directories first, then alphabetically.

---

## Layout System

**Files:** `Layout/PaneLayout.swift`, `Layout/LayoutManager.swift`, `Layout/SplitViewController.swift`

### PaneLayout

The layout is an `indirect enum` that can represent either a single pane or a split containing two child layouts:

```swift
enum PaneLayout {
    case leaf(PaneType)     // .terminal | .fileManager | .editor
    case split(SplitLayout) // axis, position (0–1), first, second
}
```

### LayoutManager

`LayoutManager.shared` is the single entry point for building the view controller tree. `buildRootViewController()` loads the saved layout JSON (falling back to a hardcoded default), recursively constructs `SplitViewController` and pane VC instances, and applies saved divider positions after the first layout pass.

### SplitViewController

`SplitViewController` wraps a plain `NSSplitView` rather than `NSSplitViewController`. This avoids Auto Layout conflicts that arise when setting divider positions programmatically on `NSSplitViewController`. The delegate enforces a 120 pt minimum for each pane and maintains proportional fractions on window resize.

---

## Configuration

**Files:** `Config/AppConfig.swift`, `Config/ConfigManager.swift`

Settings are stored in `~/Library/Application Support/schwarzterm/config.json`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `fontName` | String | `"JetBrainsMono-Regular"` | Font used in both the terminal and the editor |
| `fontSize` | Double | `13.0` | Font size in points |
| `shell` | String | `$SHELL` or `/bin/zsh` | Shell executable path |
| `terminalBackground` | RGBA object | dark gray | Terminal background color |
| `terminalForeground` | RGBA object | light gray | Terminal foreground color |

There is no settings UI yet. Edit the JSON file directly and restart the app to apply changes.

**Example config.json:**
```json
{
  "fontName": "JetBrainsMono-Regular",
  "fontSize": 14.0,
  "shell": "/bin/zsh",
  "terminalBackground": { "red": 0.08, "green": 0.08, "blue": 0.08, "alpha": 1.0 },
  "terminalForeground": { "red": 0.92, "green": 0.92, "blue": 0.92, "alpha": 1.0 }
}
```

### Font

JetBrains Mono is bundled inside the app (`Resources/Fonts/`). It is registered at launch via `CTFontManagerRegisterFontsForURL` before any views are created. The PostScript names are:

| Weight | PostScript name |
|--------|----------------|
| Regular | `JetBrainsMono-Regular` |
| Italic | `JetBrainsMono-Italic` |
| Bold | `JetBrainsMono-Bold` |
| Bold Italic | `JetBrainsMono-BoldItalic` |

If `fontName` in the config does not resolve to a valid font, both the editor and terminal fall back to `NSFont.monospacedSystemFont`.

---

## Notifications

All notification names are defined as static constants on `Notification.Name` in `Notifications.swift`.

| Name | Posted by | Observed by | `userInfo` | Description |
|------|-----------|-------------|------------|-------------|
| `schwarzterm.openFileInEditor` | `FilePaneVC`, `TerminalSessionView` | `EditorPaneVC` | `"url": URL` | Open (or switch to) a file in the editor |
| `schwarzterm.terminalDirectoryChanged` | `TerminalSessionView` | `FilePaneVC` | `"url": URL` | Terminal's working directory changed (OSC 7) |
| `schwarzterm.openDirectoryInFilePane` | `TerminalSessionView` | `FilePaneVC` | `"url": URL` | Navigate file pane to a directory (`o` command) |
| `schwarzterm.focusTerminal` | `AppDelegate`, `EditorPaneVC` | `TerminalPaneVC` | — | Move keyboard focus to the terminal |
| `schwarzterm.focusEditor` | `AppDelegate`, `TerminalSessionView` | `EditorPaneVC` | — | Move keyboard focus to the editor |

---

## Shell Integration

The `e` and `o` shell functions are injected into the user's shell session at startup via a temporary init file. They do not modify the user's actual `.zshrc` or `.bashrc`.

```sh
# Open a file in the editor pane (focuses the editor automatically)
e path/to/file.txt

# Navigate the file pane to a directory (defaults to current directory)
o
o path/to/directory
```

Both functions resolve the path to an absolute path using `realpath` (or `readlink -f` as fallback) before emitting the OSC sequence, so relative paths work correctly.

After `e <file>` opens a file, focus moves automatically to the editor text view so typing can begin immediately. Use `Cmd+J` to return focus to the terminal.

---

## Keyboard Shortcuts

All shortcuts are wired via `NSMenuItem` key equivalents and route through the AppKit responder chain, so they fire regardless of which pane currently holds focus.

### File

| Shortcut | Action |
|----------|--------|
| `Cmd+S` | Save current document |
| `Cmd+Shift+S` | Save As… |

### View / Editor

| Shortcut | Action |
|----------|--------|
| `Cmd+F` | Open find bar |
| `Cmd+Return` | Insert new line below cursor (regardless of cursor position in line) |

### Tabs

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New editor tab (focused immediately) |
| `Cmd+W` | Close current editor tab |
| `Cmd+]` | Next tab |
| `Cmd+[` | Previous tab |

### Focus

| Shortcut | Action |
|----------|--------|
| `Cmd+E` | Focus editor |
| `Cmd+J` | Focus terminal |

---

## Syntax Highlighting

**Files:** `Panes/Editor/Syntax/`

Syntax highlighting is applied automatically when a file is opened or modified. The language is detected from the file extension. A 150 ms debounce prevents excessive re-highlighting during fast typing; switching tabs triggers an immediate highlight pass.

### Supported languages

| Extension(s) | Highlighter |
|---|---|
| `.md`, `.markdown` | `MarkdownHighlighter` |
| `.py` | `PythonHighlighter` |
| `.html`, `.htm` | `HTMLHighlighter` |
| `.js`, `.mjs` | `JavaScriptHighlighter` |
| `.css` | `CSSHighlighter` |

Files with unrecognised extensions are displayed without highlighting.

### Architecture

`SyntaxHighlighter` is a protocol with a single method:

```swift
func highlight(_ text: String) -> [(NSRange, NSColor)]
```

`makeSyntaxHighlighter(forExtension:)` is the factory function. Each highlighter returns an ordered list of `(range, color)` pairs. These are applied to the `NSTextStorage` inside a `beginEditing()` / `endEditing()` block, resetting all foreground colors first to clear stale attributes.

### Color palette (`SyntaxColor`)

| Role | Color |
|------|-------|
| keyword | blue/lavender |
| string | warm orange |
| comment | mid-grey |
| number | soft green |
| typeName | gold |
| attribute | light green |
| operator | light grey |
| punctuation | mid-grey |

---

## Editor Features

### Auto-pairing

**File:** `Panes/Editor/AutoPairHandler.swift`

Triggered via `STTextViewDelegate.textView(_:shouldChangeTextIn:replacementString:)`.

| Behaviour | Description |
|-----------|-------------|
| Insert pair | Typing `(`, `[`, `{`, `"`, `'`, or `` ` `` inserts the matching closer and places the cursor between them |
| Skip over closer | Typing a closer when the cursor already sits before it advances the cursor instead of inserting a duplicate |
| Delete pair | Pressing Backspace when the cursor is between an empty pair (e.g. `(|)`) deletes both characters |

---

## External Dependencies

Both dependencies are managed via Swift Package Manager.

### SwiftTerm

**Repository:** https://github.com/migueldeicaza/SwiftTerm

Provides the terminal emulator engine: PTY management, VT100/xterm-256color rendering, OSC handler registration, and the `LocalProcessTerminalView` base class.

**Important:** `startProcess` must be called from `viewDidAppear`, not `viewDidLoad`. The terminal requires a valid, non-zero frame before a PTY can be allocated.

### STTextView

**Repository:** https://github.com/krzyzanowskim/STTextView

Provides the code editor view: TextKit 2 rendering, line numbers, selected-line highlight, and the `STTextViewDelegate` protocol for change notifications.

`STTextView.scrollableTextView()` is the designated factory; it returns an `NSScrollView` whose `documentView` is the `STTextView`. The text content is accessed via `tv.text: String?`.

Key delegate methods used:

- `textView(_:shouldChangeTextIn:replacementString:)` — used by `AutoPairHandler` to intercept bracket/quote insertions and deletions
- `textViewDidChangeText(_:)` — used to mark the document modified and schedule a syntax highlight pass

---

## Persistence

| Data | Location | Format | When saved |
|------|----------|--------|-----------|
| Application config | `~/Library/Application Support/schwarzterm/config.json` | JSON | Manually (no auto-save yet) |
| Window layout | `~/Library/Application Support/schwarzterm/layout.json` | JSON | Manually (no auto-save yet) |
| Window frame | NSUserDefaults (via `setFrameAutosaveName`) | Binary plist | Automatically by AppKit |

Both JSON files are created automatically with defaults if they do not exist.

---

## Known Limitations

### Layout not saved on quit

The layout JSON is not written when the window closes. Pane sizes are not restored between sessions (only the window frame position is restored by AppKit automatically).

### No settings UI

Configuration changes require manually editing `config.json` and restarting the app.

### Single window only

The app supports exactly one window. Multiple workspaces or windows are not implemented.

### Syntax highlighting does not span language boundaries

`<script>` and `<style>` blocks inside HTML are not sub-highlighted with JS/CSS rules. Each file is highlighted by a single language pass.
