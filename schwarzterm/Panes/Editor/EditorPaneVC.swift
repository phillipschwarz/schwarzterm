// Panes/Editor/EditorPaneVC.swift
import AppKit
import STTextView

class EditorPaneVC: NSViewController, PaneProtocol {

    var paneTitle: String { "Editor" }

    // MARK: - UI

    private let tabBar = TabBarView()
    private let editorContainer = NSView()
    private var findBar: FindBarView?
    private var findBarHeightConstraint: NSLayoutConstraint!

    // MARK: - State

    private var documents: [EditorDocument] = []
    private var currentIndex: Int = 0
    private var textView: STTextView?
    private var scrollView: NSScrollView?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupEditorContainer()
        setupFindBar()
        openUntitledIfEmpty()
        observeNotifications()
    }

    // MARK: - Setup

    private func setupTabBar() {
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    private func setupEditorContainer() {
        editorContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editorContainer)
        NSLayoutConstraint.activate([
            editorContainer.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            editorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupFindBar() {
        let fb = FindBarView()
        fb.translatesAutoresizingMaskIntoConstraints = false
        fb.isHidden = true
        fb.delegate = self
        view.addSubview(fb)
        findBarHeightConstraint = fb.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            fb.topAnchor.constraint(equalTo: editorContainer.bottomAnchor),
            fb.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fb.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fb.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            findBarHeightConstraint,
        ])
        findBar = fb
    }

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openFileNotification(_:)),
            name: .openFileInEditor,
            object: nil
        )
    }

    // MARK: - Document Management

    private func openUntitledIfEmpty() {
        guard documents.isEmpty else { return }
        openDocument(EditorDocument(untitled: ""))
    }

    func openFile(_ url: URL) {
        if let idx = documents.firstIndex(where: { $0.url == url }) {
            switchToTab(idx)
            return
        }
        openDocument(EditorDocument(url: url))
    }

    private func openDocument(_ doc: EditorDocument) {
        documents.append(doc)
        switchToTab(documents.count - 1)
        refreshTabBar()
    }

    private func switchToTab(_ index: Int) {
        guard index >= 0, index < documents.count else { return }
        // Flush current text back to document before switching
        if let tv = textView, currentIndex < documents.count {
            documents[currentIndex].content = tv.text ?? ""
        }
        currentIndex = index
        rebuildEditor(for: documents[index])
        refreshTabBar()
        tabBar.selectTab(index)
    }

    private func refreshTabBar() {
        let titles = documents.map { $0.displayName }
        let modified = documents.map { $0.isModified }
        tabBar.setTabs(titles, modified: modified)
        tabBar.selectTab(currentIndex)
    }

    // MARK: - Editor View

    private func rebuildEditor(for doc: EditorDocument) {
        scrollView?.removeFromSuperview()
        textView = nil

        // scrollableTextView returns NSScrollView; documentView is the STTextView
        let sv = STTextView.scrollableTextView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        editorContainer.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: editorContainer.topAnchor),
            sv.leadingAnchor.constraint(equalTo: editorContainer.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: editorContainer.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: editorContainer.bottomAnchor),
        ])

        guard let tv = sv.documentView as? STTextView else { return }

        let cfg = ConfigManager.shared.config
        let font = NSFont(name: cfg.fontName, size: cfg.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: cfg.fontSize, weight: .regular)

        tv.font = font
        tv.textColor = .labelColor
        tv.text = doc.content
        tv.isEditable = true
        tv.isSelectable = true
        tv.showsLineNumbers = true
        tv.highlightSelectedLine = true
        tv.isHorizontallyResizable = false
        tv.delegate = self

        scrollView = sv
        textView = tv
    }

    // MARK: - Save

    func saveCurrentDocument() {
        guard currentIndex < documents.count else { return }
        let doc = documents[currentIndex]
        if let tv = textView { doc.content = tv.text ?? "" }
        if doc.url != nil {
            doc.save()
            refreshTabBar()
        } else {
            saveAs()
        }
    }

    func saveAs() {
        guard currentIndex < documents.count, let window = view.window else { return }
        let doc = documents[currentIndex]
        if let tv = textView { doc.content = tv.text ?? "" }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = doc.displayName
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            doc.saveAs(to: url)
            self?.refreshTabBar()
        }
    }

    // MARK: - Find

    func showFindBar() {
        guard let fb = findBar else { return }
        fb.isHidden = false
        findBarHeightConstraint.constant = 36
        fb.focus()
    }

    func hideFindBar() {
        guard let fb = findBar else { return }
        fb.isHidden = true
        findBarHeightConstraint.constant = 0
        textView?.window?.makeFirstResponder(textView)
    }

    // MARK: - Key commands

    /// Called by the macOS responder chain when File > Save (Cmd+S) is triggered.
    @objc func saveDocument(_ sender: Any?) {
        saveCurrentDocument()
    }

    /// Called by the macOS responder chain when File > Save As (Shift+Cmd+S) is triggered.
    @objc func saveDocumentAs(_ sender: Any?) {
        saveAs()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command {
            switch event.charactersIgnoringModifiers {
            case "f": showFindBar(); return
            case "w": closeCurrentTab(); return
            default: break
            }
        }
        super.keyDown(with: event)
    }

    private func closeCurrentTab() {
        guard !documents.isEmpty else { return }
        let doc = documents[currentIndex]
        if doc.isModified {
            confirmClose(doc) { [weak self] confirmed in
                guard confirmed else { return }
                self?.removeTab(at: self!.currentIndex)
            }
        } else {
            removeTab(at: currentIndex)
        }
    }

    private func removeTab(at index: Int) {
        documents.remove(at: index)
        if documents.isEmpty {
            openDocument(EditorDocument(untitled: ""))
        } else {
            switchToTab(max(0, index - 1))
        }
        refreshTabBar()
    }

    private func confirmClose(_ doc: EditorDocument, completion: @escaping (Bool) -> Void) {
        guard let window = view.window else { completion(true); return }
        let alert = NSAlert()
        alert.messageText = "Close \"\(doc.displayName)\"?"
        alert.informativeText = "You have unsaved changes."
        alert.addButton(withTitle: "Close Anyway")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }

    // MARK: - Notifications

    @objc private func openFileNotification(_ note: Notification) {
        guard let url = note.userInfo?["url"] as? URL else { return }
        openFile(url)
        // Return focus to the terminal so the user can keep typing
        NotificationCenter.default.post(name: .focusTerminal, object: nil)
    }
}

// MARK: - TabBarViewDelegate

extension EditorPaneVC: TabBarViewDelegate {

    func tabBar(_ bar: TabBarView, didSelectTab index: Int) {
        switchToTab(index)
    }

    func tabBar(_ bar: TabBarView, didCloseTab index: Int) {
        removeTab(at: index)
    }

    func tabBarDidRequestNewTab(_ bar: TabBarView) {
        openDocument(EditorDocument(untitled: ""))
    }
}

// MARK: - STTextViewDelegate

extension EditorPaneVC: STTextViewDelegate {

    func textViewDidChangeText(_ notification: Notification) {
        guard currentIndex < documents.count, let tv = textView else { return }
        let doc = documents[currentIndex]
        let wasModified = doc.isModified
        doc.content = tv.text ?? ""
        doc.isModified = true
        if !wasModified { refreshTabBar() }
    }
}

// MARK: - FindBarViewDelegate

extension EditorPaneVC: FindBarViewDelegate {

    func findBar(_ bar: FindBarView, searchFor searchText: String, forward: Bool) {
        guard let tv = textView, !searchText.isEmpty else { return }
        let fullText = tv.text ?? ""

        let currentSel = tv.textSelection
        let searchOptions: String.CompareOptions = forward
            ? [.caseInsensitive]
            : [.caseInsensitive, .backwards]

        let startOffset = forward
            ? min(currentSel.upperBound + 1, fullText.count)
            : max(currentSel.location, 0)

        let startIdx = fullText.index(fullText.startIndex, offsetBy: min(startOffset, fullText.count))
        let endIdx = forward ? fullText.endIndex : startIdx

        let searchRange = forward
            ? startIdx..<fullText.endIndex
            : fullText.startIndex..<startIdx

        let foundRange = fullText.range(of: searchText, options: searchOptions, range: searchRange)
            ?? fullText.range(of: searchText, options: searchOptions)

        guard let range = foundRange else { return }
        let nsRange = NSRange(range, in: fullText)
        tv.textSelection = nsRange
        tv.scrollRangeToVisible(nsRange)
    }

    func findBarDidClose(_ bar: FindBarView) {
        hideFindBar()
    }
}
