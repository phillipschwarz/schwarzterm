# Syntax Highlighting

## Supported Languages

| Extension(s)       | Highlighter               | Status      |
|--------------------|---------------------------|-------------|
| `.md`, `.markdown` | `MarkdownHighlighter`     | Implemented |
| `.py`              | `PythonHighlighter`       | Implemented |
| `.html`, `.htm`    | `HTMLHighlighter`         | Implemented |
| `.js`, `.mjs`      | `JavaScriptHighlighter`   | Implemented |
| `.css`             | `CSSHighlighter`          | Implemented |

Language detection is done via `doc.url?.pathExtension` in `makeSyntaxHighlighter(forExtension:)` (see `Syntax/SyntaxHighlighter.swift`).

---

This document describes how syntax highlighting is implemented in `EditorPaneVC` for each supported language. Highlighting is applied per-tab using `NSTextStorage` attribute passes after text changes. Patterns are matched via `NSRegularExpression` and colored by applying `.foregroundColor` attributes to matched ranges.

---

## Architecture Notes

- Highlighting runs in `textViewDidChangeText(_:)` (or on tab switch) after debouncing.
- Each language is selected by inspecting `doc.url?.pathExtension.lowercased()`.
- A `SyntaxHighlighter` protocol (or struct) takes the full text string and returns `[(NSRange, NSColor)]` — a list of (range, color) pairs to apply.
- Apply pairs to the text view's `textStorage` inside `beginEditing()` / `endEditing()`.
- Base text color is reset to `.labelColor` before each highlight pass to clear stale attributes.

---

## Color Palette

Use a consistent dark-theme palette across all languages:

| Role       | NSColor suggestion                        |
|------------|-------------------------------------------|
| keyword    | `NSColor(red: 0.56, green: 0.70, blue: 1.0, alpha: 1)` — soft blue/lavender |
| string     | `NSColor(red: 0.80, green: 0.55, blue: 0.40, alpha: 1)` — warm orange |
| comment    | `NSColor(white: 0.45, alpha: 1)` — mid-grey |
| number     | `NSColor(red: 0.70, green: 0.90, blue: 0.65, alpha: 1)` — soft green |
| type/class | `NSColor(red: 0.85, green: 0.75, blue: 0.45, alpha: 1)` — gold/yellow |
| tag        | `NSColor(red: 0.56, green: 0.70, blue: 1.0, alpha: 1)` — same as keyword |
| attribute  | `NSColor(red: 0.70, green: 0.85, blue: 0.60, alpha: 1)` — light green |
| operator   | `NSColor(white: 0.75, alpha: 1)` — light grey |
| punctuation| `NSColor(white: 0.60, alpha: 1)` — mid-grey |

---

## Markdown (`.md`)

Markdown is structural: headings, emphasis, code, links, blockquotes.

### Patterns

| Element           | Regex pattern                                          | Color     |
|-------------------|--------------------------------------------------------|-----------|
| ATX headings      | `^#{1,6} .+`  (multiline)                             | keyword   |
| Bold              | `\*\*[^*]+\*\*` or `__[^_]+__`                        | type/class|
| Italic            | `\*[^*]+\*` or `_[^_]+_`                              | string    |
| Inline code       | `` `[^`]+` ``                                         | number    |
| Fenced code block | ```` ```[\s\S]*?``` ```` (multiline, non-greedy)      | comment   |
| Link text         | `\[[^\]]+\]`                                          | attribute |
| Link URL          | `\([^)]+\)`                                           | string    |
| Blockquote        | `^> .+` (multiline)                                   | comment   |
| HR / separator    | `^[-*_]{3,}\s*$` (multiline)                          | operator  |

### Notes
- Apply fenced code block pattern **before** inline code to avoid partial matches.
- Do not highlight inside fenced code blocks (skip other patterns over those ranges).

---

## Python (`.py`)

### Patterns

| Element           | Regex pattern                                                    | Color     |
|-------------------|------------------------------------------------------------------|-----------|
| Keywords          | `\b(False|None|True|and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield)\b` | keyword |
| Built-ins         | `\b(print|len|range|type|int|str|float|list|dict|set|tuple|bool|open|super|self|cls|isinstance|hasattr|getattr|setattr|enumerate|zip|map|filter|sorted|reversed|any|all|min|max|sum|abs|round)\b` | type/class |
| Decorator         | `@[A-Za-z_]\w*`                                                 | attribute |
| String (double)   | `"(?:[^"\\]|\\.)*"`                                              | string    |
| String (single)   | `'(?:[^'\\]|\\.)*'`                                              | string    |
| Triple-double str | `"""[\s\S]*?"""` (non-greedy)                                   | string    |
| Triple-single str | `'''[\s\S]*?'''` (non-greedy)                                   | string    |
| f-string prefix   | `\bf?r?"` or `\bf?r?'` prefix handling — treat whole as string  | string    |
| Comment           | `#[^\n]*`                                                        | comment   |
| Number            | `\b\d+(\.\d+)?([eE][+-]?\d+)?\b` and `\b0x[0-9A-Fa-f]+\b`     | number    |
| Class name        | `(?<=class )[A-Za-z_]\w*`                                        | type/class|
| Function name     | `(?<=def )[A-Za-z_]\w*`                                          | attribute |

### Notes
- Apply triple-quoted strings **before** single-quoted strings.
- Comments starting with `#` must be applied after strings to avoid coloring `#` inside strings.

---

## HTML (`.html`)

HTML uses a tag-centric model: tags, attributes, values, comments, DOCTYPE.

### Patterns

| Element           | Regex pattern                                                    | Color     |
|-------------------|------------------------------------------------------------------|-----------|
| Comment           | `<!--[\s\S]*?-->` (non-greedy)                                  | comment   |
| DOCTYPE           | `<!DOCTYPE[^>]*>`                                               | comment   |
| Tag name (open)   | `(?<=</?)[A-Za-z][A-Za-z0-9-]*`                                 | tag (keyword) |
| Attribute name    | `\b[a-z][a-z0-9-]*(?=\s*=)`                                     | attribute |
| Attribute value   | `"[^"]*"` or `'[^']*'`                                          | string    |
| Angle brackets    | `[<>]` and `</` and `/>`                                        | punctuation |
| Entity            | `&[a-zA-Z0-9#]+;`                                               | number    |

### Notes
- Apply comment pattern first so tag patterns don't fire inside `<!-- -->`.
- `<script>` and `<style>` blocks ideally fall through to JS/CSS sub-highlighting (optional enhancement).

---

## JavaScript (`.js`)

### Patterns

| Element           | Regex pattern                                                    | Color     |
|-------------------|------------------------------------------------------------------|-----------|
| Keywords          | `\b(break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|finally|for|function|if|import|in|instanceof|let|new|return|static|super|switch|this|throw|try|typeof|var|void|while|with|yield|async|await|of)\b` | keyword |
| Built-in objects  | `\b(Array|Boolean|Date|Error|Function|JSON|Math|Number|Object|Promise|RegExp|String|Symbol|Map|Set|WeakMap|WeakSet|console|document|window|undefined|null|true|false|NaN|Infinity)\b` | type/class |
| String (double)   | `"(?:[^"\\]|\\.)*"`                                              | string    |
| String (single)   | `'(?:[^'\\]|\\.)*'`                                              | string    |
| Template literal  | `` `(?:[^`\\]|\\.)*` ``                                         | string    |
| Line comment      | `//[^\n]*`                                                       | comment   |
| Block comment     | `/\*[\s\S]*?\*/` (non-greedy)                                   | comment   |
| Number            | `\b\d+(\.\d+)?([eE][+-]?\d+)?\b` and `\b0x[0-9A-Fa-f]+\b`     | number    |
| Regex literal     | `/(?:[^/\\\n]|\\.)+/[gimsuy]*` (heuristic — see note)          | number    |
| Arrow / operator  | `=>|===|!==|>=|<=|&&|\|\||\?\?|[+\-*/%&|^~!]=?`               | operator  |
| Function name     | `(?<=function )[A-Za-z_$][\w$]*`                                 | attribute |
| Class name        | `(?<=class )[A-Za-z_$][\w$]*`                                    | type/class|

### Notes
- Apply block comments and strings first so `//` inside a string is not treated as a comment.
- Regex literal detection is ambiguous; a simple heuristic is to match `/…/flags` only when preceded by `=`, `(`, `,`, `[`, `!`, `&`, `|`, `?`, `:`, `{`, `;` or start-of-line.

---

## CSS (`.css`)

### Patterns

| Element           | Regex pattern                                                    | Color     |
|-------------------|------------------------------------------------------------------|-----------|
| Comment           | `/\*[\s\S]*?\*/` (non-greedy)                                   | comment   |
| Selector          | `[^{};/]+(?=\s*\{)` (trim whitespace)                           | type/class|
| Property name     | `[a-z][a-z0-9-]*(?=\s*:)`  (inside rule block)                 | keyword   |
| Property value    | `(?<=:)[^;{}]+(?=;)`                                             | string    |
| String            | `"[^"]*"` or `'[^']*'`                                          | string    |
| Color hex         | `#[0-9A-Fa-f]{3,8}\b`                                           | number    |
| Number with unit  | `\b\d+(\.\d+)?(px|em|rem|%|vh|vw|pt|s|ms|deg|fr|ch|ex)?\b`    | number    |
| At-rule           | `@[a-z-]+`                                                       | attribute |
| Pseudo-class      | `:[a-z][a-z0-9-]*`                                               | attribute |
| Pseudo-element    | `::[a-z][a-z0-9-]*`                                              | attribute |
| Punctuation       | `[{}:;,]`                                                        | punctuation |
| Important         | `!important`                                                     | keyword   |

### Notes
- Comments must be matched first.
- Selector matching is line-based; multi-line selectors (comma-separated) may need a block-aware pass.
- CSS custom properties (`--foo`) can be colored as `attribute` by extending the property name pattern to include `--`.

---

## Implementation Checklist

- [x] `SyntaxHighlighter` protocol: `func highlight(_ text: String) -> [(NSRange, NSColor)]`
- [x] One concrete type per language: `MarkdownHighlighter`, `PythonHighlighter`, `HTMLHighlighter`, `JavaScriptHighlighter`, `CSSHighlighter`
- [x] Factory: `makeSyntaxHighlighter(forExtension ext: String) -> SyntaxHighlighter?`
- [x] Hook into `EditorPaneVC.textViewDidChangeText` with debounce (~150 ms)
- [x] Also re-highlight on `switchToTab` (immediate, no debounce)
- [x] Ensure `beginEditing()` / `endEditing()` wraps all attribute mutations
- [ ] Preserve undo coalescing — attribute-only changes should not pollute the undo stack (use `textStorage.addAttributes` outside `undoManager` grouping if STTextView exposes that)
