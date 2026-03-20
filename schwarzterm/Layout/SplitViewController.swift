// Layout/SplitViewController.swift
import AppKit

/// Hosts two child view controllers in a draggable NSSplitView.
/// Uses a plain NSSplitView + NSSplitViewDelegate instead of NSSplitViewController
/// to avoid Auto Layout conflicts that prevent programmatic positioning and dragging.
class SplitViewController: NSViewController {

    private let splitView = NSSplitView()
    private(set) var firstVC: NSViewController
    private(set) var secondVC: NSViewController
    private(set) var isVertical: Bool        // true = side-by-side, false = stacked
    private var initialFraction: Double = 0.5
    private var didApplyInitialPosition = false

    init(first: NSViewController, second: NSViewController, vertical: Bool) {
        self.firstVC  = first
        self.secondVC = second
        self.isVertical = vertical
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical   = isVertical
        splitView.dividerStyle = .thin
        splitView.delegate     = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Add child VCs
        addChild(firstVC)
        addChild(secondVC)
        firstVC.view.translatesAutoresizingMaskIntoConstraints  = true
        secondVC.view.translatesAutoresizingMaskIntoConstraints = true
        splitView.addSubview(firstVC.view)
        splitView.addSubview(secondVC.view)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyInitialPositionIfNeeded()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyInitialPositionIfNeeded()
    }

    // MARK: - Position

    func setInitialPosition(_ fraction: Double) {
        guard fraction > 0, fraction < 1 else { return }
        initialFraction = fraction
        didApplyInitialPosition = false   // reset so it re-applies if view reappears
        applyInitialPositionIfNeeded()
    }

    private func applyInitialPositionIfNeeded() {
        guard !didApplyInitialPosition else { return }
        let total = isVertical ? splitView.bounds.width : splitView.bounds.height
        guard total > 1 else { return }
        splitView.setPosition(total * initialFraction, ofDividerAt: 0)
        didApplyInitialPosition = true
    }

    // MARK: - Dynamic Mutation

    /// Current divider position as a 0…1 fraction of the total size.
    var currentFraction: Double {
        let total = isVertical ? splitView.bounds.width : splitView.bounds.height
        guard total > 1, splitView.subviews.count == 2 else { return initialFraction }
        let firstSize = isVertical ? splitView.subviews[0].frame.width : splitView.subviews[0].frame.height
        return Double(firstSize / total)
    }

    /// Replace one of the two children with a new view controller.
    func replaceChild(_ oldChild: NSViewController, with newChild: NSViewController) {
        let isFirst = (oldChild === firstVC)
        guard isFirst || (oldChild === secondVC) else { return }

        let subviewIndex = isFirst ? 0 : 1
        guard subviewIndex < splitView.subviews.count else { return }
        let savedFrame = splitView.subviews[subviewIndex].frame

        // Save the divider position before making any changes, because the
        // intermediate state (1 subview) can cause NSSplitView to auto-resize.
        let savedFraction = currentFraction

        // Remove old child
        oldChild.view.removeFromSuperview()
        oldChild.removeFromParent()

        // Update stored reference
        if isFirst { firstVC = newChild } else { secondVC = newChild }

        // Add new child
        addChild(newChild)
        newChild.view.translatesAutoresizingMaskIntoConstraints = true
        newChild.view.frame = savedFrame

        if subviewIndex == 0, let existingSecond = splitView.subviews.first {
            splitView.addSubview(newChild.view, positioned: .below, relativeTo: existingSecond)
        } else {
            splitView.addSubview(newChild.view)
        }

        // Restore the divider to where it was before the replacement
        let total = isVertical ? splitView.bounds.width : splitView.bounds.height
        if total > 1 {
            splitView.setPosition(total * savedFraction, ofDividerAt: 0)
        } else {
            splitView.adjustSubviews()
        }
    }

    /// Insert a new child VC into the slot (first or second) that was previously
    /// vacated by removing a child. Use this when the old child has already been
    /// detached from this split (removeFromParent + removeFromSuperview).
    func insertChild(_ newChild: NSViewController, asFirst: Bool) {
        // Save the divider position from the remaining subview before it shifts
        let savedFraction = splitView.subviews.count == 1 ? currentFraction : initialFraction

        if asFirst { firstVC = newChild } else { secondVC = newChild }

        addChild(newChild)
        newChild.view.translatesAutoresizingMaskIntoConstraints = true
        newChild.view.frame = splitView.bounds

        if asFirst, let existingOther = splitView.subviews.first {
            splitView.addSubview(newChild.view, positioned: .below, relativeTo: existingOther)
        } else {
            splitView.addSubview(newChild.view)
        }

        // Restore the divider position
        let total = isVertical ? splitView.bounds.width : splitView.bounds.height
        if total > 1 {
            splitView.setPosition(total * savedFraction, ofDividerAt: 0)
        } else {
            splitView.adjustSubviews()
        }
    }
}

// MARK: - NSSplitViewDelegate

extension SplitViewController: NSSplitViewDelegate {

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 120
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        let total = isVertical ? splitView.bounds.width : splitView.bounds.height
        return total - 120
    }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        let total = isVertical ? splitView.bounds.width : splitView.bounds.height
        guard total > 1, splitView.subviews.count == 2 else { return }

        let firstView  = splitView.subviews[0]
        let secondView = splitView.subviews[1]
        let divider    = splitView.dividerThickness

        // Compute fraction against available space (excluding divider) so it
        // doesn't drift due to rounding on repeated resize callbacks.
        let oldAvailable: CGFloat
        let firstCurrent: CGFloat
        if isVertical {
            oldAvailable = oldSize.width - divider
            firstCurrent = firstView.frame.width
        } else {
            oldAvailable = oldSize.height - divider
            firstCurrent = firstView.frame.height
        }

        let fraction = oldAvailable > 1 ? Double(firstCurrent / oldAvailable) : initialFraction
        let clamped = min(max(fraction, 0), 1)

        let available = total - divider
        let firstSize = round(available * clamped)
        let secondSize = available - firstSize

        if isVertical {
            firstView.frame  = NSRect(x: 0,                   y: 0, width: firstSize,  height: splitView.bounds.height)
            secondView.frame = NSRect(x: firstSize + divider,  y: 0, width: secondSize, height: splitView.bounds.height)
        } else {
            firstView.frame  = NSRect(x: 0, y: 0,                       width: splitView.bounds.width, height: firstSize)
            secondView.frame = NSRect(x: 0, y: firstSize + divider,      width: splitView.bounds.width, height: secondSize)
        }
    }
}
