// Panes/Editor/Syntax/PythonHighlighter.swift
import AppKit

struct PythonHighlighter: SyntaxHighlighter {

    private static let keywords = [
        "False", "None", "True", "and", "as", "assert", "async", "await",
        "break", "class", "continue", "def", "del", "elif", "else", "except",
        "finally", "for", "from", "global", "if", "import", "in", "is",
        "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try",
        "while", "with", "yield"
    ]

    private static let builtins = [
        "print", "len", "range", "type", "int", "str", "float", "list",
        "dict", "set", "tuple", "bool", "open", "super", "self", "cls",
        "isinstance", "hasattr", "getattr", "setattr", "enumerate", "zip",
        "map", "filter", "sorted", "reversed", "any", "all", "min", "max",
        "sum", "abs", "round", "input", "repr", "id", "dir", "vars",
        "object", "property", "staticmethod", "classmethod"
    ]

    func highlight(_ text: String) -> [(NSRange, NSColor)] {
        var results: [(NSRange, NSColor)] = []

        // 1. Triple-quoted strings (before single-quoted)
        let tripleDouble = syntaxMatches(pattern: #"\"\"\"[\s\S]*?\"\"\""#, in: text, options: .dotMatchesLineSeparators)
        let tripleSingle = syntaxMatches(pattern: #"'''[\s\S]*?'''"#,       in: text, options: .dotMatchesLineSeparators)
        let tripleStrings = tripleDouble + tripleSingle
        results += tripleStrings.map { ($0, SyntaxColor.string) }

        // 2. Single-line strings
        let doubleStr = syntaxMatches(pattern: #"[bBfFrRuU]*"(?:[^"\\]|\\.)*""#, in: text, excluding: tripleStrings)
        let singleStr = syntaxMatches(pattern: #"[bBfFrRuU]*'(?:[^'\\]|\\.)*'"#, in: text, excluding: tripleStrings)
        let allStrings = tripleStrings + doubleStr + singleStr
        results += (doubleStr + singleStr).map { ($0, SyntaxColor.string) }

        // 3. Comments — after strings so # inside a string isn't colored
        let comments = syntaxMatches(pattern: #"#[^\n]*"#, in: text, excluding: allStrings)
        results += comments.map { ($0, SyntaxColor.comment) }

        let excluded = allStrings + comments

        // 4. Decorators
        let decorators = syntaxMatches(pattern: #"@[A-Za-z_]\w*"#, in: text, excluding: excluded)
        results += decorators.map { ($0, SyntaxColor.attribute) }

        // 5. Keywords
        let kwPattern = #"\b(?:"# + Self.keywords.joined(separator: "|") + #")\b"#
        let keywords = syntaxMatches(pattern: kwPattern, in: text, excluding: excluded)
        results += keywords.map { ($0, SyntaxColor.keyword) }

        // 6. Built-ins
        let biPattern = #"\b(?:"# + Self.builtins.joined(separator: "|") + #")\b"#
        let builtins = syntaxMatches(pattern: biPattern, in: text, excluding: excluded)
        results += builtins.map { ($0, SyntaxColor.typeName) }

        // 7. Class names
        let classNames = syntaxMatches(pattern: #"(?<=class )[A-Za-z_]\w*"#, in: text, excluding: excluded)
        results += classNames.map { ($0, SyntaxColor.typeName) }

        // 8. Function names
        let funcNames = syntaxMatches(pattern: #"(?<=def )[A-Za-z_]\w*"#, in: text, excluding: excluded)
        results += funcNames.map { ($0, SyntaxColor.attribute) }

        // 9. Numbers
        let numbers = syntaxMatches(pattern: #"\b0x[0-9A-Fa-f]+\b|\b\d+(\.\d+)?([eE][+-]?\d+)?\b"#, in: text, excluding: excluded)
        results += numbers.map { ($0, SyntaxColor.number) }

        return results
    }
}
