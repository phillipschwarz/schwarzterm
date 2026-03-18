# schwarzterm — Known Bugs / TODO

## Bugs

*(none currently)*

## Notes

- Editor tab management is now mouse-only: click a tab to select, click × on the selected tab to close, click + on the right of the tab bar to open a new tab.
- Keyboard shortcuts (`keyDown` in `EditorPaneVC`) were removed because `STTextView` holds first responder when the editor is active, so VC-level `keyDown` overrides are never called. If shortcuts are needed in future, use NSMenu key equivalents or a local event monitor.
