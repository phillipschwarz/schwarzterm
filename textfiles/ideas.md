# schwarzterm — Development Ideas

Ten ideas for improving and extending schwarzterm, ordered roughly by implementation effort.

---

## 1. Fix Keyboard Shortcuts via NSMenu Key Equivalents

The most impactful quick win. Wire `Cmd+F` (find), `Cmd+W` (close tab), `Cmd+T` (new tab), and `Cmd+'['/']'` (cycle tabs) through `NSMenuItem` key equivalents rather than `keyDown` overrides. Menu items route through the responder chain regardless of who holds first responder, so they fire even when `STTextView` is active. This unblocks the find bar and makes tab management keyboard-friendly.

---

## 2. Auto-Save Layout on Window Close

The layout JSON is never written on quit, so pane sizes reset every launch. Hook into `windowWillClose` in `MainWindowController`, call `LayoutManager.shared.saveLayout(currentLayout)`, and capture the current divider fractions from each `SplitViewController`. This is a small change with high daily-use value.

---

## 3. Syntax Highlighting for Swift, TypeScript, Rust, Go

`syntax.md` already defines the architecture and color palette for five languages. The natural next step is adding highlighters for the languages most used in the project itself: Swift (the host language), TypeScript, Rust, and Go. Each is a new struct conforming to `SyntaxHighlighter` with a pattern table — no architectural changes needed. Alternatively, replace the regex-based system with Neon + SwiftTreeSitter for accurate, incremental highlighting as planned in Phase 4.

---

## 4. Settings UI Panel

There is no settings UI; changes require manually editing `config.json` and restarting. Add a preferences window (`NSWindowController` with a tab view) covering: font picker, font size stepper, shell picker, terminal foreground/background color wells, and a live preview. Bind all controls to `ConfigManager.shared.config` and apply changes immediately so a restart is not required.

---

## 5. Git Pane

A read-only (then read-write) Git status pane would make schwarzterm a self-contained dev environment. Phase 1: show `git status` output as a structured list (modified, staged, untracked) using `libgit2` via a Swift wrapper or by shelling out to `git`. Phase 2: diff viewer with side-by-side or inline highlighting. Phase 3: stage/unstage, commit, branch switching. The pane fits naturally into the layout system as a new `PaneType`.

---

## 6. Project-Wide Search Pane

A `grep`/`ripgrep`-backed search pane that lets the user search across all files in the current file pane root. Results shown as a grouped list (file → matching lines). Clicking a result opens the file in the editor and scrolls to the line. Can be implemented by shelling out to `rg` or by a pure-Swift recursive search. Wire it to a keyboard shortcut (`Cmd+Shift+F`) via `NSMenuItem`.

---

## 7. Multiple Terminal Tabs with Naming and Color Labels

The terminal pane already supports multiple tabs but they are unnamed. Let users double-click a tab to rename it and right-click to assign a color label (similar to iTerm2 profiles). Store the names and colors in the layout JSON so they persist across launches. This is low-effort but makes multi-session workflows significantly cleaner.

---

## 8. LSP Integration (Autocomplete + Diagnostics)

Connect the editor to Language Server Protocol servers (e.g. `sourcekit-lsp` for Swift, `pylsp` for Python). Use `LanguageClient` (a Swift LSP client library) to: show inline diagnostics as red/yellow underlines, provide autocomplete via `NSTextView`'s completion panel, and support go-to-definition (open file at line). This is the largest feature on the list but transforms the editor from a viewer into a real IDE.

---

## 9. Split Editor Panes

Allow the editor area to be split horizontally or vertically into two independent editor panes, each with its own tab bar. This mirrors VS Code's split editor and lets users view two files side by side. The layout system's recursive `PaneLayout` tree already supports arbitrary nesting — the change is in EditorPaneVC to support being split, and adding a context-menu or button to trigger the split.

---

## 10. AI Assistant Pane (Claude Integration)

Add an optional pane that hosts a Claude conversation context-aware of the current project. The pane can: receive the currently open file as context (via a "Send to AI" button in the editor tab bar), display streamed responses with Markdown rendering, and emit `e <file>` or apply diffs directly to open documents. Uses the Anthropic API with `claude-sonnet-4-6` as the default model. Already listed as a future extension in `plan.md` — this idea fleshes out the implementation approach.

---

*Last updated: 2026-03-18*
