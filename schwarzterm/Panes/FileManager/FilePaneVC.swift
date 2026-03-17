// Panes/FileManager/FilePaneVC.swift
import AppKit

class FilePaneVC: NSViewController, PaneProtocol {

    var paneTitle: String { "Files" }

    // MARK: - UI

    private let toolbar    = NSView()
    private let pathLabel  = NSTextField(labelWithString: "")
    private let homeButton = NSButton()

    // Left column: outline (directory tree)
    private let outlineScrollView = NSScrollView()
    private let outlineView       = NSOutlineView()

    // Right column: table (directory contents)
    private let tableScrollView = NSScrollView()
    private let tableView       = NSTableView()

    // Divider between columns
    private let divider = NSView()

    // MARK: - State

    private var rootItem: FileItem = FileItem.root(at: FileManager.default.homeDirectoryForCurrentUser)
    private var selectedDirectory: FileItem?

    // Divider dragging
    private var dividerLeading: NSLayoutConstraint!
    private var dividerFraction: CGFloat = 0.38
    private var isDragging = false

    // Debounce terminal directory changes so rapid cd's during shell init don't flicker
    private var navigateWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
        setupColumns()
        setupOutlineView()
        setupTableView()
        refreshOutline()
        selectDirectory(rootItem)
        observeTerminalDirectory()
    }

    // MARK: - Setup

    private func setupToolbar() {
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(pathLabel)

        homeButton.image = NSImage(systemSymbolName: "house", accessibilityDescription: "Home")
        homeButton.bezelStyle = .inline
        homeButton.isBordered = false
        homeButton.contentTintColor = .secondaryLabelColor
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        homeButton.target = self
        homeButton.action = #selector(goHome)
        toolbar.addSubview(homeButton)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 28),

            homeButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            homeButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 6),
            homeButton.widthAnchor.constraint(equalToConstant: 20),

            pathLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            pathLabel.leadingAnchor.constraint(equalTo: homeButton.trailingAnchor, constant: 4),
            pathLabel.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -6),
        ])
    }

    private func setupColumns() {
        outlineScrollView.translatesAutoresizingMaskIntoConstraints = false
        tableScrollView.translatesAutoresizingMaskIntoConstraints   = false
        divider.translatesAutoresizingMaskIntoConstraints           = false

        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor

        view.addSubview(outlineScrollView)
        view.addSubview(divider)
        view.addSubview(tableScrollView)

        dividerLeading = divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 200)

        NSLayoutConstraint.activate([
            // Outline: from leading to divider
            outlineScrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            outlineScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outlineScrollView.trailingAnchor.constraint(equalTo: divider.leadingAnchor),
            outlineScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Divider: 1pt wide, full height
            dividerLeading,
            divider.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            divider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            // Table: from divider to trailing
            tableScrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            tableScrollView.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            tableScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Set initial divider position once width is known
        view.needsLayout = true
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let w = view.bounds.width
        if w > 1 && dividerLeading.constant == 200 {
            // Apply fraction-based initial position
            dividerLeading.constant = max(80, min(w - 80, w * dividerFraction))
        }
    }

    private func setupOutlineView() {
        outlineScrollView.hasVerticalScroller = true
        outlineScrollView.hasHorizontalScroller = false
        outlineScrollView.autohidesScrollers = true
        outlineScrollView.borderType = .noBorder

        let col = NSTableColumn(identifier: .init("name"))
        col.title = "Name"
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col
        outlineView.headerView = nil
        outlineView.rowHeight = 20
        outlineView.intercellSpacing = NSSize(width: 0, height: 1)
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.backgroundColor = .clear
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.doubleAction = #selector(outlineDoubleClicked)
        outlineView.target = self
        outlineView.menu = makeOutlineContextMenu()

        outlineScrollView.documentView = outlineView
    }

    private func setupTableView() {
        tableScrollView.hasVerticalScroller = true
        tableScrollView.autohidesScrollers = true
        tableScrollView.borderType = .noBorder

        let col = NSTableColumn(identifier: .init("name"))
        col.title = "Name"
        col.minWidth = 80
        col.resizingMask = .autoresizingMask
        tableView.addTableColumn(col)

        let dateCol = NSTableColumn(identifier: .init("date"))
        dateCol.title = "Modified"
        dateCol.width = 110
        dateCol.minWidth = 80
        dateCol.maxWidth = 140
        dateCol.resizingMask = .userResizingMask
        tableView.addTableColumn(dateCol)

        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.rowHeight = 20
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(tableDoubleClicked)
        tableView.target = self
        tableView.menu = makeTableContextMenu()
        tableView.allowsMultipleSelection = true

        tableScrollView.documentView = tableView
    }

    // MARK: - Divider dragging

    override func mouseDragged(with event: NSEvent) {
        let loc = view.convert(event.locationInWindow, from: nil)
        let w   = view.bounds.width
        dividerLeading.constant = max(80, min(w - 80, loc.x))
        dividerFraction = dividerLeading.constant / w
    }

    override func mouseDown(with event: NSEvent) {
        let loc = view.convert(event.locationInWindow, from: nil)
        let divX = dividerLeading.constant
        isDragging = abs(loc.x - divX) < 6
        if !isDragging { super.mouseDown(with: event) }
    }

    // MARK: - Notifications

    private func observeTerminalDirectory() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(terminalDirectoryChanged(_:)),
            name: .terminalDirectoryChanged,
            object: nil
        )
    }

    @objc private func terminalDirectoryChanged(_ note: Notification) {
        guard let url = note.userInfo?["url"] as? URL else { return }
        // Ignore transient shell init directories (e.g. the ZDOTDIR temp path
        // used during shell startup) so they don't overwrite the file listing.
        let p = url.path
        guard !p.hasPrefix("/tmp/") && !p.hasPrefix("/private/tmp/") && !p.hasPrefix("/var/folders/") else { return }
        // Debounce: cancel any pending navigation and wait for the shell to settle
        // before updating the file pane (rapid cd's during rc sourcing cause flicker).
        navigateWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.navigate(to: url) }
        navigateWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Navigation

    @objc private func goHome() {
        navigate(to: FileManager.default.homeDirectoryForCurrentUser)
    }

    func navigate(to url: URL) {
        rootItem = FileItem.root(at: url)
        refreshOutline()
        selectDirectory(rootItem)
    }

    private func refreshOutline() {
        outlineView.reloadData()
        // Expand each top-level directory item explicitly.
        // expandItem(nil) is unreliable with custom data sources.
        let dirs = rootItem.children?.filter { $0.isDirectory } ?? []
        for dir in dirs {
            outlineView.expandItem(dir)
        }
    }

    private func selectDirectory(_ item: FileItem) {
        selectedDirectory = item
        pathLabel.stringValue = item.url.abbreviatingWithTildeInPath
        if !item.isLoaded { item.loadChildren() }
        tableView.reloadData()
    }

    // MARK: - Context Menus

    private func makeOutlineContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New File",      action: #selector(newFile(_:)),      keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "New Folder",    action: #selector(newFolder(_:)),    keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Rename",        action: #selector(renameSelected(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Move to Trash", action: #selector(deleteSelected(_:)), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        return menu
    }

    private func makeTableContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open in Editor",  action: #selector(openInEditor(_:)),   keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reveal in Finder",action: #selector(revealInFinder(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "New File",        action: #selector(newFile(_:)),        keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "New Folder",      action: #selector(newFolder(_:)),      keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Rename",          action: #selector(renameSelected(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Move to Trash",   action: #selector(deleteSelected(_:)), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        return menu
    }

    // MARK: - Actions

    @objc private func outlineDoubleClicked() {
        guard let item = outlineView.item(atRow: outlineView.clickedRow) as? FileItem else { return }
        if item.isDirectory { selectDirectory(item) }
    }

    @objc private func tableDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, let dir = selectedDirectory, let children = dir.children, row < children.count else { return }
        let item = children[row]
        if item.isDirectory { selectDirectory(item) } else { openFile(item.url) }
    }

    @objc private func openInEditor(_ sender: Any?) {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, let children = selectedDirectory?.children, row < children.count else { return }
        let item = children[row]
        if !item.isDirectory { openFile(item.url) }
    }

    private func openFile(_ url: URL) {
        NotificationCenter.default.post(name: .openFileInEditor, object: nil, userInfo: ["url": url])
    }

    @objc private func revealInFinder(_ sender: Any?) {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, let children = selectedDirectory?.children, row < children.count else { return }
        NSWorkspace.shared.activateFileViewerSelecting([children[row].url])
    }

    @objc private func newFile(_ sender: Any?) {
        guard let dir = selectedDirectory else { return }
        promptForName(title: "New File", placeholder: "untitled.txt") { [weak self] name in
            guard let name else { return }
            FileOperations.createFile(named: name, in: dir.url)
            dir.loadChildren()
            self?.tableView.reloadData()
        }
    }

    @objc private func newFolder(_ sender: Any?) {
        guard let dir = selectedDirectory else { return }
        promptForName(title: "New Folder", placeholder: "New Folder") { [weak self] name in
            guard let name else { return }
            FileOperations.createDirectory(named: name, in: dir.url)
            dir.loadChildren()
            self?.tableView.reloadData()
            self?.outlineView.reloadData()
        }
    }

    @objc private func renameSelected(_ sender: Any?) {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, let children = selectedDirectory?.children, row < children.count else { return }
        let item = children[row]
        guard let window = view.window else { return }
        FileOperations.presentRenameSheet(for: item.url, in: window) { [weak self] newName in
            guard let newName, !newName.isEmpty else { return }
            try? FileOperations.rename(item.url, to: newName)
            self?.selectedDirectory?.loadChildren()
            self?.tableView.reloadData()
            self?.outlineView.reloadData()
        }
    }

    @objc private func deleteSelected(_ sender: Any?) {
        var urls: [URL] = []
        tableView.selectedRowIndexes.forEach { row in
            if let children = selectedDirectory?.children, row < children.count {
                urls.append(children[row].url)
            }
        }
        if urls.isEmpty {
            let row = tableView.clickedRow
            if row >= 0, let children = selectedDirectory?.children, row < children.count {
                urls.append(children[row].url)
            }
        }
        guard !urls.isEmpty, let window = view.window else { return }
        let names = urls.map { $0.lastPathComponent }.joined(separator: ", ")
        let alert = NSAlert()
        alert.messageText = "Move to Trash?"
        alert.informativeText = "Move \"\(names)\" to the Trash?"
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            for url in urls { try? FileOperations.delete(url) }
            self?.selectedDirectory?.loadChildren()
            self?.tableView.reloadData()
            self?.outlineView.reloadData()
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

// MARK: - NSOutlineView DataSource & Delegate

extension FilePaneVC: NSOutlineViewDataSource, NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let fi = (item as? FileItem) ?? rootItem
        if !fi.isLoaded { fi.loadChildren() }
        return fi.children?.filter { $0.isDirectory }.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let fi = (item as? FileItem) ?? rootItem
        let dirs = fi.children?.filter { $0.isDirectory } ?? []
        return dirs[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return (item as? FileItem)?.isDirectory ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let fi = item as! FileItem
        let cellID = NSUserInterfaceItemIdentifier("OutlineCell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.font = .systemFont(ofSize: 12)
            cell.addSubview(imageView)
            cell.addSubview(tf)
            cell.imageView = imageView
            cell.textField = tf
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                tf.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            ])
        }
        cell.textField?.stringValue = fi.displayName
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: fi.url.path)
        cell.imageView?.image?.size = NSSize(width: 16, height: 16)
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let item = outlineView.item(atRow: outlineView.selectedRow) as? FileItem else { return }
        selectDirectory(item)
    }
}

// MARK: - NSTableView DataSource & Delegate

extension FilePaneVC: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        selectedDirectory?.children?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let children = selectedDirectory?.children, row < children.count else { return nil }
        let item = children[row]

        if tableColumn?.identifier.rawValue == "name" {
            let cellID = NSUserInterfaceItemIdentifier("TableNameCell")
            let cell: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
                cell = reused
            } else {
                cell = NSTableCellView()
                cell.identifier = cellID
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                let tf = NSTextField(labelWithString: "")
                tf.translatesAutoresizingMaskIntoConstraints = false
                tf.font = .systemFont(ofSize: 12)
                cell.addSubview(imageView)
                cell.addSubview(tf)
                cell.imageView = imageView
                cell.textField = tf
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    tf.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                    tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                ])
            }
            cell.textField?.stringValue = item.displayName
            cell.imageView?.image = NSWorkspace.shared.icon(forFile: item.url.path)
            cell.imageView?.image?.size = NSSize(width: 16, height: 16)
            return cell

        } else {
            let cellID = NSUserInterfaceItemIdentifier("TableDateCell")
            let cell: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
                cell = reused
            } else {
                cell = NSTableCellView()
                cell.identifier = cellID
                let tf = NSTextField(labelWithString: "")
                tf.translatesAutoresizingMaskIntoConstraints = false
                tf.font = .systemFont(ofSize: 11)
                tf.textColor = .secondaryLabelColor
                cell.addSubview(tf)
                cell.textField = tf
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                ])
            }
            if let date = (try? item.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
                cell.textField?.stringValue = RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
            } else {
                cell.textField?.stringValue = ""
            }
            return cell
        }
    }
}

// MARK: - URL helper

private extension URL {
    var abbreviatingWithTildeInPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
