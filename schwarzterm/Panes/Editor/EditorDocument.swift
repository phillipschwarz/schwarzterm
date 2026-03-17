// Panes/Editor/EditorDocument.swift
import Foundation

class EditorDocument {
    let url: URL?
    var content: String
    var isModified: Bool = false

    var displayName: String {
        url?.lastPathComponent ?? "Untitled"
    }

    init(url: URL) {
        self.url = url
        self.content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    init(untitled content: String = "") {
        self.url = nil
        self.content = content
    }

    @discardableResult
    func save() -> Bool {
        guard let url else { return false }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            isModified = false
            return true
        } catch {
            return false
        }
    }

    func saveAs(to newURL: URL) -> Bool {
        do {
            try content.write(to: newURL, atomically: true, encoding: .utf8)
            isModified = false
            return true
        } catch {
            return false
        }
    }
}
