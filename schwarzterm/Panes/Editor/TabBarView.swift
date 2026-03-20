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

    /// Set by the owning pane VC so drag payloads identify the source.
    var sourcePaneID: UInt = 0
    /// Set by the owning pane VC so drag payloads carry the pane kind.
    var sourcePaneKind: TabDragPayload.PaneKind = .editor
    /// Whether dragging is allowed (e.g. terminal with 1 tab should not drag)
    var dragEnabled: Bool = true

    private let clipView   = NSView()
    private let stripView  = NSView()
    private let addButton  = NSButton()
    private var tabs: [TabCell] = []

    private static let tabHeight:  CGFloat = 34
    private static let tabMinWidth: CGFloat = 100
    private static let tabMaxWidth: CGFloat = 220
    private static let addButtonW:  CGFloat = 34
    private static let tabSpacing:  CGFloat = 4
    private static let tabPadY:     CGFloat = 4  // vertical inset for pill shape

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.11, alpha: 1).cgColor

        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")
        addButton.bezelStyle = .inline
        addButton.isBordered = false
        addButton.contentTintColor = NSColor(white: 0.55, alpha: 1)
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
            cell.tabIndex = i
            cell.dragOwner = self
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
        let spacing = Self.tabSpacing
        let leadingPad: CGFloat = spacing
        let totalSpacing = leadingPad + spacing * CGFloat(tabs.count - 1)
        let rawW = (availableWidth - totalSpacing) / CGFloat(tabs.count)
        let tabW = min(Self.tabMaxWidth, max(Self.tabMinWidth, rawW))
        let totalW = leadingPad + tabW * CGFloat(tabs.count) + spacing * CGFloat(tabs.count - 1)
        let pillH = h - Self.tabPadY * 2

        stripView.frame = CGRect(x: 0, y: 0, width: totalW, height: h)
        for (i, cell) in tabs.enumerated() {
            let x = leadingPad + CGFloat(i) * (tabW + spacing)
            cell.frame = CGRect(x: x, y: Self.tabPadY, width: tabW, height: pillH)
        }
    }

    // MARK: - Tab Dragging

    /// Called by a TabCell when the user drags past the threshold.
    fileprivate func beginTabDrag(cellIndex: Int, event: NSEvent) {
        guard dragEnabled else { return }

        let payload = TabDragPayload(
            paneKind: sourcePaneKind,
            sourcePaneID: sourcePaneID,
            tabIndex: cellIndex
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }

        // Snapshot of the tab cell for the drag image
        let cell = tabs[cellIndex]
        let snapshot = cell.snapshot()

        let dragItem = NSDraggingItem(pasteboardWriter: NSPasteboardItem())
        dragItem.setDraggingFrame(cell.convert(cell.bounds, to: self), contents: snapshot)

        if let pbItem = dragItem.item as? NSPasteboardItem {
            pbItem.setData(data, forType: .schwarztermTab)
        }

        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    // MARK: - Private

    private func userDidSelect(index: Int) {
        selectedIndex = index
        tabs.enumerated().forEach { $0.element.isSelected = $0.offset == index }
        delegate?.tabBar(self, didSelectTab: index)
    }
}

// MARK: - NSDraggingSource

extension TabBarView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .withinApplication ? .move : []
    }
}

// MARK: - TabCell

/// A single tab drawn as a rounded pill — inspired by macOS Tahoe Safari's
/// Liquid Glass aesthetic. The selected tab has a frosted-glass highlight;
/// unselected tabs are transparent with subtle hover feedback.
private class TabCell: NSView {

    override var isFlipped: Bool { true }

    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var onSelect: (() -> Void)?
    var onClose:  (() -> Void)?

    /// Index of this tab within the tab bar (set by TabBarView).
    var tabIndex: Int = 0
    /// Back-reference to the owning tab bar for drag initiation.
    weak var dragOwner: TabBarView?

    private var title: String = ""
    private var isModified: Bool = false
    private var isHovered: Bool = false { didSet { needsDisplay = true } }

    // The × hit rect is computed in draw() and stored here for mouseDown to check.
    private var closeHitRect: NSRect = .zero

    // Drag detection
    private var mouseDownLocation: NSPoint = .zero
    private var didInitiateDrag = false
    private static let dragThreshold: CGFloat = 4

    // Pill geometry
    private static let cornerRadius: CGFloat = 8
    private static let closeButtonSize: CGFloat = 16

    private var trackingArea: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isModified: Bool, isSelected: Bool) {
        self.title = title
        self.isModified = isModified
        self.isSelected = isSelected
        needsDisplay = true
    }

    /// Create a bitmap snapshot of this cell for the drag image.
    func snapshot() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current {
            layer?.render(in: ctx.cgContext)
        }
        image.unlockFocus()
        return image
    }

    // MARK: - Tracking (hover)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent)  { isHovered = false }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = convert(event.locationInWindow, from: nil)
        didInitiateDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didInitiateDrag else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let dx = loc.x - mouseDownLocation.x
        let dy = loc.y - mouseDownLocation.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance >= Self.dragThreshold {
            didInitiateDrag = true
            dragOwner?.beginTabDrag(cellIndex: tabIndex, event: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard !didInitiateDrag else { return }
        let loc = convert(event.locationInWindow, from: nil)
        if (isSelected || isHovered) && closeHitRect.contains(loc) {
            onClose?()
        } else {
            onSelect?()
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let pillRect = bounds
        let pill = NSBezierPath(roundedRect: pillRect, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)

        // --- Pill background ---
        if isSelected {
            // Frosted glass: semi-transparent light fill
            NSColor(white: 1.0, alpha: 0.10).setFill()
            pill.fill()
            // Subtle inner glow border
            NSColor(white: 1.0, alpha: 0.14).setStroke()
            pill.lineWidth = 0.5
            pill.stroke()
        } else if isHovered {
            NSColor(white: 1.0, alpha: 0.05).setFill()
            pill.fill()
        }
        // Unselected + not hovered: fully transparent (no fill)

        // --- Close button (circle with ×) ---
        let showClose = isSelected || isHovered
        let closeBtnSize = Self.closeButtonSize
        let closePad: CGFloat = 8
        if showClose {
            let cx = pillRect.maxX - closePad - closeBtnSize
            let cy = (pillRect.height - closeBtnSize) / 2
            closeHitRect = NSRect(x: cx, y: cy, width: closeBtnSize, height: closeBtnSize)

            // Circle background
            let circlePath = NSBezierPath(ovalIn: closeHitRect)
            NSColor(white: 1.0, alpha: 0.08).setFill()
            circlePath.fill()

            // × glyph
            let xAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor(white: 0.65, alpha: 1),
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

        // --- Title text ---
        let leftPad: CGFloat = 10
        let rightPad: CGFloat = showClose ? (closePad + closeBtnSize + 4) : 10
        let textColor: NSColor
        if isModified {
            textColor = .controlAccentColor
        } else if isSelected {
            textColor = NSColor(white: 0.95, alpha: 1)
        } else {
            textColor = NSColor(white: 0.55, alpha: 1)
        }

        let font = NSFont.systemFont(ofSize: 11.5, weight: isSelected ? .medium : .regular)
        let textRect = NSRect(
            x: leftPad,
            y: 0,
            width: pillRect.width - leftPad - rightPad,
            height: pillRect.height
        )
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let str = title as NSString
        let fullSize = str.size(withAttributes: attrs)
        if fullSize.width <= textRect.width {
            let y = (pillRect.height - fullSize.height) / 2
            str.draw(at: NSPoint(x: textRect.minX, y: y), withAttributes: attrs)
        } else {
            str.draw(with: textRect,
                     options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
                     attributes: attrs)
        }
    }
}
