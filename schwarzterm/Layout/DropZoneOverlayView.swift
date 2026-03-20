// Layout/DropZoneOverlayView.swift
import AppKit

/// The region of a pane where a dragged tab would land.
enum DropZone: Equatable {
    case left, right, top, bottom, center, none
}

// MARK: - Drop Target Handler

/// Closure-based handler that pane VCs set on their root PaneDropTargetView.
/// Keeps drag destination logic in the VC while the view routes the NSView callbacks.
protocol PaneDropHandler: AnyObject {
    func handleDraggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation
    func handleDraggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation
    func handleDraggingExited(_ sender: NSDraggingInfo?)
    func handlePrepareForDrag(_ sender: NSDraggingInfo) -> Bool
    func handlePerformDrag(_ sender: NSDraggingInfo) -> Bool
}

/// Root view for pane VCs. Registers for tab drag types and forwards
/// NSDraggingDestination calls to its `dropHandler`.
class PaneDropTargetView: NSView {
    weak var dropHandler: PaneDropHandler?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropHandler?.handleDraggingEntered(sender) ?? []
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropHandler?.handleDraggingUpdated(sender) ?? []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropHandler?.handleDraggingExited(sender)
    }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropHandler?.handlePrepareForDrag(sender) ?? false
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropHandler?.handlePerformDrag(sender) ?? false
    }
}

/// Semi-transparent overlay shown on a pane during a tab drag.
/// Highlights the zone (left/right/top/bottom/center) under the cursor.
class DropZoneOverlayView: NSView {

    private(set) var activeZone: DropZone = .none

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Update the highlighted zone based on the cursor position (in this view's coords).
    func updateZone(for point: NSPoint) {
        let newZone = zoneForPoint(point)
        if newZone != activeZone {
            activeZone = newZone
            needsDisplay = true
        }
    }

    func reset() {
        activeZone = .none
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard activeZone != .none else { return }
        let rect = highlightRect(for: activeZone)

        // Fill
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        path.fill()

        // Border
        NSColor.controlAccentColor.withAlphaComponent(0.45).setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    // MARK: - Zone Detection

    private func zoneForPoint(_ point: NSPoint) -> DropZone {
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return .none }

        let edgeFraction: CGFloat = 0.30
        let fx = point.x / w
        // NSView y=0 is at the bottom
        let fy = point.y / h

        if fx < edgeFraction { return .left }
        if fx > (1 - edgeFraction) { return .right }
        if fy < edgeFraction { return .bottom }
        if fy > (1 - edgeFraction) { return .top }
        return .center
    }

    /// Returns the rectangle to highlight for a given zone.
    /// Edge zones highlight the corresponding half of the pane.
    private func highlightRect(for zone: DropZone) -> NSRect {
        let inset: CGFloat = 4
        let w = bounds.width
        let h = bounds.height
        switch zone {
        case .left:
            return NSRect(x: inset, y: inset, width: w * 0.5 - inset, height: h - 2 * inset)
        case .right:
            return NSRect(x: w * 0.5, y: inset, width: w * 0.5 - inset, height: h - 2 * inset)
        case .top:
            return NSRect(x: inset, y: h * 0.5, width: w - 2 * inset, height: h * 0.5 - inset)
        case .bottom:
            return NSRect(x: inset, y: inset, width: w - 2 * inset, height: h * 0.5 - inset)
        case .center:
            return bounds.insetBy(dx: inset, dy: inset)
        case .none:
            return .zero
        }
    }
}
