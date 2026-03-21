// Panes/Editor/FindBarView.swift
import AppKit

protocol FindBarViewDelegate: AnyObject {
    func findBar(_ bar: FindBarView, searchFor text: String, forward: Bool)
    func findBarDidClose(_ bar: FindBarView)
}

class FindBarView: NSView {

    weak var delegate: FindBarViewDelegate?

    private let searchField = NSSearchField()
    private let nextButton  = NSButton()
    private let prevButton  = NSButton()
    private let closeButton = NSButton()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = ThemeManager.shared.current.findBarBackground.nsColor.cgColor

        NotificationCenter.default.addObserver(
            self, selector: #selector(themeDidChange), name: .themeChanged, object: nil
        )

        // Top separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sep)

        searchField.placeholderString = "Find…"
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        prevButton.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Previous")
        prevButton.bezelStyle = .smallSquare
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        prevButton.target = self
        prevButton.action = #selector(prevHit)
        addSubview(prevButton)

        nextButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Next")
        nextButton.bezelStyle = .smallSquare
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.target = self
        nextButton.action = #selector(nextHit)
        addSubview(nextButton)

        closeButton.title = "Done"
        closeButton.bezelStyle = .inline
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.target = self
        closeButton.action = #selector(closeHit)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: topAnchor),
            sep.leadingAnchor.constraint(equalTo: leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),

            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 220),

            prevButton.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 6),
            prevButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 26),

            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 4),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 26),

            closeButton.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 12),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @objc private func themeDidChange() {
        layer?.backgroundColor = ThemeManager.shared.current.findBarBackground.nsColor.cgColor
    }

    func focus() {
        window?.makeFirstResponder(searchField)
    }

    @objc private func searchChanged() {
        delegate?.findBar(self, searchFor: searchField.stringValue, forward: true)
    }

    @objc private func nextHit() {
        delegate?.findBar(self, searchFor: searchField.stringValue, forward: true)
    }

    @objc private func prevHit() {
        delegate?.findBar(self, searchFor: searchField.stringValue, forward: false)
    }

    @objc private func closeHit() {
        delegate?.findBarDidClose(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            delegate?.findBarDidClose(self)
        } else {
            super.keyDown(with: event)
        }
    }
}
