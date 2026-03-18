// Panes/Editor/Syntax/CSSHighlighter.swift
import AppKit

struct CSSHighlighter: SyntaxHighlighter {

    func highlight(_ text: String) -> [(NSRange, NSColor)] {
        var results: [(NSRange, NSColor)] = []

        // 1. Comments first
        let comments = syntaxMatches(pattern: #"/\*[\s\S]*?\*/"#, in: text, options: .dotMatchesLineSeparators)
        results += comments.map { ($0, SyntaxColor.comment) }

        // 2. Strings
        let strings = syntaxMatches(pattern: #""[^"]*"|'[^']*'"#, in: text, excluding: comments)
        results += strings.map { ($0, SyntaxColor.string) }

        let excluded = comments + strings

        // 3. At-rules (@media, @keyframes, etc.)
        let atRules = syntaxMatches(pattern: #"@[a-zA-Z-]+"#, in: text, excluding: excluded)
        results += atRules.map { ($0, SyntaxColor.attribute) }

        // 4. Selectors — text before { on the same logical block
        //    Simple heuristic: match from start-of-line (or after }) up to the {
        let selectors = syntaxMatches(
            pattern: #"(?:^|(?<=\}))\s*([^{}/]+)(?=\s*\{)"#,
            in: text,
            options: [.anchorsMatchLines, .dotMatchesLineSeparators],
            excluding: excluded
        )
        results += selectors.map { ($0, SyntaxColor.typeName) }

        // 5. !important
        let important = syntaxMatches(pattern: #"!important\b"#, in: text, excluding: excluded)
        results += important.map { ($0, SyntaxColor.keyword) }

        // 6. Property names (word followed by :, inside a rule block)
        let properties = syntaxMatches(pattern: #"\b--?[a-zA-Z][a-zA-Z0-9-]*(?=\s*:)"#, in: text, excluding: excluded)
        results += properties.map { ($0, SyntaxColor.keyword) }

        // 7. Hex colors
        let hexColors = syntaxMatches(pattern: #"#[0-9A-Fa-f]{3,8}\b"#, in: text, excluding: excluded)
        results += hexColors.map { ($0, SyntaxColor.number) }

        // 8. Numbers with optional units
        let numbers = syntaxMatches(
            pattern: #"\b\d+(\.\d+)?(px|em|rem|%|vh|vw|vmin|vmax|pt|pc|cm|mm|in|s|ms|deg|rad|turn|fr|ch|ex|lh)?\b"#,
            in: text,
            excluding: excluded + hexColors
        )
        results += numbers.map { ($0, SyntaxColor.number) }

        // 9. Pseudo-elements (:: before pseudo-classes)
        let pseudoElements = syntaxMatches(pattern: #"::[a-zA-Z][a-zA-Z0-9-]*"#, in: text, excluding: excluded)
        results += pseudoElements.map { ($0, SyntaxColor.attribute) }

        // 10. Pseudo-classes
        let pseudoClasses = syntaxMatches(pattern: #"(?<!:):[a-zA-Z][a-zA-Z0-9-]*(?!\()"#, in: text, excluding: excluded + pseudoElements)
        results += pseudoClasses.map { ($0, SyntaxColor.attribute) }

        // 11. Punctuation
        let punctuation = syntaxMatches(pattern: #"[{}:;,]"#, in: text, excluding: excluded)
        results += punctuation.map { ($0, SyntaxColor.punctuation) }

        return results
    }
}
