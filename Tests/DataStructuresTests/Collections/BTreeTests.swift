//
//  BTreeTests.swift
//  DataStructuresSwift
//

import Foundation
import Testing
@testable import DataStructures

@Suite("BTree Cache-Friendly Index Tests")
struct BTreeTests {
    @Test("BTree basic insertion, lookup, and mutation")
    func testBasicOperations() {
        var btree = BTree<String, Int>(degree: 2) // Small degree to force splits quickly

        #expect(btree.isEmpty)
        #expect(btree.count == 0)
        #expect(btree.find(key: "apple") == nil)
        #expect(btree.min == nil)
        #expect(btree.max == nil)

        #expect(btree.insert(key: "banana", value: 2) == nil)
        #expect(btree.insert(key: "apple", value: 1) == nil)
        #expect(btree.insert(key: "cherry", value: 3) == nil)
        #expect(btree.insert(key: "date", value: 4) == nil)

        #expect(btree.count == 4)
        #expect(!btree.isEmpty)
        #expect(btree.contains(key: "apple"))
        #expect(btree.contains(key: "cherry"))
        #expect(!btree.contains(key: "elderberry"))

        #expect(btree.find(key: "apple") == 1)
        #expect(btree.find(key: "banana") == 2)
        #expect(btree.find(key: "cherry") == 3)
        #expect(btree.find(key: "date") == 4)

        // Update existing key
        let old = btree.insert(key: "apple", value: 10)
        #expect(old == 1)
        #expect(btree.find(key: "apple") == 10)
        #expect(btree.count == 4)

        // Subscript usage
        btree["fig"] = 6
        #expect(btree["fig"] == 6)
        #expect(btree.count == 5)

        #expect(btree.min?.key == "apple")
        #expect(btree.max?.key == "fig")
    }

    @Test("BTree range scan forward and reverse")
    func testRangeScans() {
        var btree = BTree<Int, String>(degree: 3)

        for i in 1...20 {
            btree.insert(key: i * 10, value: "val_\(i * 10)")
        }

        #expect(btree.count == 20)

        // Forward scan from 50 to 120
        let forward = btree.scan(from: 50, to: 120)
        let expectedKeys = Array(stride(from: 50, through: 120, by: 10))
        #expect(forward.map(\.key) == expectedKeys)

        // Reverse scan from 50 to 120
        let reverse = btree.scan(from: 50, to: 120, reverse: true)
        #expect(reverse.map(\.key) == expectedKeys.reversed())

        // Scan all forward
        let all = btree.scan()
        #expect(all.count == 20)
        #expect(all.first?.key == 10)
        #expect(all.last?.key == 200)
    }

    @Test("BTree Sequence conformance and in-order traversal")
    func testSequenceConformance() {
        var btree = BTree<Int, Int>(degree: 4)

        let numbers = [50, 20, 80, 10, 30, 70, 90, 5, 15, 25, 35]
        for n in numbers {
            btree.insert(key: n, value: n * 2)
        }

        var iteratedKeys: [Int] = []
        for (k, _) in btree {
            iteratedKeys.append(k)
        }

        #expect(iteratedKeys == numbers.sorted())
    }

    @Test("BTree stress insertion and deletion of 2,000 keys")
    func testStressInsertionAndDeletion() {
        var btree = BTree<Int, Int>(degree: 8)

        // Insert 2,000 keys
        for i in 1...2000 {
            btree.insert(key: i, value: i * 10)
        }

        #expect(btree.count == 2000)
        #expect(btree.min?.key == 1)
        #expect(btree.max?.key == 2000)

        // Verify all lookups succeed
        for i in 1...2000 {
            #expect(btree.find(key: i) == i * 10)
        }

        // Delete even keys (1,000 deletions)
        for i in stride(from: 2, through: 2000, by: 2) {
            let rem = btree.remove(key: i)
            #expect(rem == i * 10)
        }

        #expect(btree.count == 1000)

        // Verify odd keys remain and even keys are gone
        for i in 1...2000 {
            if i % 2 == 1 {
                #expect(btree.find(key: i) == i * 10)
            } else {
                #expect(btree.find(key: i) == nil)
            }
        }

        // Delete odd keys (remaining 1,000 deletions)
        for i in stride(from: 1, through: 2000, by: 2) {
            let rem = btree.remove(key: i)
            #expect(rem == i * 10)
        }

        #expect(btree.count == 0)
        #expect(btree.isEmpty)
        #expect(btree.min == nil)
        #expect(btree.max == nil)
    }

    @Test("BTree Copy-on-Write value semantics")
    func testCopyOnWrite() {
        var tree1 = BTree<String, Int>(degree: 2)
        tree1["a"] = 1
        tree1["b"] = 2

        var tree2 = tree1
        #expect(tree2.count == 2)

        tree2["c"] = 3
        #expect(tree2.count == 3)
        #expect(tree1.count == 2)
        #expect(tree1["c"] == nil)
        #expect(tree2["c"] == 3)
    }

    @Test("BTree subscript deletion, clear, and missing key removal")
    func testSubscriptDeletionAndClear() {
        var btree = BTree<String, Int>(degree: 2)
        btree["x"] = 100
        btree["y"] = 200

        #expect(btree.remove(key: "missing") == nil)

        btree["x"] = nil
        #expect(btree["x"] == nil)
        #expect(btree.count == 1)

        btree.clear()
        #expect(btree.isEmpty)
        #expect(btree.count == 0)
    }

    @Test("BTree internal node deletion with successor and merge")
    func testInternalNodeDeletions() {
        var btree = BTree<Int, String>(degree: 2)
        for i in 1...20 {
            btree.insert(key: i, value: "val_\(i)")
        }

        let keysToDelete = [4, 8, 12, 16, 10, 6, 2, 14, 18, 5, 7, 9, 11, 13, 15, 17, 19, 1, 3, 20]
        for k in keysToDelete {
            let removed = btree.remove(key: k)
            #expect(removed == "val_\(k)")
        }
        #expect(btree.isEmpty)
    }
}
