// Panes/FileManager/FileItem.swift
import Foundation

class FileItem: NSObject {
    let url: URL
    let isDirectory: Bool
    var children: [FileItem]?   // nil = not yet loaded; [] = loaded, empty
    var isLoaded: Bool { children != nil }

    var name: String { url.lastPathComponent }
    var displayName: String { name.isEmpty ? url.path : name }

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    static func root(at url: URL) -> FileItem {
        let item = FileItem(url: url, isDirectory: true)
        item.loadChildren()
        return item
    }

    func loadChildren() {
        guard isDirectory else { children = []; return }
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .nameKey]
        guard let contents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsSubdirectoryDescendants]
        ) else {
            children = []
            return
        }
        children = contents
            .filter { url in
                let hidden = (try? url.resourceValues(forKeys: [.isHiddenKey]))?.isHidden ?? false
                return !hidden
            }
            .map { childURL -> FileItem in
                let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return FileItem(url: childURL, isDirectory: isDir)
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }
}
