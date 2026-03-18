// Panes/Editor/EditorPaneVC.swift
import AppKit
import STTextView

class EditorPaneVC: NSViewController, PaneProtocol {

    var paneTitle: String { "Editor" }

    // MARK: - UI

    private let tabBar         = TabBarView()
    private let editorStack    = NSView()   // container; each tab's scrollView is a subview
    private let welcomeView    = NSView()
    private var findBar: FindBarView?
    private var findBarHeightConstraint: NSLayoutConstraint!

    // MARK: - State

    /// One entry per open tab. The scrollView/textView stay alive for the
    /// lifetime of the tab so scroll position, undo history etc. are preserved.
    private struct Tab {
        let doc:        EditorDocument
        let scrollView: NSScrollView
        let textView:   STTextView
    }

    private var tabs: [Tab] = []
    private var currentIndex: Int = 0

    private var currentTextView: STTextView? {
        guard currentIndex < tabs.count else { return nil }
        return tabs[currentIndex].textView
    }

    /// Debounce token for syntax highlighting
    private var highlightWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupEditorStack()
        setupWelcomeView()
        setupFindBar()
        observeNotifications()
    }

    // MARK: - Setup

    private func setupTabBar() {
        tabBar.delegate = self
        tabBar.isHidden = true
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    private func setupEditorStack() {
        editorStack.wantsLayer = true
        editorStack.layer?.masksToBounds = true
        editorStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editorStack)
        NSLayoutConstraint.activate([
            editorStack.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            editorStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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
            fb.topAnchor.constraint(equalTo: editorStack.bottomAnchor),
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(focusEditorNotification),
            name: .focusEditor,
            object: nil
        )
    }

    // MARK: - Welcome View

    private func setupWelcomeView() {
        welcomeView.wantsLayer = true
        welcomeView.layer?.backgroundColor = NSColor(white: 0.11, alpha: 1).cgColor
        welcomeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(welcomeView)
        NSLayoutConstraint.activate([
            welcomeView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            welcomeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            welcomeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            welcomeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let label = NSTextField(labelWithString: "schwarzterm")
        label.font = NSFont.systemFont(ofSize: 28, weight: .thin)
        label.textColor = NSColor(white: 0.35, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.addSubview(label)

        let sub = NSTextField(labelWithString: "open a file to start editing")
        sub.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        sub.textColor = NSColor(white: 0.28, alpha: 1)
        sub.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.addSubview(sub)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: welcomeView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: welcomeView.centerYAnchor, constant: -14),
            sub.centerXAnchor.constraint(equalTo: welcomeView.centerXAnchor),
            sub.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
        ])
    }

    // MARK: - Document / Tab Management

    func openFile(_ url: URL) {
        // If already open, just switch to it
        if let idx = tabs.firstIndex(where: { $0.doc.url == url }) {
            switchToTab(idx)
            return
        }
        addTab(for: EditorDocument(url: url))
    }

    /// Creates a new tab with a fresh STTextView and switches to it.
    private func addTab(for doc: EditorDocument) {
        let (sv, tv) = makeEditorViews(for: doc)
        let tab = Tab(doc: doc, scrollView: sv, textView: tv)

        // Add the scroll view to the stack container but keep it hidden for now
        sv.translatesAutoresizingMaskIntoConstraints = false
        editorStack.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: editorStack.topAnchor),
            sv.leadingAnchor.constraint(equalTo: editorStack.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: editorStack.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: editorStack.bottomAnchor),
        ])
        sv.isHidden = true

        tabs.append(tab)
        welcomeView.isHidden = true
        tabBar.isHidden = false
        switchToTab(tabs.count - 1)
    }

    private func switchToTab(_ index: Int) {
        guard index >= 0, index < tabs.count else { return }

        // Hide current
        if currentIndex < tabs.count {
            tabs[currentIndex].scrollView.isHidden = true
        }

        currentIndex = index

        // Show new
        tabs[currentIndex].scrollView.isHidden = false

        refreshTabBar()
        tabBar.selectTab(index)
        applyHighlighting()
    }

    private func refreshTabBar() {
        let titles   = tabs.map { $0.doc.displayName }
        let modified = tabs.map { $0.doc.isModified }
        tabBar.setTabs(titles, modified: modified)
        tabBar.selectTab(currentIndex)
    }

    // MARK: - Editor View Factory

    private func makeEditorViews(for doc: EditorDocument) -> (NSScrollView, STTextView) {
        let sv = STTextView.scrollableTextView()

        guard let tv = sv.documentView as? STTextView else {
            fatalError("STTextView.scrollableTextView() did not return STTextView as documentView")
        }

        let cfg  = ConfigManager.shared.config
        let font = NSFont(name: cfg.fontName, size: cfg.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: cfg.fontSize, weight: .regular)

        tv.font               = font
        tv.textColor          = .labelColor
        tv.text               = doc.content
        tv.isEditable         = true
        tv.isSelectable       = true
        tv.showsLineNumbers   = true
        tv.highlightSelectedLine = true
        tv.isHorizontallyResizable = false
        tv.textDelegate       = self

        return (sv, tv)
    }

    // MARK: - Syntax Highlighting

    /// Schedules a highlight pass ~150 ms after the last edit.
    private func scheduleHighlight() {
        highlightWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.applyHighlighting() }
        highlightWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    /// Applies syntax colors to the current tab's text storage.
    private func applyHighlighting() {
        guard currentIndex < tabs.count else { return }
        let tab = tabs[currentIndex]
        let ext = tab.doc.url?.pathExtension ?? ""
        guard let highlighter = makeSyntaxHighlighter(forExtension: ext) else { return }

        let textView = tab.textView
        guard let storage = textView.textContentManager as? NSTextContentStorage,
              let nsStorage = storage.textStorage else { return }

        let text = textView.text ?? ""
        let pairs = highlighter.highlight(text)
        let fullRange = NSRange(text.startIndex..., in: text)

        nsStorage.beginEditing()
        // Reset all foreground colors to default first
        nsStorage.removeAttribute(.foregroundColor, range: fullRange)
        nsStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        // Apply highlight pairs
        for (range, color) in pairs {
            guard range.location != NSNotFound,
                  range.location + range.length <= (text as NSString).length else { continue }
            nsStorage.addAttribute(.foregroundColor, value: color, range: range)
        }
        nsStorage.endEditing()
    }

    // MARK: - Save

    func saveCurrentDocument() {
        guard currentIndex < tabs.count else { return }
        let tab = tabs[currentIndex]
        tab.doc.content = tab.textView.text ?? ""
        if tab.doc.url != nil {
            tab.doc.save()
            refreshTabBar()
        } else {
            saveAs()
        }
    }

    func saveAs() {
        guard currentIndex < tabs.count, let window = view.window else { return }
        let tab = tabs[currentIndex]
        tab.doc.content = tab.textView.text ?? ""
        let panel = NSSavePanel()
        panel.nameFieldStringValue = tab.doc.displayName
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            _ = tab.doc.saveAs(to: url)
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
        currentTextView?.window?.makeFirstResponder(currentTextView)
    }

    // MARK: - Close

    func closeCurrentTab() {
        guard !tabs.isEmpty else { return }
        let tab = tabs[currentIndex]
        if tab.doc.isModified {
            confirmClose(tab.doc) { [weak self] confirmed in
                guard confirmed, let self else { return }
                self.removeTab(at: self.currentIndex)
            }
        } else {
            removeTab(at: currentIndex)
        }
    }

    private func removeTab(at index: Int) {
        // Tear down the view
        tabs[index].scrollView.removeFromSuperview()
        tabs.remove(at: index)

        if tabs.isEmpty {
            welcomeView.isHidden = false
            tabBar.isHidden = true
        } else {
            switchToTab(max(0, index - 1))
        }
        refreshTabBar()
    }

    private func confirmClose(_ doc: EditorDocument, completion: @escaping (Bool) -> Void) {
        guard let window = view.window else { completion(true); return }
        let alert = NSAlert()
        alert.messageText     = "Close \"\(doc.displayName)\"?"
        alert.informativeText = "You have unsaved changes."
        alert.addButton(withTitle: "Close Anyway")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }

    // MARK: - Responder chain actions (wired via main menu)

    @objc func saveDocument(_ sender: Any?) {
        saveCurrentDocument()
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        saveAs()
    }

    @objc func showFindBar(_ sender: Any?) {
        showFindBar()
    }

    /// Cmd+Return: insert a new line below the current line, move cursor to it.
    @objc func insertNewlineBelow(_ sender: Any?) {
        guard let tv = currentTextView,
              let text = tv.text as NSString? else { return }
        let cursor = tv.textSelection.location
        // Find the end of the current line
        let lineEnd = text.lineRange(for: NSRange(location: cursor, length: 0)).upperBound - 1
        let insertAt = min(lineEnd, text.length)
        tv.replaceCharacters(in: NSRange(location: insertAt, length: 0), with: "\n")
        tv.textSelection = NSRange(location: insertAt + 1, length: 0)
    }

    @objc func newEditorTab(_ sender: Any?) {
        addTab(for: EditorDocument(untitled: ""))
        if let tv = currentTextView {
            view.window?.makeFirstResponder(tv)
        }
    }

    @objc func closeEditorTab(_ sender: Any?) {
        closeCurrentTab()
    }

    @objc func selectNextTab(_ sender: Any?) {
        guard !tabs.isEmpty else { return }
        switchToTab((currentIndex + 1) % tabs.count)
    }

    @objc func selectPreviousTab(_ sender: Any?) {
        guard !tabs.isEmpty else { return }
        switchToTab((currentIndex - 1 + tabs.count) % tabs.count)
    }

    // MARK: - Notifications

    @objc private func openFileNotification(_ note: Notification) {
        guard let url = note.userInfo?["url"] as? URL else { return }
        openFile(url)
        // Focus the editor text view so the user can start typing immediately.
        NotificationCenter.default.post(name: .focusEditor, object: nil)
    }

    @objc private func focusEditorNotification() {
        guard let tv = currentTextView else { return }
        view.window?.makeFirstResponder(tv)
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
        addTab(for: EditorDocument(untitled: ""))
    }
}

// MARK: - STTextViewDelegate

extension EditorPaneVC: STTextViewDelegate {

    func textView(_ textView: STTextView, shouldChangeTextIn affectedCharRange: NSTextRange, replacementString: String?) -> Bool {
        // Let AutoPairHandler intercept bracket/quote pairs and balanced deletes.
        // Returns false to STTextView when it handled the event itself.
        return !AutoPairHandler.handle(textView: textView, range: affectedCharRange, replacement: replacementString)
    }

    func textViewDidChangeText(_ notification: Notification) {
        guard currentIndex < tabs.count else { return }
        let tab = tabs[currentIndex]
        let wasModified = tab.doc.isModified
        tab.doc.content   = tab.textView.text ?? ""
        tab.doc.isModified = true
        if !wasModified { refreshTabBar() }
        scheduleHighlight()
    }
}

// MARK: - FindBarViewDelegate

extension EditorPaneVC: FindBarViewDelegate {

    func findBar(_ bar: FindBarView, searchFor searchText: String, forward: Bool) {
        guard let tv = currentTextView, !searchText.isEmpty else { return }
        let fullText = tv.text ?? ""

        let currentSel = tv.textSelection
        let searchOptions: String.CompareOptions = forward
            ? [.caseInsensitive]
            : [.caseInsensitive, .backwards]

        let startOffset = forward
            ? min(currentSel.upperBound + 1, fullText.count)
            : max(currentSel.location, 0)

        let startIdx   = fullText.index(fullText.startIndex, offsetBy: min(startOffset, fullText.count))
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
