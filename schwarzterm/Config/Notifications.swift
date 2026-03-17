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
}
