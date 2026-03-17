// Panes/FileManager/FileOperations.swift
import AppKit

enum FileOperations {

    @discardableResult
    static func createFile(named name: String, in directory: URL) -> URL? {
        let dest = directory.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: dest.path) else { return nil }
        FileManager.default.createFile(atPath: dest.path, contents: nil)
        return dest
    }

    @discardableResult
    static func createDirectory(named name: String, in directory: URL) -> URL? {
        let dest = directory.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        return dest
    }

    static func rename(_ url: URL, to newName: String) throws -> URL {
        let dest = url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    }

    static func delete(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    static func move(_ url: URL, to destinationDirectory: URL) throws -> URL {
        let dest = destinationDirectory.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    }

    static func copy(_ url: URL, to destinationDirectory: URL) throws -> URL {
        let dest = destinationDirectory.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    /// Show a rename sheet on the given window
    static func presentRenameSheet(for url: URL, in window: NSWindow, completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Rename \"\(url.lastPathComponent)\""
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = url.lastPathComponent
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { response in
            completion(response == .alertFirstButtonReturn ? field.stringValue : nil)
        }
    }
}
