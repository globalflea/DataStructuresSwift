//
//  GlobTests.swift
//  DataStructuresSwift
//

import Foundation
import Testing
@testable import DataStructures

@Suite("Glob Pattern Matcher Tests")
struct GlobTests {
    @Test("Universal and simple prefix/suffix wildcards")
    func testUniversalAndPrefixSuffix() {
        #expect(Glob.match(pattern: "*", text: "anything"))
        #expect(Glob.match(pattern: "*", text: ""))
        #expect(Glob.match(pattern: "user:*", text: "user:123"))
        #expect(Glob.match(pattern: "user:*", text: "user:"))
        #expect(!Glob.match(pattern: "user:*", text: "admin:123"))

        #expect(Glob.match(pattern: "*:truck", text: "fleet:truck"))
        #expect(Glob.match(pattern: "*:*", text: "a:b"))
        #expect(Glob.match(pattern: "a*b*c", text: "a_middle_b_end_c"))
        #expect(!Glob.match(pattern: "a*b*c", text: "a_middle_b_end_d"))

        // Consecutive asterisks collapse
        #expect(Glob.match(pattern: "a**b", text: "ab"))
        #expect(Glob.match(pattern: "a**b", text: "a123b"))
    }

    @Test("Single character wildcard '?'")
    func testSingleCharWildcard() {
        #expect(Glob.match(pattern: "h?llo", text: "hello"))
        #expect(Glob.match(pattern: "h?llo", text: "hallo"))
        #expect(!Glob.match(pattern: "h?llo", text: "hllo"))
        #expect(!Glob.match(pattern: "h?llo", text: "heello"))

        #expect(Glob.match(pattern: "???", text: "abc"))
        #expect(!Glob.match(pattern: "???", text: "ab"))
    }

    @Test("Character classes and ranges")
    func testCharacterClasses() {
        #expect(Glob.match(pattern: "[abc]", text: "a"))
        #expect(Glob.match(pattern: "[abc]", text: "b"))
        #expect(Glob.match(pattern: "[abc]", text: "c"))
        #expect(!Glob.match(pattern: "[abc]", text: "d"))

        #expect(Glob.match(pattern: "[a-z]", text: "m"))
        #expect(Glob.match(pattern: "[0-9]", text: "5"))
        #expect(!Glob.match(pattern: "[0-9]", text: "a"))

        #expect(Glob.match(pattern: "[^0-9]", text: "a"))
        #expect(!Glob.match(pattern: "[^0-9]", text: "7"))
        #expect(Glob.match(pattern: "[!0-9]", text: "z"))
        #expect(!Glob.match(pattern: "[!0-9]", text: "3"))

        #expect(Glob.match(pattern: "[a-zA-Z0-9]", text: "Z"))
        #expect(Glob.match(pattern: "[a-zA-Z0-9]", text: "9"))
    }

    @Test("Literal escaping with backslash")
    func testEscaping() {
        #expect(Glob.match(pattern: "hello\\*world", text: "hello*world"))
        #expect(!Glob.match(pattern: "hello\\*world", text: "hello123world"))

        #expect(Glob.match(pattern: "\\[abc\\]", text: "[abc]"))
    }

    @Test("Edge cases: empty pattern, empty text, unclosed brackets")
    func testEdgeCases() {
        #expect(Glob.match(pattern: "", text: ""))
        #expect(!Glob.match(pattern: "", text: "something"))

        #expect(Glob.match(pattern: "[unclosed", text: "[unclosed"))
        #expect(!Glob.match(pattern: "[unclosed", text: "unclosed"))

        let glob = Glob("fleet:*")
        #expect(glob.matches("fleet:vehicle1"))
        #expect(glob.description == "fleet:*")
        #expect(glob == Glob("fleet:*"))
    }
}
