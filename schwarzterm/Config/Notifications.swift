// Config/Notifications.swift
import Foundation

extension Notification.Name {
    /// Posted by FilePaneVC when a file should be opened in the editor.
    /// userInfo key: "url" -> URL
    static let openFileInEditor = Notification.Name("schwarzterm.openFileInEditor")

    /// Posted by TerminalPaneVC when the working directory changes.
    /// userInfo key: "url" -> URL
    static let terminalDirectoryChanged = Notification.Name("schwarzterm.terminalDirectoryChanged")

    /// Posted when the `o` shell function is used to open a directory in the file pane.
    /// userInfo key: "url" -> URL
    static let openDirectoryInFilePane = Notification.Name("schwarzterm.openDirectoryInFilePane")

    /// Posted when the editor opens a file via the `e` command and focus should return to the terminal.
    static let focusTerminal = Notification.Name("schwarzterm.focusTerminal")

    /// Posted when focus should move to the editor text view (e.g. after `e file` opens a file).
    static let focusEditor = Notification.Name("schwarzterm.focusEditor")

    /// Posted when the active theme changes. Components observe this to re-apply colors.
    static let themeChanged = Notification.Name("schwarzterm.themeChanged")
}
