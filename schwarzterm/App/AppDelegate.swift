// App/AppDelegate.swift
import AppKit
import CoreText

@main
class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {

    nonisolated static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        NSApp.run()
    }

    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerBundledFonts()
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        buildMenu()
    }

    /// Registers all TTF fonts shipped inside the app bundle so they are available
    /// to NSFont by PostScript name (e.g. "JetBrainsMono-Regular").
    private func registerBundledFonts() {
        let fontNames = [
            "JetBrainsMono-Regular",
            "JetBrainsMono-Italic",
            "JetBrainsMono-Bold",
            "JetBrainsMono-BoldItalic",
        ]
        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("[fonts] missing \(name).ttf in bundle")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit schwarzterm", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        // File menu
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let saveItem = NSMenuItem(title: "Save", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        fileMenu.addItem(saveItem)
        let saveAsItem = NSMenuItem(title: "Save As…", action: #selector(saveDocumentAs(_:)), keyEquivalent: "S")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(saveAsItem)
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        // View menu — Find
        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Find…", action: #selector(showFindBar(_:)), keyEquivalent: "f"))
        let newlineItem = NSMenuItem(title: "Insert Line Below", action: #selector(insertNewlineBelow(_:)), keyEquivalent: "\r")
        newlineItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(newlineItem)
        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        // Focus shortcuts — jump between editor and terminal
        let focusItem = NSMenuItem()
        let focusMenu = NSMenu(title: "Focus")
        focusMenu.addItem(NSMenuItem(title: "Focus Editor", action: #selector(focusEditor(_:)), keyEquivalent: "e"))
        focusMenu.addItem(NSMenuItem(title: "Focus Terminal", action: #selector(focusTerminal(_:)), keyEquivalent: "j"))
        focusItem.submenu = focusMenu
        mainMenu.addItem(focusItem)

        // Tab menu — new tab, close tab, cycle tabs
        let tabItem = NSMenuItem()
        let tabMenu = NSMenu(title: "Tab")
        tabMenu.addItem(NSMenuItem(title: "New Tab", action: #selector(newEditorTab(_:)), keyEquivalent: "t"))
        tabMenu.addItem(NSMenuItem(title: "Close Tab", action: #selector(closeEditorTab(_:)), keyEquivalent: "w"))
        tabMenu.addItem(.separator())
        tabMenu.addItem(NSMenuItem(title: "Next Tab", action: #selector(selectNextTab(_:)), keyEquivalent: "]"))
        tabMenu.addItem(NSMenuItem(title: "Previous Tab", action: #selector(selectPreviousTab(_:)), keyEquivalent: "["))
        tabItem.submenu = tabMenu
        mainMenu.addItem(tabItem)

        NSApp.mainMenu = mainMenu
    }

    // These are declared here so AppKit can find them as targets on the menu items.
    // The actual implementations live on EditorPaneVC which is in the responder chain.
    @objc func saveDocument(_ sender: Any?) {}
    @objc func saveDocumentAs(_ sender: Any?) {}
    @objc func showFindBar(_ sender: Any?) {}
    @objc func newEditorTab(_ sender: Any?) {}
    @objc func closeEditorTab(_ sender: Any?) {}
    @objc func selectNextTab(_ sender: Any?) {}
    @objc func selectPreviousTab(_ sender: Any?) {}
    @objc func insertNewlineBelow(_ sender: Any?) {}
    @objc func focusEditor(_ sender: Any?) {
        NotificationCenter.default.post(name: .focusEditor, object: nil)
    }
    @objc func focusTerminal(_ sender: Any?) {
        NotificationCenter.default.post(name: .focusTerminal, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
