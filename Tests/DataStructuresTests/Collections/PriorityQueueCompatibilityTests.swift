//
//  PriorityQueueCompatibilityTests.swift
//  DataStructuresSwift
//

import Foundation
import Testing
@testable import DataStructures

@Suite("PriorityQueue Compatibility Tests")
struct PriorityQueueCompatibilityTests {
    @Test("PriorityQueue default Comparable min-heap and clear")
    func testDefaultInitAndClear() {
        var pq = PriorityQueue<Int>()
        pq.push(30)
        pq.push(10)
        pq.push(20)

        #expect(pq.count == 3)
        #expect(pq.peek() == 10)
        #expect(pq.pop() == 10)
        #expect(pq.count == 2)

        pq.clear()
        #expect(pq.isEmpty)
        #expect(pq.count == 0)
        #expect(pq.pop() == nil)
    }

    @Test("PriorityQueue init(sort:) custom order")
    func testInitWithSortClosure() {
        var pq = PriorityQueue<Double>(sort: { $0 > $1 }) // Max-heap
        pq.push(1.5)
        pq.push(9.9)
        pq.push(4.2)

        #expect(pq.peek() == 9.9)
        #expect(pq.pop() == 9.9)
        #expect(pq.pop() == 4.2)
        #expect(pq.pop() == 1.5)
        #expect(pq.isEmpty)
    }
}
