// Layout/SplitManager.swift
import AppKit

/// Orchestrates tab drag-and-drop: splitting panes, merging tabs, and collapsing empty panes.
class SplitManager {
    static let shared = SplitManager()
    private init() {}

    /// Execute a tab drop. Returns true on success.
    @discardableResult
    func executeTabDrop(
        payload: TabDragPayload,
        targetPane: TabTransferProtocol,
        zone: DropZone
    ) -> Bool {
        guard let sourceVC = LayoutManager.shared.pane(forID: payload.sourcePaneID),
              let sourcePane = sourceVC as? TabTransferProtocol else { return false }

        // Same-type enforcement
        guard sourcePane.paneKind == targetPane.paneKind else { return false }

        // Terminal must keep at least 1 tab
        if sourcePane.paneKind == .terminal && !sourcePane.canExtractTab {
            return false
        }

        // If dropping on self in center zone, nothing to do
        if sourceVC === (targetPane as AnyObject) && zone == .center {
            return false
        }

        // 1. Extract the tab
        guard let tab = sourcePane.extractTab(at: payload.tabIndex) else { return false }

        if zone == .center {
            // Merge into target pane
            targetPane.insertTab(tab)
        } else {
            // Split: create new pane, insert tab, wrap in SplitViewController
            let newPane = makeEmptyPane(kind: payload.paneKind)

            // Force the new pane's view to load so its subviews (sessionContainer,
            // editorStack, etc.) are initialized before insertTab accesses them.
            _ = newPane.view

            guard let newTransfer = newPane as? TabTransferProtocol else { return false }
            newTransfer.insertTab(tab)

            let targetVC = targetPane as NSViewController
            let savedFrame = targetVC.view.frame

            // Determine split direction and ordering
            let isVerticalDivider: Bool   // true = side-by-side
            let newIsFirst: Bool
            // NSSplitView.isFlipped is true, so subview[0] (first) is at the top
            // and subview[1] (second) is at the bottom.
            switch zone {
            case .left:   isVerticalDivider = true;  newIsFirst = true
            case .right:  isVerticalDivider = true;  newIsFirst = false
            case .top:    isVerticalDivider = false; newIsFirst = true
            case .bottom: isVerticalDivider = false; newIsFirst = false
            default: return false
            }

            // Remember which slot targetVC occupies in its parent split before
            // we detach it. We need this to insert the replacement at the right spot.
            let oldParent = targetVC.parent as? SplitViewController
            let wasFirst = (oldParent != nil) ? (oldParent!.firstVC === targetVC) : false

            // Detach targetVC from its current parent so that the new
            // SplitViewController's viewDidLoad can call addChild without
            // conflicting with the old parent.
            targetVC.view.removeFromSuperview()
            targetVC.removeFromParent()

            let first  = newIsFirst ? newPane : targetVC
            let second = newIsFirst ? targetVC : newPane
            let splitVC = SplitViewController(first: first, second: second, vertical: isVerticalDivider)
            splitVC.view.frame = savedFrame

            // Insert the new split into the hierarchy where targetVC used to be
            if let oldParent = oldParent {
                oldParent.insertChild(splitVC, asFirst: wasFirst)
            } else if let window = NSApp.mainWindow {
                window.contentViewController = splitVC
            }

            // Apply the 50/50 split position now that the view has a real frame
            splitVC.setInitialPosition(0.5)
            splitVC.view.layoutSubtreeIfNeeded()
        }

        // Collapse source if empty (editor only — terminal always keeps >= 1)
        if sourcePane.isEmpty {
            collapsePane(sourceVC)
        }

        return true
    }

    // MARK: - Hierarchy Manipulation

    private func replaceInHierarchy(_ old: NSViewController, with new: NSViewController) {
        if let parentSplit = old.parent as? SplitViewController {
            parentSplit.replaceChild(old, with: new)
        } else if let window = old.view.window {
            // old is the root content VC — detach new from its current parent first
            new.view.removeFromSuperview()
            new.removeFromParent()
            new.view.frame = old.view.frame
            window.contentViewController = new
        }
    }

    func collapsePane(_ pane: NSViewController) {
        guard let parentSplit = pane.parent as? SplitViewController else { return }

        // The sibling is the other child
        let sibling: NSViewController
        if parentSplit.firstVC === pane {
            sibling = parentSplit.secondVC
        } else {
            sibling = parentSplit.firstVC
        }

        replaceInHierarchy(parentSplit, with: sibling)
        LayoutManager.shared.unregisterPane(pane)
    }

    private func makeEmptyPane(kind: TabDragPayload.PaneKind) -> NSViewController {
        switch kind {
        case .editor:
            return EditorPaneVC()
        case .terminal:
            let vc = TerminalPaneVC()
            vc.skipDefaultSession = true
            return vc
        }
    }
}
