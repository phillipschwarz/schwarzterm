// App/MainWindowController.swift
import AppKit

class MainWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "schwarzterm"
        window.titlebarAppearsTransparent = false
        window.minSize = NSSize(width: 800, height: 500)
        window.center()
        window.setFrameAutosaveName("MainWindow")

        self.init(window: window)

        let rootVC = LayoutManager.shared.buildRootViewController()
        window.contentViewController = rootVC
    }
}
