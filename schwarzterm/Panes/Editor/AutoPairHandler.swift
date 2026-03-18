// Panes/Editor/AutoPairHandler.swift
import AppKit
import STTextView

/// Handles auto-pairing of brackets and quotes in an STTextView.
///
/// Behaviours:
/// - Typing an opener inserts the pair and places the cursor between them.
/// - Typing a closer when the cursor is already sitting before that closer
///   skips over it instead of inserting a duplicate.
/// - Pressing Backspace when the cursor sits between an empty pair deletes both.
enum AutoPairHandler {

    // Maps opener → closer
    private static let pairs: [Character: Character] = [
        "(": ")",
        "[": "]",
        "{": "}",
        "\"": "\"",
        "'": "'",
        "`": "`",
    ]

    // The set of all closers (for skip-over detection)
    private static let closers: Set<Character> = Set(pairs.values)

    /// Call from `textView(_:shouldChangeTextIn:replacementString:)`.
    /// Returns `true` if the event was handled (caller should return `false` to STTextView).
    @discardableResult
    static func handle(
        textView: STTextView,
        range affectedRange: NSTextRange,
        replacement: String?
    ) -> Bool {
        guard let text = textView.text else { return false }
        let nsText = text as NSString
        let nsRange = nsRange(from: affectedRange, in: textView)

        // ── Backspace over an empty pair ─────────────────────────────────────
        // replacement is "" or nil AND range covers one character being deleted
        if (replacement == nil || replacement == "") && nsRange.length == 1 {
            let deletedChar = nsText.character(at: nsRange.location)
            guard let opener = Character(unicode: deletedChar),
                  let closer = pairs[opener] else { return false }

            // Check the character that follows the deleted one
            let nextLoc = nsRange.location + 1
            guard nextLoc < nsText.length else { return false }
            let nextChar = nsText.character(at: nextLoc)
            guard let next = Character(unicode: nextChar), next == closer else { return false }

            // Delete both opener and closer
            let pairRange = NSRange(location: nsRange.location, length: 2)
            textView.replaceCharacters(in: pairRange, with: "")
            textView.textSelection = NSRange(location: nsRange.location, length: 0)
            return true
        }

        // ── Only act on single-char insertions with no active selection ──────
        guard let str = replacement, str.count == 1,
              nsRange.length == 0 else { return false }

        let char = str.first!

        // ── Skip over matching closer ─────────────────────────────────────────
        // e.g. cursor is before ) and user types ) — just advance cursor
        if closers.contains(char) {
            let loc = nsRange.location
            if loc < nsText.length {
                let next = nsText.character(at: loc)
                if let nextChar = Character(unicode: next), nextChar == char {
                    textView.textSelection = NSRange(location: loc + 1, length: 0)
                    return true
                }
            }
        }

        // ── Insert pair and position cursor between them ──────────────────────
        guard let closer = pairs[char] else { return false }

        let pair = str + String(closer)
        textView.replaceCharacters(in: nsRange, with: pair)
        // Place cursor between opener and closer
        textView.textSelection = NSRange(location: nsRange.location + 1, length: 0)
        return true
    }
}

// MARK: - Helpers

/// Converts an NSTextRange to an NSRange using the text view's content manager.
private func nsRange(from textRange: NSTextRange, in textView: STTextView) -> NSRange {
    guard let storage = textView.textContentManager as? NSTextContentStorage else {
        return .init(location: NSNotFound, length: 0)
    }
    let start = storage.offset(from: storage.documentRange.location, to: textRange.location)
    let end   = storage.offset(from: storage.documentRange.location, to: textRange.endLocation)
    guard start != NSNotFound, end != NSNotFound, end >= start else {
        return .init(location: NSNotFound, length: 0)
    }
    return NSRange(location: start, length: end - start)
}

private extension Character {
    /// Create a Character from a UTF-16 code unit returned by NSString.character(at:).
    init?(unicode scalar: unichar) {
        guard let s = Unicode.Scalar(scalar) else { return nil }
        self = Character(s)
    }
}
