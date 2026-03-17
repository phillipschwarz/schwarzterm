// Layout/SplitViewController.swift
import AppKit

/// Hosts two child view controllers in a draggable NSSplitView.
/// Uses a plain NSSplitView + NSSplitViewDelegate instead of NSSplitViewController
/// to avoid Auto Layout conflicts that prevent programmatic positioning and dragging.
class SplitViewController: NSViewController {

    private let splitView = NSSplitView()
    private let firstVC: NSViewController
    private let secondVC: NSViewController
    private let isVertical: Bool        // true = side-by-side, false = stacked
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
        // Maintain proportional resize when the window is resized
        let total = isVertical ? splitView.bounds.width : splitView.bounds.height
        guard total > 1, splitView.subviews.count == 2 else { return }

        let firstView  = splitView.subviews[0]
        let secondView = splitView.subviews[1]
        let divider    = splitView.dividerThickness

        let fraction: Double
        if isVertical {
            let oldTotal  = oldSize.width
            fraction = oldTotal > 1 ? Double(firstView.frame.width) / Double(oldTotal) : initialFraction
        } else {
            let oldTotal  = oldSize.height
            fraction = oldTotal > 1 ? Double(firstView.frame.height) / Double(oldTotal) : initialFraction
        }

        let clampedFraction = min(max(fraction, 0), 1)
        let firstSize = (total - divider) * CGFloat(clampedFraction)
        let secondSize = total - divider - firstSize

        if isVertical {
            firstView.frame  = NSRect(x: 0,                       y: 0, width: firstSize,  height: splitView.bounds.height)
            secondView.frame = NSRect(x: firstSize + divider,     y: 0, width: secondSize, height: splitView.bounds.height)
        } else {
            firstView.frame  = NSRect(x: 0, y: 0,                        width: splitView.bounds.width, height: firstSize)
            secondView.frame = NSRect(x: 0, y: firstSize + divider,       width: splitView.bounds.width, height: secondSize)
        }
    }
}
