//
//  Glob.swift
//  Tile38Swift
//
//  Created on 2026-09-05.
//

import Foundation

/// High-performance wildcard string pattern matcher in pure Swift.
///
/// Implements Redis/Tile38 glob pattern semantics without regular expression overhead:
/// - `*` matches zero or more characters.
/// - `?` matches exactly one character.
/// - `[abc]` matches any character within the brackets.
/// - `[a-z]` matches any character within the ASCII range.
/// - `[^abc]` or `[!abc]` matches any character not in the brackets.
/// - `\\c` escapes character `c` to be matched literally.
public struct Glob: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// The original glob pattern string.
    public let pattern: String

    /// Initializes a `Glob` with the specified pattern.
    ///
    /// - Parameter pattern: Wildcard pattern string.
    public init(_ pattern: String) {
        self.pattern = pattern
    }

    /// Evaluates whether the candidate text matches this glob pattern.
    ///
    /// - Parameter text: The string to test.
    /// - Returns: `true` if `text` matches the pattern; otherwise `false`.
    public func matches(_ text: String) -> Bool {
        Glob.match(pattern: pattern, text: text)
    }

    public var description: String { pattern }

    /// Static convenience function to test a pattern against text.
    ///
    /// - Parameters:
    ///   - pattern: Wildcard pattern string.
    ///   - text: Candidate text to match.
    /// - Returns: `true` if matching; otherwise `false`.
    public static func match(pattern: String, text: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.isEmpty { return text.isEmpty }

        let pChars = Array(pattern)
        let tChars = Array(text)

        return matchHelper(pChars: pChars, pIdx: 0, tChars: tChars, tIdx: 0)
    }

    private static func matchHelper(
        pChars: [Character],
        pIdx: Int,
        tChars: [Character],
        tIdx: Int
    ) -> Bool {
        var p = pIdx
        var t = tIdx

        while p < pChars.count {
            let pChar = pChars[p]

            if pChar == "*" {
                // Collapse consecutive asterisks
                while p + 1 < pChars.count && pChars[p + 1] == "*" {
                    p += 1
                }
                // If trailing *, it matches the rest of the text
                if p + 1 == pChars.count {
                    return true
                }
                // Try matching * with 0, 1, 2... characters
                for nextT in t...tChars.count {
                    if matchHelper(pChars: pChars, pIdx: p + 1, tChars: tChars, tIdx: nextT) {
                        return true
                    }
                }
                return false
            } else if pChar == "?" {
                if t >= tChars.count {
                    return false
                }
                p += 1
                t += 1
            } else if pChar == "[" {
                if t >= tChars.count {
                    return false
                }
                guard let closeIdx = findClosingBracket(pChars: pChars, start: p + 1) else {
                    // Malformed bracket, treat literal
                    if tChars[t] != "[" { return false }
                    p += 1
                    t += 1
                    continue
                }

                let isNegated = (p + 1 < closeIdx) && (pChars[p + 1] == "!" || pChars[p + 1] == "^")
                let contentStart = isNegated ? p + 2 : p + 1

                let matched = matchCharacterClass(
                    pChars: pChars,
                    start: contentStart,
                    end: closeIdx,
                    char: tChars[t]
                )

                if isNegated ? matched : !matched {
                    return false
                }

                p = closeIdx + 1
                t += 1
            } else if pChar == "\\" {
                // Escaped character
                p += 1
                if p >= pChars.count {
                    return false
                }
                if t >= tChars.count || tChars[t] != pChars[p] {
                    return false
                }
                p += 1
                t += 1
            } else {
                // Literal character match
                if t >= tChars.count || tChars[t] != pChar {
                    return false
                }
                p += 1
                t += 1
            }
        }

        return t == tChars.count
    }

    private static func findClosingBracket(pChars: [Character], start: Int) -> Int? {
        var idx = start
        // Allow leading ] if it is immediately at the start of the class
        if idx < pChars.count && (pChars[idx] == "!" || pChars[idx] == "^") {
            idx += 1
        }
        if idx < pChars.count && pChars[idx] == "]" {
            idx += 1
        }
        while idx < pChars.count {
            if pChars[idx] == "]" {
                return idx
            }
            idx += 1
        }
        return nil
    }

    private static func matchCharacterClass(
        pChars: [Character],
        start: Int,
        end: Int,
        char: Character
    ) -> Bool {
        var idx = start
        while idx < end {
            if idx + 2 < end && pChars[idx + 1] == "-" {
                let lo = pChars[idx]
                let hi = pChars[idx + 2]
                if lo <= char && char <= hi {
                    return true
                }
                idx += 3
            } else {
                if pChars[idx] == char {
                    return true
                }
                idx += 1
            }
        }
        return false
    }
}
