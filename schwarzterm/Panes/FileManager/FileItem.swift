// Panes/FileManager/FileItem.swift
import Foundation

final class FileItem: NSObject {
    let url: URL
    let isDirectory: Bool
    private(set) var children: [FileItem]?  // nil = not loaded yet

    var isLoaded: Bool { children != nil }
    var name: String { url.lastPathComponent }
    var displayName: String { name.isEmpty ? url.path : name }

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    static func root(at url: URL) -> FileItem {
        let item = FileItem(url: url, isDirectory: true)
        item.reload()
        return item
    }

    /// Load or refresh children from disk.
    func reload() {
        guard isDirectory else { children = []; return }
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            children = []
            return
        }
        // Preserve existing child objects so the outline view can track identity
        var existing: [URL: FileItem] = [:]
        for child in children ?? [] { existing[child.url] = child }

        children = contents
            .map { childURL -> FileItem in
                let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if let old = existing[childURL], old.isDirectory == isDir { return old }
                return FileItem(url: childURL, isDirectory: isDir)
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }
}
