# schwarzterm — Scheme for AI Assistants

This document explains how to work on this project as an AI assistant (Claude Code or similar).
Read this first, then read `plan.md` and `todo.md`.

---

## What This Project Is

schwarzterm is a macOS-native developer productivity app combining a terminal emulator, file manager,
and code editor in a single window. It is written entirely in Swift using AppKit (not SwiftUI).

The codebase is actively being developed. At any given time it may have known bugs, half-finished
features, or recently changed files. Always read the relevant source files before making changes.

---

## Key Files for AI Assistants

All supporting documentation lives in `textfiles/`. The files in that folder are:

- **`textfiles/plan.md`** — Product and architecture reference
- **`textfiles/documentation.md`** — Full technical documentation for all panes, systems, and APIs
- **`textfiles/todo.md`** — Living bug/task tracker
- **`textfiles/syntax.md`** — Syntax highlighting specs and language patterns
- **`textfiles/ideas.md`** — Development ideas and future directions

### `textfiles/plan.md`
The product and architecture reference. Contains:
- The vision and tech stack decisions (and *why* they were made)
- Known pitfalls and gotchas (e.g. "Runestone is iOS-only", "SwiftTerm needs viewDidAppear")
- The target feature set and directory structure
- Implementation phases (rough sequencing, not strict)

**Use it to:** Understand what the app is supposed to do, why certain libraries were chosen,
and what the intended architecture looks like before touching any code.

### `textfiles/todo.md`
The living bug/task tracker. Contains:
- Known bugs with root cause analysis already done
- Proposed fix options for each bug
- References to the exact files and line numbers involved

**Use it to:** Know what is currently broken before the user tells you. When you fix a bug
from this list, remove or strike it from `textfiles/todo.md`. When you discover a new bug you're not
immediately fixing, add it here with a brief root cause note.

---

## Workflow Expectations

1. **Read before writing.** Never propose changes to a file you haven't read in this session.
   The codebase changes frequently; your training data or summaries may be stale.

2. **Keep `textfiles/todo.md` current.** If you fix a bug, remove it. If you find a new bug while working
   on something else, add it. This file is how problems survive context resets.

3. **Build to verify.** After non-trivial changes, use `BuildProject` to confirm the project
   compiles. Use `XcodeRefreshCodeIssuesInFile` for a faster check on individual files.

4. **Commit when asked.** The user will ask for commits explicitly. When they do, commit all
   modified files with a clear message. Do not commit unbidden.

5. **Respect existing patterns.** This project avoids Combine, prefers async/await, uses
   NotificationCenter for cross-pane communication, and keeps all UI on the main actor.
   Don't introduce new patterns without discussing them.

---

## Architecture in One Paragraph

The window is managed by `MainWindowController`. The layout is a tree of `PaneLayout` nodes
(either a leaf pane or a split containing two children), serialized as JSON and restored on
launch by `LayoutManager`. Each pane is an `NSViewController` conforming to `PaneProtocol`.
The three pane types are `EditorPaneVC`, `FilePaneVC`, and `TerminalPaneVC`. Panes communicate
exclusively via `NotificationCenter` using the names defined in `Notifications.swift` —
they never hold direct references to each other.

---

## Common Gotchas Discovered During Development

- **`NSSplitView` is not flipped.** Coordinate origin is bottom-left. Any custom view that
  needs to receive mouse events inside an `NSSplitView` must override `isFlipped` to return
  `true`, otherwise `hitTest` will return `nil` for all clicks.

- **`NSControl` swallows mouse events.** Never subclass `NSControl` for a custom tab button
  or similar interactive view. Use plain `NSView` with `mouseDown(with:)`.

- **`NSScrollView` blocks `mouseDown` in subviews.** `NSClipView` intercepts events before
  they reach document view subviews. Use manual frame layout on a plain `NSView` instead.

- **`NSTextField` participates in hit testing** even when non-editable. Never embed an
  `NSTextField` in a view that needs to respond to clicks. Draw text manually in `draw(_:)`.

- **`NSViewController.keyDown` is never called** when a descendant view (e.g. `STTextView`)
  holds first responder. Use `NSMenu` key equivalents or a local event monitor instead.

- **SwiftTerm `startProcess` requires a valid frame.** Call it in `viewDidAppear`, not
  `viewDidLoad`. The terminal must be laid out before a PTY can be created.

- **`STTextView.scrollableTextView()`** returns an `NSScrollView` whose `documentView` is
  the `STTextView`. Always cast `documentView` to `STTextView` after calling this factory.
