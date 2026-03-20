// Layout/DragTypes.swift
import AppKit

extension NSPasteboard.PasteboardType {
    /// Identifies a tab drag within schwarzterm.
    static let schwarztermTab = NSPasteboard.PasteboardType("com.schwarzterm.tab-drag")
}

/// Lightweight payload written to the pasteboard during a tab drag.
/// Identifies the source pane and tab index so the drop target can locate them.
struct TabDragPayload: Codable {
    enum PaneKind: String, Codable { case editor, terminal }

    let paneKind: PaneKind
    /// ObjectIdentifier of the source pane VC, serialized as UInt.
    let sourcePaneID: UInt
    /// Index of the tab being dragged within the source pane.
    let tabIndex: Int
}
