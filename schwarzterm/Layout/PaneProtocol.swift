// Layout/PaneProtocol.swift
import AppKit

/// All pane view controllers conform to this protocol.
protocol PaneProtocol: NSViewController {
    /// A human-readable title for this pane (shown in drag handles etc.)
    var paneTitle: String { get }
}
