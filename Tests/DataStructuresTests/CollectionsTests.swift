//
//  CollectionsTests.swift
//  DataStructuresTests
//
//  Created on 2026-09-06.
//

import Foundation
import Testing
@testable import DataStructures

@Suite("DataStructures Core Collections Tests")
struct CollectionsTests {

    // MARK: - 1. MonotonicDeque Tests

    @Test("MonotonicDeque Running Minimum (Increasing Order) and Domination Pruning")
    func testMonotonicDequeRunningMinimum() {
        var deque = MonotonicDeque<Double, Int>(order: .increasing)
        #expect(deque.isEmpty)
        #expect(deque.extremum == nil)

        deque.push(element: 10.0, tag: 1)
        #expect(deque.extremum == 10.0)
        #expect(deque.dequeCount == 1)

        deque.push(element: 20.0, tag: 2)
        #expect(deque.extremum == 10.0)
        #expect(deque.dequeCount == 2)

        deque.push(element: 5.0, tag: 3)
        #expect(deque.extremum == 5.0)
        #expect(deque.dequeCount == 1) // 10 and 20 pruned
        #expect(deque.count == 3)

        deque.push(element: 15.0, tag: 4)
        deque.push(element: 8.0, tag: 5)
        #expect(deque.extremum == 5.0)

        deque.remove(tag: 1)
        deque.remove(tag: 2)
        #expect(deque.extremum == 5.0)

        deque.remove(tag: 3) // 5 removed -> min becomes 8.0
        #expect(deque.extremum == 8.0)

        deque.remove(tag: 5)
        #expect(deque.extremum == 15.0)
        #expect(deque.count == 1)

        deque.removeAll()
        #expect(deque.isEmpty)
    }

    @Test("MonotonicDeque Running Maximum (Decreasing Order)")
    func testMonotonicDequeRunningMaximum() {
        var deque = MonotonicDeque<Int, String>(order: .decreasing)

        deque.push(element: 15, tag: "A")
        deque.push(element: 10, tag: "B")
        deque.push(element: 25, tag: "C")

        #expect(deque.extremum == 25)
        #expect(deque.dequeCount == 1)
        #expect(deque.count == 3)

        deque.push(element: 20, tag: "D")
        deque.push(element: 18, tag: "E")
        #expect(deque.extremum == 25)

        deque.remove(tag: "C")
        #expect(deque.extremum == 20)

        deque.remove(tag: "D")
        #expect(deque.extremum == 18)
    }

    // MARK: - 2. RingBuffer Tests

    @Test("RingBuffer Ingestion, FIFO Eviction, Subscripts, and RandomAccessCollection")
    func testRingBufferBasicsAndIteration() {
        var ring = RingBuffer<String>(capacity: 4)
        #expect(ring.isEmpty)
        #expect(ring.count == 0)
        #expect(ring.maxCapacity == 4)

        #expect(ring.append("A") == nil)
        #expect(ring.append("B") == nil)
        #expect(ring.append("C") == nil)
        #expect(ring.append("D") == nil)
        #expect(ring.isFull)
        #expect(ring.count == 4)
        #expect(ring.first == "A")
        #expect(ring.last == "D")

        // Overwrite evicts oldest A
        let evicted1 = ring.append("E")
        #expect(evicted1 == "A")
        #expect(ring.count == 4)
        #expect(ring.elements == ["B", "C", "D", "E"])

        #expect(ring[0] == "B")
        #expect(ring[3] == "E")

        ring[1] = "C_MOD"
        #expect(ring[1] == "C_MOD")

        #expect(ring.popFirst() == "B")
        #expect(ring.popFirst() == "C_MOD")
        #expect(ring.count == 2)

        let mapped = ring.map { $0 + "!" }
        #expect(mapped == ["D!", "E!"])

        ring.removeAll()
        #expect(ring.isEmpty)
        #expect(ring.popFirst() == nil)
    }

    // MARK: - 3. PriorityQueue Tests

    @Test("PriorityQueue Min-Heap and Max-Heap Sorting")
    func testPriorityQueueHeapSorting() {
        var minPQ = PriorityQueue<Int>(order: .min)
        let values = [45, 12, 85, 32, 89, 39, 69, 22, 42, 1, 99, 15]
        for v in values { minPQ.push(v) }

        #expect(minPQ.count == values.count)
        #expect(minPQ.peek() == 1)

        var minExtracted: [Int] = []
        while let root = minPQ.pop() { minExtracted.append(root) }
        #expect(minExtracted == values.sorted())

        var maxPQ = PriorityQueue<Double>(order: .max)
        let doubleValues: [Double] = [3.14, 1.41, 2.71, 9.81, 0.57, 1.61]
        for v in doubleValues { maxPQ.push(v) }

        #expect(maxPQ.peek() == 9.81)
        var maxExtracted: [Double] = []
        while let root = maxPQ.pop() { maxExtracted.append(root) }
        #expect(maxExtracted == doubleValues.sorted(by: >))
    }

    // MARK: - 4. ConcurrentMap & ConcurrentSet Tests

    @Test("ConcurrentMap and ConcurrentSet Thread Safety Under High Concurrency")
    func testConcurrentMapAndSetThreadSafety() async throws {
        let map = ConcurrentMap<String, Int>()
        let set = ConcurrentSet<String>()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let key = "Key_\(i % 10)"
                    map.set(key, value: i)
                    set.insert(key)
                    _ = map.get(key)
                    _ = set.contains(key)
                    _ = map.count
                    _ = set.count
                }
            }
        }

        #expect(map.count <= 10)
        #expect(set.count <= 10)
        #expect(!map.isEmpty)
        #expect(!set.isEmpty)

        map.remove("Key_0")
        set.remove("Key_0")
        #expect(map.get("Key_0") == nil)
        #expect(!set.contains("Key_0"))

        map.removeAll()
        set.removeAll()
        #expect(map.isEmpty)
        #expect(set.isEmpty)
    }

    // MARK: - 5. PathTrie Tests

    @Test("PathTrie Tokenization and Dynamic Invalidation")
    func testPathTrieTokenizationAndInvalidation() {
        #expect(PathTrie.tokenizePath("Order") == ["Order"])
        #expect(PathTrie.tokenizePath("Order.Total") == ["Order", "Total"])
        #expect(PathTrie.tokenizePath("State.Ids[0].Name") == ["State", "Ids", "[0]", "Name"])
        #expect(PathTrie.tokenizePath("") == [])

        let trie = PathTrie()
        trie.insert(path: "Car.Engine.RPM", ruleName: "Rule_RPM")
        trie.insert(path: "Car.Speed", ruleName: "Rule_Speed")
        trie.insert(path: "Car", ruleName: "Rule_CarRoot")
        trie.insert(path: "Driver.Name", ruleName: "Rule_Driver")

        // Mutating Car.Engine.RPM invalidates Rule_RPM and Rule_CarRoot
        let invExact = trie.findInvalidatedRules(for: "Car.Engine.RPM")
        #expect(invExact.contains("Rule_RPM"))
        #expect(invExact.contains("Rule_CarRoot"))
        #expect(!invExact.contains("Rule_Speed"))

        // Mutating Car invalidates all rules under Car
        let invRoot = trie.findInvalidatedRules(for: "Car")
        #expect(invRoot.contains("Rule_RPM"))
        #expect(invRoot.contains("Rule_Speed"))
        #expect(invRoot.contains("Rule_CarRoot"))
        #expect(!invRoot.contains("Rule_Driver"))

        trie.clear()
        #expect(trie.findInvalidatedRules(for: "Car").isEmpty)
    }

    @Test("ConcurrentMap and ConcurrentSet Full API Coverage")
    func testConcurrentMapAndSetAPIs() {
        let map = ConcurrentMap<String, Int>()
        map["a"] = 1
        map["b"] = 2
        #expect(map["a"] == 1)
        #expect(map["b"] == 2)
        #expect(map.keys.sorted() == ["a", "b"])
        #expect(map.values.sorted() == [1, 2])
        #expect(map.contains("a"))
        #expect(!map.contains("c"))

        let removedVal = map.remove("a")
        #expect(removedVal == 1)
        #expect(!map.contains("a"))

        let set = ConcurrentSet<String>()
        set.insert("x")
        set.insert("y")
        #expect(set.elements.sorted() == ["x", "y"])
        #expect(set.contains("x"))
        set.remove("x")
        #expect(!set.contains("x"))
        #expect(set.count == 1)
    }
}
