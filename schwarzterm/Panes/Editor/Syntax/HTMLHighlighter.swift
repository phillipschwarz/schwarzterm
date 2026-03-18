// Panes/Editor/Syntax/HTMLHighlighter.swift
import AppKit

struct HTMLHighlighter: SyntaxHighlighter {

    func highlight(_ text: String) -> [(NSRange, NSColor)] {
        var results: [(NSRange, NSColor)] = []

        // 1. Comments — must come first
        let comments = syntaxMatches(pattern: #"<!--[\s\S]*?-->"#, in: text, options: .dotMatchesLineSeparators)
        results += comments.map { ($0, SyntaxColor.comment) }

        // 2. DOCTYPE
        let doctype = syntaxMatches(pattern: #"<!DOCTYPE[^>]*>"#, in: text, options: .caseInsensitive, excluding: comments)
        results += doctype.map { ($0, SyntaxColor.comment) }

        let excluded = comments + doctype

        // 3. Attribute values (before tag names so they get their own color)
        let attrValues = syntaxMatches(pattern: #""[^"]*"|'[^']*'"#, in: text, excluding: excluded)
        results += attrValues.map { ($0, SyntaxColor.string) }

        // 4. Tag names
        let tagNames = syntaxMatches(pattern: #"(?<=</?)[A-Za-z][A-Za-z0-9-]*"#, in: text, excluding: excluded + attrValues)
        results += tagNames.map { ($0, SyntaxColor.keyword) }

        // 5. Attribute names (word before =)
        let attrNames = syntaxMatches(pattern: #"\b[a-zA-Z][a-zA-Z0-9-]*(?=\s*=)"#, in: text, excluding: excluded + attrValues + tagNames)
        results += attrNames.map { ($0, SyntaxColor.attribute) }

        // 6. HTML entities
        let entities = syntaxMatches(pattern: #"&[a-zA-Z0-9#]+;"#, in: text, excluding: excluded)
        results += entities.map { ($0, SyntaxColor.number) }

        // 7. Angle brackets and slashes
        let punctuation = syntaxMatches(pattern: #"[<>]|<\/|\/"#, in: text, excluding: excluded)
        results += punctuation.map { ($0, SyntaxColor.punctuation) }

        return results
    }
}
