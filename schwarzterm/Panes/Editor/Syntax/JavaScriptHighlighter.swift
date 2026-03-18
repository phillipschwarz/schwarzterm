// Panes/Editor/Syntax/JavaScriptHighlighter.swift
import AppKit

struct JavaScriptHighlighter: SyntaxHighlighter {

    private static let keywords = [
        "break", "case", "catch", "class", "const", "continue", "debugger",
        "default", "delete", "do", "else", "export", "extends", "finally",
        "for", "function", "if", "import", "in", "instanceof", "let", "new",
        "return", "static", "super", "switch", "this", "throw", "try",
        "typeof", "var", "void", "while", "with", "yield", "async", "await", "of"
    ]

    private static let builtins = [
        "Array", "Boolean", "Date", "Error", "Function", "JSON", "Math",
        "Number", "Object", "Promise", "RegExp", "String", "Symbol",
        "Map", "Set", "WeakMap", "WeakSet", "console", "document", "window",
        "undefined", "null", "true", "false", "NaN", "Infinity",
        "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI",
        "decodeURI", "setTimeout", "setInterval", "clearTimeout", "clearInterval"
    ]

    func highlight(_ text: String) -> [(NSRange, NSColor)] {
        var results: [(NSRange, NSColor)] = []

        // 1. Block comments
        let blockComments = syntaxMatches(pattern: #"/\*[\s\S]*?\*/"#, in: text, options: .dotMatchesLineSeparators)
        results += blockComments.map { ($0, SyntaxColor.comment) }

        // 2. Template literals
        let templateLiterals = syntaxMatches(pattern: #"`(?:[^`\\]|\\.)*`"#, in: text, options: .dotMatchesLineSeparators, excluding: blockComments)
        results += templateLiterals.map { ($0, SyntaxColor.string) }

        // 3. Double-quoted strings
        let doubleStr = syntaxMatches(pattern: #""(?:[^"\\]|\\.)*""#, in: text, excluding: blockComments + templateLiterals)
        results += doubleStr.map { ($0, SyntaxColor.string) }

        // 4. Single-quoted strings
        let singleStr = syntaxMatches(pattern: #"'(?:[^'\\]|\\.)*'"#, in: text, excluding: blockComments + templateLiterals + doubleStr)
        results += singleStr.map { ($0, SyntaxColor.string) }

        let allStrings = templateLiterals + doubleStr + singleStr

        // 5. Line comments — after strings so // inside a string is ignored
        let lineComments = syntaxMatches(pattern: #"//[^\n]*"#, in: text, excluding: blockComments + allStrings)
        results += lineComments.map { ($0, SyntaxColor.comment) }

        let excluded = blockComments + allStrings + lineComments

        // 6. Keywords
        let kwPattern = #"\b(?:"# + Self.keywords.joined(separator: "|") + #")\b"#
        let keywords = syntaxMatches(pattern: kwPattern, in: text, excluding: excluded)
        results += keywords.map { ($0, SyntaxColor.keyword) }

        // 7. Built-ins / globals
        let biPattern = #"\b(?:"# + Self.builtins.joined(separator: "|") + #")\b"#
        let builtins = syntaxMatches(pattern: biPattern, in: text, excluding: excluded)
        results += builtins.map { ($0, SyntaxColor.typeName) }

        // 8. Class names
        let classNames = syntaxMatches(pattern: #"(?<=class )[A-Za-z_$][\w$]*"#, in: text, excluding: excluded)
        results += classNames.map { ($0, SyntaxColor.typeName) }

        // 9. Function names
        let funcNames = syntaxMatches(pattern: #"(?<=function )[A-Za-z_$][\w$]*"#, in: text, excluding: excluded)
        results += funcNames.map { ($0, SyntaxColor.attribute) }

        // 10. Numbers
        let numbers = syntaxMatches(pattern: #"\b0x[0-9A-Fa-f]+\b|\b\d+(\.\d+)?([eE][+-]?\d+)?\b"#, in: text, excluding: excluded)
        results += numbers.map { ($0, SyntaxColor.number) }

        // 11. Operators
        let operators = syntaxMatches(pattern: #"=>|===|!==|>=|<=|&&|\|\||\?\?|[+\-*/%&|^~!]=?"#, in: text, excluding: excluded)
        results += operators.map { ($0, SyntaxColor.operator) }

        return results
    }
}
