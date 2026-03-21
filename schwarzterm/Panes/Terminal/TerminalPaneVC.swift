// Panes/Terminal/TerminalPaneVC.swift
import AppKit
import SwiftTerm

/// Hosts one or more terminal sessions with a tab bar at the top.
/// Only the active session is visible; switching tabs swaps the visible view.
class TerminalPaneVC: NSViewController, PaneProtocol {

    var paneTitle: String { "Terminal" }

    /// Picks the lowest available "Terminal N" number across all panes.
    private static func nextSessionName() -> String {
        var used = Set<Int>()
        for vc in LayoutManager.shared.allPanes() {
            if let term = vc as? TerminalPaneVC {
                for s in term.sessions {
                    if let n = Self.parseSessionNumber(s.sessionName) {
                        used.insert(n)
                    }
                }
            }
        }
        var n = 1
        while used.contains(n) { n += 1 }
        return "Terminal \(n)"
    }

    private static func parseSessionNumber(_ name: String) -> Int? {
        guard name.hasPrefix("Terminal ") else { return nil }
        return Int(name.dropFirst("Terminal ".count))
    }

    // MARK: - UI

    private let tabBar           = TabBarView()
    private let sessionContainer = NSView()

    // MARK: - State

    var sessions: [TerminalSessionView] = []
    var currentIndex: Int = 0

    /// When true, viewDidLoad skips creating a default session.
    /// Set before the view is loaded when the pane is created as a drop target.
    var skipDefaultSession = false

    // MARK: - Drop Zone

    private var dropOverlay: DropZoneOverlayView?

    // MARK: - Lifecycle

    override func loadView() {
        let dropView = PaneDropTargetView()
        dropView.wantsLayer = true
        dropView.layer?.backgroundColor = ThemeManager.shared.current.terminalBackground.nsColor.cgColor
        dropView.dropHandler = self
        dropView.registerForDraggedTypes([.schwarztermTab])
        view = dropView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupSessionContainer()
        if !skipDefaultSession {
            addSession()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(focusTerminalNotification),
            name: .focusTerminal,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeChanged,
            object: nil
        )

        // Drag-and-drop identity
        tabBar.sourcePaneID = UInt(bitPattern: ObjectIdentifier(self))
        tabBar.sourcePaneKind = .terminal
        LayoutManager.shared.registerPane(self)
    }

    deinit {
        LayoutManager.shared.unregisterPane(self)
    }

    @objc private func focusTerminalNotification() {
        focusCurrentSession()
    }

    @objc private func themeDidChange() {
        let t = ThemeManager.shared.current
        view.layer?.backgroundColor = t.terminalBackground.nsColor.cgColor
        for session in sessions {
            session.applyTheme()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // SwiftTerm needs a valid frame before startProcess
        for session in sessions where !session.shellStarted {
            session.startShell()
        }
        focusCurrentSession()
    }

    // MARK: - Setup

    private func setupTabBar() {
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    private func setupSessionContainer() {
        sessionContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sessionContainer)
        NSLayoutConstraint.activate([
            sessionContainer.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            sessionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sessionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sessionContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Session Management

    func addSession() {
        let session = TerminalSessionView(frame: .zero)
        session.translatesAutoresizingMaskIntoConstraints = false
        session.sessionName = TerminalPaneVC.nextSessionName()
        sessions.append(session)
        sessionContainer.addSubview(session)

        // Pin to container (hidden until selected)
        NSLayoutConstraint.activate([
            session.topAnchor.constraint(equalTo: sessionContainer.topAnchor),
            session.bottomAnchor.constraint(equalTo: sessionContainer.bottomAnchor),
            session.leadingAnchor.constraint(equalTo: sessionContainer.leadingAnchor),
            session.trailingAnchor.constraint(equalTo: sessionContainer.trailingAnchor),
        ])

        let newIndex = sessions.count - 1
        switchToSession(newIndex)

        // Start shell immediately if we already have a window
        if viewIfLoaded?.window != nil {
            session.startShell()
            focusCurrentSession()
        }

        refreshTabBar()
    }

    private func switchToSession(_ index: Int) {
        guard index >= 0, index < sessions.count else { return }
        currentIndex = index
        for (i, s) in sessions.enumerated() {
            s.isHidden = (i != currentIndex)
        }
        refreshTabBar()
        focusCurrentSession()
    }

    private func focusCurrentSession() {
        guard currentIndex < sessions.count else { return }
        view.window?.makeFirstResponder(sessions[currentIndex])
    }

    private func removeSession(at index: Int) {
        if sessions.count > 1 {
            sessions[index].removeFromSuperview()
            sessions.remove(at: index)
            let next = min(index, sessions.count - 1)
            switchToSession(next)
            refreshTabBar()
        } else if parent is SplitViewController, hasOtherTerminalPanes() {
            // Last tab in a split pane and other terminal panes exist — collapse
            SplitManager.shared.collapsePane(self)
        } else {
            // Last terminal pane overall — replace with a fresh session
            sessions[index].removeFromSuperview()
            sessions.removeAll()
            addSession()
        }
    }

    /// Returns true if any other TerminalPaneVC exists in the registry.
    private func hasOtherTerminalPanes() -> Bool {
        for vc in LayoutManager.shared.allPanes() {
            if let term = vc as? TerminalPaneVC, term !== self {
                return true
            }
        }
        return false
    }

    // MARK: - Tab Bar

    private func refreshTabBar() {
        let titles = sessions.map { $0.sessionName }
        let modified = sessions.map { _ in false }
        tabBar.setTabs(titles, modified: modified)
        tabBar.selectTab(currentIndex)
        // Terminal must keep at least 1 session — disable drag if only 1
        tabBar.dragEnabled = sessions.count > 1
    }
}

// MARK: - TabBarViewDelegate

extension TerminalPaneVC: TabBarViewDelegate {

    func tabBar(_ bar: TabBarView, didSelectTab index: Int) {
        switchToSession(index)
    }

    func tabBar(_ bar: TabBarView, didCloseTab index: Int) {
        removeSession(at: index)
    }

    func tabBarDidRequestNewTab(_ bar: TabBarView) {
        addSession()
    }
}

// MARK: - PaneDropHandler

extension TerminalPaneVC: PaneDropHandler {

    func handleDraggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let payload = decodePayload(from: sender),
              payload.paneKind == .terminal else { return [] }

        let overlay = DropZoneOverlayView(frame: view.bounds)
        overlay.autoresizingMask = [.width, .height]
        view.addSubview(overlay, positioned: .above, relativeTo: nil)
        dropOverlay = overlay

        let loc = view.convert(sender.draggingLocation, from: nil)
        overlay.updateZone(for: loc)
        return .move
    }

    func handleDraggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let overlay = dropOverlay else { return [] }
        let loc = view.convert(sender.draggingLocation, from: nil)
        overlay.updateZone(for: loc)
        return .move
    }

    func handleDraggingExited(_ sender: NSDraggingInfo?) {
        dropOverlay?.removeFromSuperview()
        dropOverlay = nil
    }

    func handlePrepareForDrag(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = decodePayload(from: sender) else { return false }
        return payload.paneKind == .terminal
    }

    func handlePerformDrag(_ sender: NSDraggingInfo) -> Bool {
        let zone = dropOverlay?.activeZone ?? .none
        dropOverlay?.removeFromSuperview()
        dropOverlay = nil

        guard zone != .none,
              let payload = decodePayload(from: sender) else { return false }

        return SplitManager.shared.executeTabDrop(
            payload: payload,
            targetPane: self,
            zone: zone
        )
    }

    private func decodePayload(from sender: NSDraggingInfo) -> TabDragPayload? {
        guard let data = sender.draggingPasteboard.data(forType: .schwarztermTab),
              let payload = try? JSONDecoder().decode(TabDragPayload.self, from: data) else { return nil }
        return payload
    }
}

// MARK: - TabTransferProtocol

extension TerminalPaneVC: TabTransferProtocol {

    var paneKind: TabDragPayload.PaneKind { .terminal }
    var tabCount: Int { sessions.count }
    var canExtractTab: Bool { sessions.count > 1 }  // must keep at least 1
    var isEmpty: Bool { sessions.isEmpty }

    func extractTab(at index: Int) -> TransferableTab? {
        guard index >= 0, index < sessions.count, sessions.count > 1 else { return nil }
        let session = sessions[index]

        // Detach from view hierarchy but keep the PTY alive
        session.removeFromSuperview()
        sessions.remove(at: index)

        let next = min(index, sessions.count - 1)
        if !sessions.isEmpty {
            switchToSession(next)
        }
        refreshTabBar()

        return .terminal(session: session)
    }

    func insertTab(_ tab: TransferableTab) {
        guard case .terminal(let session) = tab else { return }
        session.translatesAutoresizingMaskIntoConstraints = false
        sessions.append(session)
        sessionContainer.addSubview(session)

        // Re-pin to container
        NSLayoutConstraint.activate([
            session.topAnchor.constraint(equalTo: sessionContainer.topAnchor),
            session.bottomAnchor.constraint(equalTo: sessionContainer.bottomAnchor),
            session.leadingAnchor.constraint(equalTo: sessionContainer.leadingAnchor),
            session.trailingAnchor.constraint(equalTo: sessionContainer.trailingAnchor),
        ])

        switchToSession(sessions.count - 1)
        refreshTabBar()

        // Start shell if not already running and we have a window
        if viewIfLoaded?.window != nil && !session.shellStarted {
            session.startShell()
        }
    }
}

