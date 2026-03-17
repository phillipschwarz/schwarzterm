# schwarzterm — Project Plan

## Vision

schwarzterm is a macOS-native, all-in-one productivity app for developers. It replaces the need to juggle a terminal, file manager, and code editor by combining all three in a single, configurable window — inspired by tmux's multi-pane philosophy but with a polished native UI.

---

## Tech Stack

### Language: Swift
- Native macOS performance with no overhead
- First-class access to macOS APIs (PTY, file system, window management)
- Strong type safety keeps the codebase maintainable as it grows

### UI Framework: AppKit
AppKit (not SwiftUI) is the right foundation because:
- Complex custom views (terminal renderer, split panes, editor) require fine-grained control
- AppKit's `NSSplitViewController` is battle-tested for resizable multi-pane layouts
- SwiftUI has limitations for low-level text rendering and event handling

### Key Libraries
| Feature | Library | Notes |
|---|---|---|
| Terminal emulator | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Full PTY + VT100/xterm in pure Swift. Must call `startProcess` in `viewDidAppear`, not `viewDidLoad` — needs a valid frame first. |
| Code editor | [STTextView](https://github.com/krzyzanowskim/STTextView) | AppKit-native TextKit 2 replacement with line numbers. Use `STTextView.scrollableTextView()` factory to create the scroll+text pair. The text property is `tv.text: String?`. |
| Syntax highlighting | [Neon](https://github.com/ChimeHQ/Neon) + [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) | Phase 4 addition. Uses ChimeHQ's own tree-sitter ecosystem — NOT simonbs/TreeSitterLanguages (that is Runestone/iOS-only). |
| Build tooling | xcodegen | Generates `.xcodeproj` from `project.yml` |

### Known Pitfalls (lessons from first attempt)
- **Runestone is iOS-only** — requires UIKit, will not compile for macOS. Do not use.
- **simonbs/TreeSitterLanguages is Runestone-only** — incompatible with Neon/SwiftTreeSitter.
- **`NSSplitView` has no `addArrangedSubview`** — that's `NSStackView`. Use `addSubview()` on `NSSplitView` directly, or use `NSSplitViewController` with `addSplitViewItem()`.
- **SwiftTerm needs a valid frame** — call `startProcess` in `viewDidAppear`, never `viewDidLoad`.
- **Metal Toolchain** — must be downloaded separately: `xcodebuild -downloadComponent MetalToolchain`
- **Xcode first launch** — must run `sudo xcodebuild -runFirstLaunch` after installing Xcode.

---

## Core Features (v1.0)

### 1. Pane System
- Every area is a **Pane** — a view controller conforming to `PaneProtocol`
- Panes can be resized by dragging dividers
- Three pane types: `TerminalPane`, `FilePane`, `EditorPane`
- Layout stored as JSON, restored on launch
- New pane types can be added without touching layout engine

### 2. Terminal Pane
- Full PTY terminal via SwiftTerm
- Supports splitting into sub-panes (horizontal)
- Each split is an independent shell session
- Defaults to user's `$SHELL`

### 3. File Manager Pane
- Two-column layout: directory tree (left) + contents (right)
- File operations: Create, Rename, Delete, Copy, Move
- Right-click context menu
- Clicking a file opens it in the EditorPane via `NotificationCenter`

### 4. Editor Pane
- Multi-tab editing with unsaved indicator
- STTextView with line numbers and selected-line highlight
- Syntax highlighting (Phase 4 — Neon + SwiftTreeSitter)
- Languages: Swift, Python, JS, TS, Go, Rust, Markdown, JSON, YAML, Bash
- Find-in-file (Cmd+F)

### 5. Layout System
- Stored in `~/Library/Application Support/schwarzterm/layout.json`
- Default layout:
  ```
  ┌─────────────┬──────────────────────┐
  │  FilePane   │                      │
  │             │     EditorPane       │
  ├─────────────│                      │
  │  Terminal   │                      │
  └─────────────┴──────────────────────┘
  ```
  Left half: FilePane (top 40%) + TerminalPane (bottom 60%)
  Right half: EditorPane (full height)

---

## Architecture

```
schwarzterm/
├── App/
│   ├── AppDelegate.swift              # @main entry point
│   └── MainWindowController.swift     # Owns root window & layout
│
├── Layout/
│   ├── PaneLayout.swift               # Codable layout tree (leaf/split nodes)
│   ├── LayoutManager.swift            # Read/write layout.json, build VC tree
│   └── SplitViewController.swift      # NSSplitViewController wrapper
│
├── Panes/
│   ├── PaneProtocol.swift             # Protocol all panes conform to
│   ├── Terminal/
│   │   ├── TerminalPaneVC.swift       # Hosts NSSplitView of sessions
│   │   └── TerminalSessionView.swift  # Single PTY session (SwiftTerm)
│   ├── FileManager/
│   │   ├── FilePaneVC.swift           # Two-column file browser
│   │   ├── FileItem.swift             # Lightweight file model
│   │   └── FileOperations.swift       # CRUD file operations
│   └── Editor/
│       ├── EditorPaneVC.swift         # Multi-tab editor pane
│       ├── TabBarView.swift           # Custom tab bar UI
│       └── EditorDocument.swift       # One open file / buffer (STTextView)
│
├── Config/
│   ├── AppConfig.swift                # Codable settings struct
│   ├── ConfigManager.swift            # Read/write config.json (@MainActor)
│   └── Notifications.swift            # Shared Notification.Name constants
│
└── Resources/
    └── Assets.xcassets
```

### Key Design Principles
1. **Protocol-based panes** — new pane types implement `PaneProtocol`, no layout engine changes needed
2. **Layout as data** — `PaneLayout` is a serializable tree; easy to save, restore, and script
3. **Decoupled communication** — panes talk via `NotificationCenter`, not direct references
4. **`@MainActor` on UI classes** — all view controllers and UI-touching classes are `@MainActor` for Swift 6 concurrency safety
5. **SPM-only dependencies** — all third-party code via Swift Package Manager

---

## Implementation Phases

### Phase 1 — Foundation
- [ ] Xcode project via xcodegen (`project.yml`)
- [ ] `PaneProtocol`, `SplitViewController`, `LayoutManager`
- [ ] Skeleton window with placeholder panes that actually appear

### Phase 2 — Terminal Pane
- [ ] SwiftTerm integration (`viewDidAppear` shell start)
- [ ] NSSplitView-based session splitting
- [ ] Scrollback + color support

### Phase 3 — File Manager Pane
- [ ] Two-column NSOutlineView + NSTableView layout
- [ ] File operations with context menus
- [ ] "Open in Editor" via NotificationCenter

### Phase 4 — Editor Pane
- [ ] STTextView multi-tab editor
- [ ] Neon + SwiftTreeSitter syntax highlighting
- [ ] Find-in-file

### Phase 5 — Layout Persistence & Config
- [ ] Save/restore layout JSON on close/open
- [ ] Settings panel (font, font size, shell)
- [ ] Keyboard shortcuts

### Phase 6 — Polish
- [ ] App icon
- [ ] Dark/light mode
- [ ] Error handling & edge cases

---

## Future Extensions (post v1.0)

- Git pane (diffs, staging, commit)
- LSP support (autocomplete, diagnostics)
- Multiple windows/workspaces
- Plugin system
- Project-wide search pane
- AI assistant pane (Claude integration)
- Remote SSH sessions

---

*Last updated: 2026-03-17*

