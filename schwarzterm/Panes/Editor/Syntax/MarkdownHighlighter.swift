// Panes/Editor/Syntax/MarkdownHighlighter.swift
import AppKit

struct MarkdownHighlighter: SyntaxHighlighter {

    func highlight(_ text: String) -> [(NSRange, NSColor)] {
        var results: [(NSRange, NSColor)] = []

        // 1. Fenced code blocks — match first so inner content isn't re-highlighted
        let fenced = syntaxMatches(pattern: #"```[\s\S]*?```"#, in: text, options: .dotMatchesLineSeparators)
        results += fenced.map { ($0, SyntaxColor.comment) }

        // 2. ATX headings
        let headings = syntaxMatches(pattern: #"^#{1,6} .+"#, in: text, options: .anchorsMatchLines, excluding: fenced)
        results += headings.map { ($0, SyntaxColor.keyword) }

        // 3. Bold (**text** or __text__)
        let bold = syntaxMatches(pattern: #"\*\*[^*\n]+\*\*|__[^_\n]+__"#, in: text, excluding: fenced)
        results += bold.map { ($0, SyntaxColor.typeName) }

        // 4. Italic (*text* or _text_) — after bold so ** isn't caught
        let italic = syntaxMatches(pattern: #"(?<!\*)\*(?!\*)[^*\n]+(?<!\*)\*(?!\*)|(?<!_)_(?!_)[^_\n]+(?<!_)_(?!_)"#, in: text, excluding: fenced)
        results += italic.map { ($0, SyntaxColor.string) }

        // 5. Inline code
        let inlineCode = syntaxMatches(pattern: #"`[^`\n]+`"#, in: text, excluding: fenced)
        results += inlineCode.map { ($0, SyntaxColor.number) }

        // 6. Link text [label]
        let linkText = syntaxMatches(pattern: #"\[[^\]\n]+\]"#, in: text, excluding: fenced)
        results += linkText.map { ($0, SyntaxColor.attribute) }

        // 7. Link URL (url) — immediately after ]
        let linkURL = syntaxMatches(pattern: #"(?<=\])\([^)\n]+\)"#, in: text, excluding: fenced)
        results += linkURL.map { ($0, SyntaxColor.string) }

        // 8. Blockquote lines
        let blockquote = syntaxMatches(pattern: #"^>[ \t]?.+"#, in: text, options: .anchorsMatchLines, excluding: fenced)
        results += blockquote.map { ($0, SyntaxColor.comment) }

        // 9. Horizontal rule
        let hr = syntaxMatches(pattern: #"^[-*_]{3,}\s*$"#, in: text, options: .anchorsMatchLines, excluding: fenced)
        results += hr.map { ($0, SyntaxColor.operator) }

        return results
    }
}
