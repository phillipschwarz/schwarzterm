// Layout/TabTransferProtocol.swift
import AppKit
import STTextView
import SwiftTerm

/// Data that fully describes a transferable tab.
enum TransferableTab {
    case editor(doc: EditorDocument, scrollView: NSScrollView, textView: STTextView)
    case terminal(session: TerminalSessionView)
}

/// Protocol adopted by pane VCs that support tab drag-and-drop.
protocol TabTransferProtocol: NSViewController {
    /// The kind of pane (used for same-type enforcement).
    var paneKind: TabDragPayload.PaneKind { get }

    /// Number of tabs currently in this pane.
    var tabCount: Int { get }

    /// Whether the pane can give up a tab (e.g. terminal must keep >= 1).
    var canExtractTab: Bool { get }

    /// Extract a tab at the given index, removing it from this pane.
    /// The pane updates its own UI after extraction.
    func extractTab(at index: Int) -> TransferableTab?

    /// Insert a previously extracted tab into this pane.
    func insertTab(_ tab: TransferableTab)

    /// Whether this pane is empty (0 tabs) and should be collapsed.
    var isEmpty: Bool { get }
}
