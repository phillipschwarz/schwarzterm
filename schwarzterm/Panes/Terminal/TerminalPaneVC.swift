// Panes/Terminal/TerminalPaneVC.swift
import AppKit
import SwiftTerm

/// Hosts one or more terminal sessions with a tab bar at the top.
/// Only the active session is visible; switching tabs swaps the visible view.
class TerminalPaneVC: NSViewController, PaneProtocol {

    var paneTitle: String { "Terminal" }

    // MARK: - UI

    private let toolbar          = NSView()
    private let titleLabel       = NSTextField(labelWithString: "Terminal")
    private let addButton        = NSButton()
    private let tabStack         = NSStackView()      // horizontal tab buttons
    private let sessionContainer = NSView()

    // MARK: - State

    private var sessions: [TerminalSessionView] = []
    private var currentIndex: Int = 0

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1).cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
        setupSessionContainer()
        addSession()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(focusTerminalNotification),
            name: .focusTerminal,
            object: nil
        )
    }

    @objc private func focusTerminalNotification() {
        focusCurrentSession()
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

    private func setupToolbar() {
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1).cgColor
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        // Tab stack (scrollable if many tabs)
        tabStack.orientation = .horizontal
        tabStack.spacing = 2
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(tabStack)

        // "+" button on the right
        addButton.title = "+"
        addButton.bezelStyle = .inline
        addButton.isBordered = false
        addButton.contentTintColor = .secondaryLabelColor
        addButton.font = .systemFont(ofSize: 14, weight: .regular)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.target = self
        addButton.action = #selector(addSessionAction)
        toolbar.addSubview(addButton)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 28),

            addButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -8),
            addButton.widthAnchor.constraint(equalToConstant: 20),

            tabStack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            tabStack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 6),
            tabStack.trailingAnchor.constraint(lessThanOrEqualTo: addButton.leadingAnchor, constant: -4),
        ])
    }

    private func setupSessionContainer() {
        sessionContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sessionContainer)
        NSLayoutConstraint.activate([
            sessionContainer.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            sessionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sessionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sessionContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Session Management

    @objc private func addSessionAction() {
        addSession()
    }

    func addSession() {
        let session = TerminalSessionView(frame: .zero)
        session.translatesAutoresizingMaskIntoConstraints = false
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
        guard sessions.count > 1 else { return }   // keep at least one session
        sessions[index].removeFromSuperview()
        sessions.remove(at: index)
        let next = min(index, sessions.count - 1)
        switchToSession(next)
        refreshTabBar()
    }

    // MARK: - Tab Bar

    private func refreshTabBar() {
        // Remove all existing tab buttons
        tabStack.arrangedSubviews.forEach { tabStack.removeArrangedSubview($0); $0.removeFromSuperview() }

        for (i, _) in sessions.enumerated() {
            let btn = makeTabButton(index: i)
            tabStack.addArrangedSubview(btn)
        }
    }

    private func makeTabButton(index: Int) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let btn = NSButton(title: "Terminal \(index + 1)", target: self, action: #selector(tabButtonClicked(_:)))
        btn.tag = index
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.font = .systemFont(ofSize: 11)
        btn.contentTintColor = (index == currentIndex) ? .labelColor : .secondaryLabelColor
        btn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(btn)

        // Close button (only show when more than 1 session)
        if sessions.count > 1 {
            let close = NSButton(title: "×", target: self, action: #selector(closeTabButtonClicked(_:)))
            close.tag = index
            close.bezelStyle = .inline
            close.isBordered = false
            close.font = .systemFont(ofSize: 10)
            close.contentTintColor = .tertiaryLabelColor
            close.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(close)

            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                btn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                close.leadingAnchor.constraint(equalTo: btn.trailingAnchor, constant: 2),
                close.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                close.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
                container.heightAnchor.constraint(equalToConstant: 22),
            ])
        } else {
            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                btn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                btn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                container.heightAnchor.constraint(equalToConstant: 22),
            ])
        }

        // Highlight active tab
        if index == currentIndex {
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
            container.layer?.cornerRadius = 4
        }

        return container
    }

    @objc private func tabButtonClicked(_ sender: NSButton) {
        switchToSession(sender.tag)
    }

    @objc private func closeTabButtonClicked(_ sender: NSButton) {
        removeSession(at: sender.tag)
    }
}
