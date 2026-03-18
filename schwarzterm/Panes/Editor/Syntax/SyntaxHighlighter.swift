// Panes/Editor/Syntax/SyntaxHighlighter.swift
import AppKit

// MARK: - Protocol

protocol SyntaxHighlighter {
    /// Returns an ordered list of (range, color) pairs to apply to the full text.
    func highlight(_ text: String) -> [(NSRange, NSColor)]
}

/// Factory: returns the right highlighter for a given file extension, or nil.
func makeSyntaxHighlighter(forExtension ext: String) -> SyntaxHighlighter? {
    switch ext.lowercased() {
    case "md", "markdown":  return MarkdownHighlighter()
    case "py":              return PythonHighlighter()
    case "html", "htm":     return HTMLHighlighter()
    case "js", "mjs":       return JavaScriptHighlighter()
    case "css":             return CSSHighlighter()
    default:                return nil
    }
}

// MARK: - Color Palette

enum SyntaxColor {
    static let keyword    = NSColor(red: 0.56, green: 0.70, blue: 1.00, alpha: 1)
    static let string     = NSColor(red: 0.80, green: 0.55, blue: 0.40, alpha: 1)
    static let comment    = NSColor(white: 0.45, alpha: 1)
    static let number     = NSColor(red: 0.70, green: 0.90, blue: 0.65, alpha: 1)
    static let typeName   = NSColor(red: 0.85, green: 0.75, blue: 0.45, alpha: 1)
    static let attribute  = NSColor(red: 0.70, green: 0.85, blue: 0.60, alpha: 1)
    static let `operator` = NSColor(white: 0.75, alpha: 1)
    static let punctuation = NSColor(white: 0.60, alpha: 1)
}

// MARK: - Shared Regex Helper

/// Returns all non-overlapping match ranges for `pattern` in `text`.
/// Matches overlapping any range in `excluded` are skipped.
func syntaxMatches(
    pattern: String,
    in text: String,
    options: NSRegularExpression.Options = [],
    excluding excluded: [NSRange] = []
) -> [NSRange] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
    let full = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: full).compactMap { match -> NSRange? in
        let r = match.range
        guard r.location != NSNotFound else { return nil }
        if excluded.contains(where: { NSIntersectionRange($0, r).length > 0 }) { return nil }
        return r
    }
}
