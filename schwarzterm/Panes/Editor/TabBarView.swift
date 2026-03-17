// Panes/Editor/TabBarView.swift
import AppKit

protocol TabBarViewDelegate: AnyObject {
    func tabBar(_ bar: TabBarView, didSelectTab index: Int)
    func tabBar(_ bar: TabBarView, didCloseTab index: Int)
    func tabBarDidRequestNewTab(_ bar: TabBarView)
}

class TabBarView: NSView {

    weak var delegate: TabBarViewDelegate?

    private var tabButtons: [TabButton] = []
    private var addButton: NSButton!
    private(set) var selectedIndex: Int = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor

        addButton = NSButton(title: "+", target: self, action: #selector(newTabPressed))
        addButton.bezelStyle = .inline
        addButton.isBordered = false
        addButton.font = .systemFont(ofSize: 14)
        addButton.contentTintColor = .secondaryLabelColor
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)

        NSLayoutConstraint.activate([
            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 24),
        ])
    }

    @objc private func newTabPressed() {
        delegate?.tabBarDidRequestNewTab(self)
    }

    func setTabs(_ titles: [String], modified: [Bool]) {
        tabButtons.forEach { $0.removeFromSuperview() }
        tabButtons = []

        for (i, title) in titles.enumerated() {
            let btn = TabButton(title: title, isModified: modified[i], isSelected: i == selectedIndex, index: i)
            btn.onSelect = { [weak self] idx in
                guard let self else { return }
                self.selectedIndex = idx
                self.tabButtons.forEach { $0.isSelected = $0.index == idx }
                self.delegate?.tabBar(self, didSelectTab: idx)
            }
            btn.onClose = { [weak self] idx in
                guard let self else { return }
                self.delegate?.tabBar(self, didCloseTab: idx)
            }
            btn.translatesAutoresizingMaskIntoConstraints = false
            addSubview(btn)
            tabButtons.append(btn)
        }

        relayout()
    }

    private func relayout() {
        var prevAnchor: NSLayoutXAxisAnchor = leadingAnchor

        for btn in tabButtons {
            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: prevAnchor),
                btn.topAnchor.constraint(equalTo: topAnchor),
                btn.bottomAnchor.constraint(equalTo: bottomAnchor),
                btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
                btn.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            ])
            prevAnchor = btn.trailingAnchor
        }
    }

    func selectTab(_ index: Int) {
        selectedIndex = index
        tabButtons.forEach { $0.isSelected = $0.index == selectedIndex }
    }
}

// MARK: - TabButton

/// A plain NSView tab button. Using NSView (not NSControl) avoids the problem
/// where NSControl.mouseDown consumes all events and prevents embedded
/// NSButton subviews from receiving clicks.
class TabButton: NSView {
    let index: Int
    var isSelected: Bool { didSet { needsDisplay = true } }
    var isModified: Bool { didSet { needsDisplay = true } }

    /// Called when the tab body is clicked (select).
    var onSelect: ((Int) -> Void)?
    /// Called when the close × is clicked.
    var onClose: ((Int) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()

    init(title: String, isModified: Bool, isSelected: Bool, index: Int) {
        self.index = index
        self.isSelected = isSelected
        self.isModified = isModified
        super.init(frame: .zero)
        setup(title: title)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(title: String) {
        wantsLayer = true

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 11.5)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        closeButton.title = "×"
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.font = .systemFont(ofSize: 12)
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
        ])
    }

    @objc private func closePressed() {
        onClose?(index)
    }

    override func mouseDown(with event: NSEvent) {
        // Hit-test: if the click lands inside the close button, forward the
        // event to it so NSButton handles highlighting/action correctly.
        let loc = convert(event.locationInWindow, from: nil)
        if closeButton.frame.contains(loc) {
            closeButton.mouseDown(with: event)
            return
        }
        onSelect?(index)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            NSColor.controlBackgroundColor.setFill()
        } else {
            NSColor.windowBackgroundColor.withAlphaComponent(0.5).setFill()
        }
        bounds.fill()

        // Bottom border for selected tab
        if isSelected {
            NSColor.controlAccentColor.setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: 2).fill()
        }

        // Right separator
        NSColor.separatorColor.withAlphaComponent(0.4).setFill()
        NSRect(x: bounds.maxX - 1, y: 4, width: 1, height: bounds.height - 8).fill()

        titleLabel.textColor = isModified ? .controlAccentColor : (isSelected ? .labelColor : .secondaryLabelColor)
    }
}
