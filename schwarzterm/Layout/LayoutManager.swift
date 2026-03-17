// Layout/LayoutManager.swift
import AppKit

class LayoutManager {
    static let shared = LayoutManager()

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
        guard let data = try? Data(contentsOf: layoutURL),
              let layout = try? JSONDecoder().decode(PaneLayout.self, from: data) else {
            return .defaultLayout
        }
        return layout
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
        switch type {
        case .terminal:     return TerminalPaneVC()
        case .fileManager:  return FilePaneVC()
        case .editor:       return EditorPaneVC()
        }
    }
}
