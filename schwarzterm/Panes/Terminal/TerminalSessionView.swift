// Panes/Terminal/TerminalSessionView.swift
import AppKit
import SwiftTerm

/// A single PTY terminal session view. Wraps LocalProcessTerminalView and
/// handles the delegate externally via an inner helper.
class TerminalSessionView: LocalProcessTerminalView {

    private var sessionDelegate: SessionDelegate?
    private(set) var shellStarted = false

    /// Persistent name for this session, assigned at creation and preserved across drag-and-drop.
    var sessionName: String = "Terminal"

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
        applyTheme()
    }

    /// Re-applies theme colors to the terminal. Called on init and when the theme changes.
    func applyTheme() {
        let t = ThemeManager.shared.current
        nativeBackgroundColor = t.terminalBackground.nsColor
        nativeForegroundColor = t.terminalForeground.nsColor
    }

    /// OSC 5000 — emitted by the `e` shell function to open a file in the editor.
    /// OSC 5001 — emitted by the `o` shell function to open a directory in the file pane.
    /// Sequence: ESC ] <code> ; /absolute/path BEL
    private func registerOscHandlers() {
        terminal.parser.oscHandlers[5000] = { [weak self] data in
            guard let path = String(bytes: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else { return }
            let url = URL(fileURLWithPath: path)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .openFileInEditor,
                    object: self,
                    userInfo: ["url": url]
                )
            }
        }
        terminal.parser.oscHandlers[5001] = { [weak self] data in
            guard let path = String(bytes: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else { return }
            let url = URL(fileURLWithPath: path)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .openDirectoryInFilePane,
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

        // Get the full login PATH by running the shell as a login shell.
        // GUI apps on macOS inherit a stripped PATH; this captures what the
        // user's shell would have after sourcing /etc/profile and ~/.profile etc.
        var envDict = ProcessInfo.processInfo.environment
        if let loginPath = Self.loginPath(shell: cfg.shell) {
            envDict["PATH"] = loginPath
        }
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

        // The `e` function: resolve the path and emit OSC 5000 (open file in editor).
        let eFunc = #"e() { local p; p=$(realpath "$1" 2>/dev/null || readlink -f "$1" 2>/dev/null || echo "$1"); printf '\033]5000;%s\007' "$p"; }"#
        // The `o` function: resolve the path and emit OSC 5001 (open directory in file pane).
        let oFunc = #"o() { local p; p=$(realpath "${1:-.}" 2>/dev/null || readlink -f "${1:-.}" 2>/dev/null || echo "${1:-.}"); printf '\033]5001;%s\007' "$p"; }"#

        // zsh: source user's real ~/.zshrc after defining our functions
        let zshRC = """
            \(eFunc)
            \(oFunc)
            [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"
            """
        // bash: similar
        let bashRC = """
            \(eFunc)
            \(oFunc)
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

    /// Runs the shell as a login shell and captures $PATH, giving us the full
    /// user PATH including Homebrew, nvm, pyenv, etc. Returns nil on failure.
    private static func loginPath(shell: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        // -l = login shell (sources /etc/profile, ~/.profile, ~/.zprofile etc.)
        // -c = run command and exit
        process.arguments = ["-l", "-c", "echo $PATH"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // suppress any error output
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
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
        // SwiftTerm emits OSC 7 as a full file:// URL (e.g. "file://hostname/path").
        // Parse it properly so we get the local path, not a broken re-wrapped URL.
        let url: URL
        if dir.hasPrefix("file://"), let parsed = URL(string: dir) {
            url = URL(fileURLWithPath: parsed.path)
        } else {
            url = URL(fileURLWithPath: dir)
        }
        NotificationCenter.default.post(
            name: .terminalDirectoryChanged,
            object: source,
            userInfo: ["url": url]
        )
    }
}
