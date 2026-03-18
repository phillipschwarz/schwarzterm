// Panes/Editor/TabBarView.swift
import AppKit

protocol TabBarViewDelegate: AnyObject {
    func tabBar(_ bar: TabBarView, didSelectTab index: Int)
    func tabBar(_ bar: TabBarView, didCloseTab index: Int)
    func tabBarDidRequestNewTab(_ bar: TabBarView)
}

/// Tab bar: clipping container + direct NSView subviews + a trailing + button.
/// No NSScrollView, no NSControl inside tab cells — all mouse handling is manual.
class TabBarView: NSView {

    weak var delegate: TabBarViewDelegate?
    private(set) var selectedIndex: Int = 0

    private let clipView   = NSView()
    private let stripView  = NSView()
    private let addButton  = NSButton()
    private var tabs: [TabCell] = []

    private static let tabHeight:  CGFloat = 30
    private static let tabMinWidth: CGFloat = 90
    private static let tabMaxWidth: CGFloat = 200
    private static let addButtonW:  CGFloat = 30

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.14, alpha: 1).cgColor

        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")
        addButton.bezelStyle = .inline
        addButton.isBordered = false
        addButton.contentTintColor = .secondaryLabelColor
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.target = self
        addButton.action = #selector(addButtonClicked)
        addSubview(addButton)

        clipView.wantsLayer = true
        clipView.layer?.masksToBounds = true
        clipView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clipView)

        stripView.wantsLayer = false
        clipView.addSubview(stripView)

        NSLayoutConstraint.activate([
            addButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            addButton.topAnchor.constraint(equalTo: topAnchor),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            addButton.widthAnchor.constraint(equalToConstant: Self.addButtonW),

            clipView.leadingAnchor.constraint(equalTo: leadingAnchor),
            clipView.topAnchor.constraint(equalTo: topAnchor),
            clipView.bottomAnchor.constraint(equalTo: bottomAnchor),
            clipView.trailingAnchor.constraint(equalTo: addButton.leadingAnchor),
        ])
    }

    @objc private func addButtonClicked() {
        delegate?.tabBarDidRequestNewTab(self)
    }

    override var isFlipped: Bool { true }

    // MARK: - Public API

    func setTabs(_ titles: [String], modified: [Bool]) {
        tabs.forEach { $0.removeFromSuperview() }
        tabs = []

        for (i, title) in titles.enumerated() {
            let cell = TabCell()
            cell.configure(title: title, isModified: modified[i], isSelected: i == selectedIndex)
            cell.onSelect = { [weak self] in self?.userDidSelect(index: i) }
            cell.onClose  = { [weak self] in self?.delegate?.tabBar(self!, didCloseTab: i) }
            stripView.addSubview(cell)
            tabs.append(cell)
        }
        layoutTabs()
    }

    func selectTab(_ index: Int) {
        selectedIndex = index
        tabs.enumerated().forEach { $0.element.isSelected = $0.offset == index }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        layoutTabs()
    }

    private func layoutTabs() {
        guard !tabs.isEmpty else {
            stripView.frame = .zero
            return
        }
        let h = bounds.height > 0 ? bounds.height : Self.tabHeight
        let availableWidth = clipView.bounds.width > 0 ? clipView.bounds.width : bounds.width
        let rawW = availableWidth / CGFloat(tabs.count)
        let tabW = min(Self.tabMaxWidth, max(Self.tabMinWidth, rawW))
        let totalW = tabW * CGFloat(tabs.count)

        stripView.frame = CGRect(x: 0, y: 0, width: totalW, height: h)
        for (i, cell) in tabs.enumerated() {
            cell.frame = CGRect(x: CGFloat(i) * tabW, y: 0, width: tabW, height: h)
        }
    }

    // MARK: - Private

    private func userDidSelect(index: Int) {
        selectedIndex = index
        tabs.enumerated().forEach { $0.element.isSelected = $0.offset == index }
        delegate?.tabBar(self, didSelectTab: index)
    }
}

// MARK: - TabCell

/// A single tab. No subviews at all — title and × are drawn manually in draw().
/// mouseDown checks whether the click is in the × hit area and routes accordingly.
private class TabCell: NSView {

    override var isFlipped: Bool { true }

    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var onSelect: (() -> Void)?
    var onClose:  (() -> Void)?

    private var title: String = ""
    private var isModified: Bool = false

    // The × hit rect is computed in draw() and stored here for mouseDown to check.
    private var closeHitRect: NSRect = .zero

    override init(frame: NSRect) {
        super.init(frame: .zero)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isModified: Bool, isSelected: Bool) {
        self.title = title
        self.isModified = isModified
        self.isSelected = isSelected
        needsDisplay = true
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if isSelected && closeHitRect.contains(loc) {
            onClose?()
        } else {
            onSelect?()
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Background
        let bg: NSColor = isSelected
            ? NSColor(white: 0.22, alpha: 1)
            : NSColor(white: 0.12, alpha: 1)
        bg.setFill()
        bounds.fill()

        // Top accent line (y:0 = top in flipped coords)
        if isSelected {
            NSColor.controlAccentColor.setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: 2).fill()
        }

        // Right divider
        NSColor.separatorColor.withAlphaComponent(0.3).setFill()
        NSRect(x: bounds.maxX - 1, y: 3, width: 1, height: bounds.height - 6).fill()

        // × close glyph on selected tab
        let closeSize: CGFloat = 14
        let closePad:  CGFloat = 6
        if isSelected {
            let cx = bounds.maxX - closePad - closeSize
            let cy = (bounds.height - closeSize) / 2
            closeHitRect = NSRect(x: cx, y: cy, width: closeSize, height: closeSize)

            let xAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            let xStr = "×" as NSString
            let xSize = xStr.size(withAttributes: xAttrs)
            xStr.draw(at: NSPoint(
                x: closeHitRect.midX - xSize.width / 2,
                y: closeHitRect.midY - xSize.height / 2
            ), withAttributes: xAttrs)
        } else {
            closeHitRect = .zero
        }

        // Title text
        let rightPad: CGFloat = isSelected ? (closePad + closeSize + 4) : 10
        let textColor: NSColor = isModified
            ? .controlAccentColor
            : (isSelected ? .labelColor : .secondaryLabelColor)
        let font = NSFont.systemFont(ofSize: 11.5)
        let textRect = NSRect(x: 10, y: 0, width: bounds.width - 10 - rightPad, height: bounds.height)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let str = title as NSString
        let fullSize = str.size(withAttributes: attrs)
        if fullSize.width <= textRect.width {
            let y = (bounds.height - fullSize.height) / 2
            str.draw(at: NSPoint(x: textRect.minX, y: y), withAttributes: attrs)
        } else {
            str.draw(with: textRect,
                     options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                     attributes: attrs)
        }
    }
}
