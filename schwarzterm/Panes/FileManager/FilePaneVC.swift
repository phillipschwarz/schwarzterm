// Panes/FileManager/FilePaneVC.swift
import AppKit

class FilePaneVC: NSViewController, PaneProtocol {

    var paneTitle: String { "Files" }

    // MARK: - UI

    private let toolbar     = NSView()
    private let pathLabel   = NSTextField(labelWithString: "")
    private let homeButton  = NSButton()
    private let upButton    = NSButton()
    private let scrollView  = NSScrollView()
    private let outlineView = NSOutlineView()

    // MARK: - State

    private var rootItem: FileItem = FileItem.root(at: FileManager.default.homeDirectoryForCurrentUser)
    private var navigateWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    override func loadView() {
        let v = NSView()
        v.wantsLayer = true
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
        setupOutline()
        reload(expanding: rootItem)
        observeNotifications()
    }

    // MARK: - Setup

    private func setupToolbar() {
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        upButton.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Up")
        upButton.bezelStyle = .inline
        upButton.isBordered = false
        upButton.contentTintColor = .secondaryLabelColor
        upButton.translatesAutoresizingMaskIntoConstraints = false
        upButton.target = self
        upButton.action = #selector(goUp)
        toolbar.addSubview(upButton)

        homeButton.image = NSImage(systemSymbolName: "house", accessibilityDescription: "Home")
        homeButton.bezelStyle = .inline
        homeButton.isBordered = false
        homeButton.contentTintColor = .secondaryLabelColor
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        homeButton.target = self
        homeButton.action = #selector(goHome)
        toolbar.addSubview(homeButton)

        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingHead
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(pathLabel)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 28),

            upButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            upButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 6),
            upButton.widthAnchor.constraint(equalToConstant: 20),

            homeButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            homeButton.leadingAnchor.constraint(equalTo: upButton.trailingAnchor, constant: 2),
            homeButton.widthAnchor.constraint(equalToConstant: 20),

            pathLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            pathLabel.leadingAnchor.constraint(equalTo: homeButton.trailingAnchor, constant: 6),
            pathLabel.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -6),
        ])
    }

    private func setupOutline() {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let col = NSTableColumn(identifier: .init("name"))
        col.resizingMask = .autoresizingMask
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col
        outlineView.headerView = nil
        outlineView.rowHeight = 22
        outlineView.intercellSpacing = NSSize(width: 0, height: 0)
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.backgroundColor = .controlBackgroundColor
        outlineView.indentationPerLevel = 14
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.doubleAction = #selector(itemDoubleClicked)
        outlineView.target = self
        outlineView.menu = makeContextMenu()

        scrollView.documentView = outlineView
    }

    // MARK: - Reload

    /// Reload the outline from disk and expand `item` (pass rootItem to expand root).
    private func reload(expanding item: FileItem) {
        item.reload()
        outlineView.reloadData()
        if item != rootItem {
            outlineView.expandItem(item)
        }
        pathLabel.stringValue = rootItem.url.abbreviatingWithTildeInPath
        if outlineView.numberOfRows > 0 {
            outlineView.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    // MARK: - Navigation

    @objc private func goHome() {
        navigate(to: FileManager.default.homeDirectoryForCurrentUser)
    }

    @objc private func goUp() {
        let parent = rootItem.url.deletingLastPathComponent()
        guard parent != rootItem.url else { return }   // already at filesystem root
        navigate(to: parent)
    }

    func navigate(to url: URL) {
        rootItem = FileItem.root(at: url)
        reload(expanding: rootItem)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(terminalDirectoryChanged(_:)),
            name: .terminalDirectoryChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openDirectoryInFilePane(_:)),
            name: .openDirectoryInFilePane,
            object: nil
        )
    }

    @objc private func terminalDirectoryChanged(_ note: Notification) {
        guard let url = note.userInfo?["url"] as? URL else { return }
        let p = url.path
        guard !p.hasPrefix("/tmp/") && !p.hasPrefix("/private/tmp/") && !p.hasPrefix("/var/folders/") else { return }
        navigateWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.navigate(to: url) }
        navigateWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    @objc private func openDirectoryInFilePane(_ note: Notification) {
        guard let url = note.userInfo?["url"] as? URL else { return }
        // Explicit user command — navigate immediately, no debounce
        navigate(to: url)
    }

    // MARK: - Context Menu

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open in Editor",   action: #selector(openInEditor(_:)),   keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reveal in Finder", action: #selector(revealInFinder(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "New File",         action: #selector(newFile(_:)),        keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "New Folder",       action: #selector(newFolder(_:)),      keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Rename",           action: #selector(renameItem(_:)),     keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Move to Trash",    action: #selector(deleteItems(_:)),    keyEquivalent: ""))
        for item in menu.items { item.target = self }
        return menu
    }

    // MARK: - Actions

    @objc private func itemDoubleClicked() {
        guard let item = outlineView.item(atRow: outlineView.clickedRow) as? FileItem else { return }
        if item.isDirectory {
            // Navigate into the directory, making it the new root
            navigate(to: item.url)
        } else {
            openFile(item.url)
        }
    }

    @objc private func openInEditor(_ sender: Any?) {
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? FileItem, !item.isDirectory else { return }
        openFile(item.url)
    }

    private func openFile(_ url: URL) {
        NotificationCenter.default.post(name: .openFileInEditor, object: nil, userInfo: ["url": url])
    }

    @objc private func revealInFinder(_ sender: Any?) {
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? FileItem else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    @objc private func newFile(_ sender: Any?) {
        let targetDir = contextDirectory()
        promptForName(title: "New File", placeholder: "untitled.txt") { [weak self] name in
            guard let name, !name.isEmpty else { return }
            FileOperations.createFile(named: name, in: targetDir.url)
            self?.refreshItem(targetDir)
        }
    }

    @objc private func newFolder(_ sender: Any?) {
        let targetDir = contextDirectory()
        promptForName(title: "New Folder", placeholder: "New Folder") { [weak self] name in
            guard let name, !name.isEmpty else { return }
            FileOperations.createDirectory(named: name, in: targetDir.url)
            self?.refreshItem(targetDir)
        }
    }

    @objc private func renameItem(_ sender: Any?) {
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? FileItem,
              let window = view.window else { return }
        FileOperations.presentRenameSheet(for: item.url, in: window) { [weak self] newName in
            guard let newName, !newName.isEmpty else { return }
            try? FileOperations.rename(item.url, to: newName)
            if let parent = self?.parent(of: item) {
                self?.refreshItem(parent)
            } else {
                self?.reload(expanding: self!.rootItem)
            }
        }
    }

    @objc private func deleteItems(_ sender: Any?) {
        var rows = outlineView.selectedRowIndexes
        if rows.isEmpty, outlineView.clickedRow >= 0 { rows = [outlineView.clickedRow] }
        let items = rows.compactMap { outlineView.item(atRow: $0) as? FileItem }
        guard !items.isEmpty, let window = view.window else { return }

        let names = items.map { $0.name }.joined(separator: ", ")
        let alert = NSAlert()
        alert.messageText = "Move to Trash?"
        alert.informativeText = "Move \"\(names)\" to the Trash?"
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            // Group by parent so we only refresh each parent once
            var parents: Set<FileItem> = []
            for item in items {
                try? FileOperations.delete(item.url)
                if let p = self?.parent(of: item) { parents.insert(p) }
            }
            if parents.isEmpty {
                self?.reload(expanding: self!.rootItem)
            } else {
                parents.forEach { self?.refreshItem($0) }
            }
        }
    }

    // MARK: - Helpers

    /// The directory to use for new-file/folder actions: the clicked item's dir, or root.
    private func contextDirectory() -> FileItem {
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? FileItem else { return rootItem }
        return item.isDirectory ? item : (parent(of: item) ?? rootItem)
    }

    /// Find the parent FileItem of a given item by searching the visible tree.
    private func parent(of item: FileItem) -> FileItem? {
        return findParent(of: item, in: rootItem)
    }

    private func findParent(of target: FileItem, in node: FileItem) -> FileItem? {
        guard let children = node.children else { return nil }
        if children.contains(target) { return node }
        for child in children where child.isDirectory {
            if let found = findParent(of: target, in: child) { return found }
        }
        return nil
    }

    /// Reload a specific directory item and update the outline in place.
    private func refreshItem(_ item: FileItem) {
        item.reload()
        if item == rootItem {
            // Root level items are always visible; just reload data
            outlineView.reloadData()
        } else {
            let wasExpanded = outlineView.isItemExpanded(item)
            outlineView.reloadItem(item, reloadChildren: true)
            if wasExpanded { outlineView.expandItem(item) }
        }
    }

    private func promptForName(title: String, placeholder: String, completion: @escaping (String?) -> Void) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { response in
            completion(response == .alertFirstButtonReturn ? field.stringValue : nil)
        }
    }
}

// MARK: - NSOutlineView DataSource

extension FilePaneVC: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = (item as? FileItem) ?? rootItem
        if !node.isLoaded { node.reload() }
        return node.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let node = (item as? FileItem) ?? rootItem
        return node.children![index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileItem)?.isDirectory ?? false
    }
}

// MARK: - NSOutlineView Delegate

extension FilePaneVC: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fi = item as? FileItem else { return nil }

        let id = NSUserInterfaceItemIdentifier("FileCell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = id

            let iv = NSImageView()
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.imageScaling = .scaleProportionallyDown

            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.font = .systemFont(ofSize: 12)
            tf.lineBreakMode = .byTruncatingMiddle

            cell.addSubview(iv)
            cell.addSubview(tf)
            cell.imageView = iv
            cell.textField = tf

            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                iv.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                iv.widthAnchor.constraint(equalToConstant: 16),
                iv.heightAnchor.constraint(equalToConstant: 16),
                tf.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            ])
        }

        cell.textField?.stringValue = fi.displayName
        cell.textField?.textColor = fi.isDirectory ? .labelColor : .secondaryLabelColor
        let icon = NSWorkspace.shared.icon(forFile: fi.url.path)
        icon.size = NSSize(width: 16, height: 16)
        cell.imageView?.image = icon
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool { true }
}

// MARK: - URL helper

private extension URL {
    var abbreviatingWithTildeInPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}
