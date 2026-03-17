// Config/Notifications.swift
import Foundation

extension Notification.Name {
    /// Posted by FilePaneVC when a file should be opened in the editor.
    /// userInfo key: "url" -> URL
    static let openFileInEditor = Notification.Name("schwarzterm.openFileInEditor")

    /// Posted by TerminalPaneVC when the working directory changes.
    /// userInfo key: "url" -> URL
    static let terminalDirectoryChanged = Notification.Name("schwarzterm.terminalDirectoryChanged")
}
