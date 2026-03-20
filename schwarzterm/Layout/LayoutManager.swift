// Layout/LayoutManager.swift
import AppKit

class LayoutManager {
    static let shared = LayoutManager()

    // MARK: - Pane Registry

    /// Maps ObjectIdentifier (as UInt) → pane VC for drag-and-drop lookups.
    private var paneRegistry: [UInt: NSViewController] = [:]

    func registerPane(_ vc: NSViewController) {
        paneRegistry[UInt(bitPattern: ObjectIdentifier(vc))] = vc
    }

    func unregisterPane(_ vc: NSViewController) {
        paneRegistry.removeValue(forKey: UInt(bitPattern: ObjectIdentifier(vc)))
    }

    func pane(forID id: UInt) -> NSViewController? {
        paneRegistry[id]
    }

    func allPanes() -> [NSViewController] {
        Array(paneRegistry.values)
    }

    private var layoutURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("schwarzterm", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("layout.json")
    }

    private init() {}

    // MARK: - Public

    func buildRootViewController() -> NSViewController {
        let layout = loadLayout()
        let vc = buildViewController(from: layout)
        // After first layout pass, set divider positions
        Task { @MainActor in
            self.applyPositions(layout: layout, vc: vc)
        }
        return vc
    }

    func saveLayout(_ layout: PaneLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        try? data.write(to: layoutURL)
    }

    // MARK: - Private

    private func loadLayout() -> PaneLayout {
        return .defaultLayout
    }

    private func buildViewController(from layout: PaneLayout) -> NSViewController {
        switch layout {
        case .leaf(let type):
            return makePaneVC(type)
        case .split(let s):
            let first = buildViewController(from: s.first)
            let second = buildViewController(from: s.second)
            let vertical = (s.axis == .horizontal) // horizontal split = vertical divider = side by side
            return SplitViewController(first: first, second: second, vertical: vertical)
        }
    }

    private func applyPositions(layout: PaneLayout, vc: NSViewController) {
        guard case .split(let s) = layout,
              let split = vc as? SplitViewController else { return }
        split.setInitialPosition(s.position)
        applyPositions(layout: s.first, vc: split.children[0])
        applyPositions(layout: s.second, vc: split.children[1])
    }

    private func makePaneVC(_ type: PaneLayout.PaneType) -> NSViewController {
        let vc: NSViewController
        switch type {
        case .terminal:     vc = TerminalPaneVC()
        case .fileManager:  vc = FilePaneVC()
        case .editor:       vc = EditorPaneVC()
        }
        registerPane(vc)
        return vc
    }

    // MARK: - Layout Capture (VC tree → PaneLayout)

    /// Walk the live view controller tree and produce a PaneLayout.
    func captureLayout(from vc: NSViewController) -> PaneLayout {
        if let split = vc as? SplitViewController {
            let axis: PaneLayout.SplitLayout.Axis = split.isVertical ? .horizontal : .vertical
            let position = split.currentFraction
            return .split(.init(
                axis: axis,
                position: position,
                first: captureLayout(from: split.firstVC),
                second: captureLayout(from: split.secondVC)
            ))
        } else if vc is EditorPaneVC {
            return .leaf(.editor)
        } else if vc is TerminalPaneVC {
            return .leaf(.terminal)
        } else if vc is FilePaneVC {
            return .leaf(.fileManager)
        } else {
            return .leaf(.editor) // fallback
        }
    }

    /// Capture the current VC tree from the main window and persist it.
    /// Currently disabled — always starts with the default layout.
    func persistCurrentLayout() {
        // no-op
    }
}
