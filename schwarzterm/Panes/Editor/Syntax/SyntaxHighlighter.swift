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
    static var keyword:     NSColor { ThemeManager.shared.current.syntaxKeyword.nsColor }
    static var string:      NSColor { ThemeManager.shared.current.syntaxString.nsColor }
    static var comment:     NSColor { ThemeManager.shared.current.syntaxComment.nsColor }
    static var number:      NSColor { ThemeManager.shared.current.syntaxNumber.nsColor }
    static var typeName:    NSColor { ThemeManager.shared.current.syntaxTypeName.nsColor }
    static var attribute:   NSColor { ThemeManager.shared.current.syntaxAttribute.nsColor }
    static var `operator`:  NSColor { ThemeManager.shared.current.syntaxOperator.nsColor }
    static var punctuation: NSColor { ThemeManager.shared.current.syntaxPunctuation.nsColor }
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
