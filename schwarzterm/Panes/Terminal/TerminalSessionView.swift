// Panes/Terminal/TerminalSessionView.swift
import AppKit
import SwiftTerm

/// A single PTY terminal session view. Wraps LocalProcessTerminalView and
/// handles the delegate externally via an inner helper.
class TerminalSessionView: LocalProcessTerminalView {

    private var sessionDelegate: SessionDelegate?
    private(set) var shellStarted = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        let d = SessionDelegate(owner: self)
        sessionDelegate = d
        processDelegate = d
        configureAppearance()
        setupClickFocus()
        registerOscHandlers()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configureAppearance() {
        let cfg = ConfigManager.shared.config
        let font = NSFont(name: cfg.fontName, size: cfg.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: cfg.fontSize, weight: .regular)
        self.font = font
        nativeBackgroundColor = NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        nativeForegroundColor = NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1)
    }

    /// OSC 5000 — emitted by the `e` shell function to open a file in the editor.
    /// Sequence: ESC ] 5000 ; /absolute/path BEL
    private func registerOscHandlers() {
        terminal.parser.oscHandlers[5000] = { [weak self] data in
            guard let path = String(bytes: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else { return }
            let url = path.hasPrefix("/") ? URL(fileURLWithPath: path)
                                          : URL(fileURLWithPath: path)   // startShell cwd not tracked here; shell resolves absolute
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .openFileInEditor,
                    object: self,
                    userInfo: ["url": url]
                )
            }
        }
    }

    func startShell() {
        guard !shellStarted else { return }
        shellStarted = true
        let cfg = ConfigManager.shared.config

        // Start from the full inherited process environment so PATH and all
        // user-installed tools (homebrew, npm globals, etc.) are available.
        // Then overlay SwiftTerm's terminal-specific variables on top.
        var envDict = ProcessInfo.processInfo.environment
        for entry in Terminal.getEnvironmentVariables(termName: "xterm-256color") {
            let parts = entry.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { envDict[String(parts[0])] = String(parts[1]) }
        }
        var env = envDict.map { "\($0.key)=\($0.value)" }

        // Inject the `e` shell function at startup via a temp init file.
        // `e file.txt` emits OSC 5000 with the resolved absolute path, which
        // TerminalSessionView intercepts to open the file in the editor pane.
        if let zdotdir = writeShellInitFile() {
            env.append("ZDOTDIR=\(zdotdir)")    // zsh sources $ZDOTDIR/.zshrc
            env.append("BASH_ENV=\(zdotdir)/.bashrc")  // bash sources $BASH_ENV for interactive
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        startProcess(executable: cfg.shell, args: [], environment: env, execName: nil, currentDirectory: home)
    }

    /// Writes a temp directory containing .zshrc / .bashrc that define the `e` function
    /// and then source the user's real rc file, returning the directory path.
    private func writeShellInitFile() -> String? {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("schwarzterm-shell-\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        // The `e` function: resolve the path and emit OSC 5000.
        let eFunc = #"e() { local p; p=$(realpath "$1" 2>/dev/null || readlink -f "$1" 2>/dev/null || echo "$1"); printf '\033]5000;%s\007' "$p"; }"#

        // zsh: source user's real ~/.zshrc after defining our function
        let zshRC = """
            \(eFunc)
            [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"
            """
        // bash: similar
        let bashRC = """
            \(eFunc)
            [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
            [ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile"
            """

        let zshPath = tmp.appendingPathComponent(".zshrc")
        let bashPath = tmp.appendingPathComponent(".bashrc")
        try? zshRC.write(to: zshPath, atomically: true, encoding: .utf8)
        try? bashRC.write(to: bashPath, atomically: true, encoding: .utf8)
        return tmp.path
    }

    /// Reset started flag when shell terminates so it can be restarted
    func shellDidTerminate() {
        shellStarted = false
    }

    // Grab focus on click via gesture recognizer
    private func setupClickFocus() {
        let gr = NSClickGestureRecognizer(target: self, action: #selector(grabFocus))
        gr.numberOfClicksRequired = 1
        addGestureRecognizer(gr)
    }

    @objc private func grabFocus() {
        window?.makeFirstResponder(self)
    }
}

// MARK: - Inner Delegate

private class SessionDelegate: LocalProcessTerminalViewDelegate {

    weak var owner: TerminalSessionView?

    init(owner: TerminalSessionView) {
        self.owner = owner
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.owner?.shellDidTerminate()
            self?.owner?.startShell()
        }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let dir = directory else { return }
        NotificationCenter.default.post(
            name: .terminalDirectoryChanged,
            object: source,
            userInfo: ["url": URL(fileURLWithPath: dir)]
        )
    }
}
