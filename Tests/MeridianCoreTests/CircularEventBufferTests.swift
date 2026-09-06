//
//  CircularEventBufferTests.swift
//  DataStructuresTests
//
//  Created on 2026-09-06.
//

import Foundation
import Testing
@testable import MeridianCore

struct MockEvent: TimestampedItem, Equatable {
    let id: String
    let timestamp: Date
}

@Suite("CircularEventBuffer Cutoff Replay & Bounded Ring Tests")
struct CircularEventBufferTests {

    @Test("CircularEventBuffer Append, Overflow, and Capacity Tracking")
    func testAppendAndCapacity() {
        var buffer = CircularEventBuffer<MockEvent>(capacity: 3)
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(!buffer.isFull)

        let t0 = Date()
        let e1 = MockEvent(id: "e1", timestamp: t0)
        let e2 = MockEvent(id: "e2", timestamp: t0.addingTimeInterval(1))
        let e3 = MockEvent(id: "e3", timestamp: t0.addingTimeInterval(2))
        let e4 = MockEvent(id: "e4", timestamp: t0.addingTimeInterval(3))

        buffer.append(e1)
        buffer.append(e2)
        #expect(buffer.count == 2)
        #expect(!buffer.isFull)

        buffer.append(e3)
        #expect(buffer.count == 3)
        #expect(buffer.isFull)

        // Append 4th -> Evicts oldest e1
        buffer.append(e4)
        #expect(buffer.count == 3)
        #expect(buffer.isFull)
        #expect(buffer.allEvents() == [e2, e3, e4])

        buffer.clear()
        #expect(buffer.isEmpty)
        #expect(!buffer.isFull)
        #expect(buffer.count == 0)
    }

    @Test("CircularEventBuffer Events Since Cutoff Filtering")
    func testEventsSinceCutoff() {
        var buffer = CircularEventBuffer<MockEvent>(capacity: 5)
        let t0 = Date(timeIntervalSince1970: 1700000000)

        for i in 0..<5 {
            let event = MockEvent(id: "id_\(i)", timestamp: t0.addingTimeInterval(Double(i)))
            buffer.append(event)
        }

        // Cutoff at t0 + 2.0s -> should return items at t0 + 3s, t0 + 4s
        let cutoff = t0.addingTimeInterval(2.0)
        let missed = buffer.events(since: cutoff)
        #expect(missed.count == 2)
        #expect(missed.map(\.id) == ["id_3", "id_4"])

        // Cutoff with predicate filter
        let filtered = buffer.events(since: t0) { $0.id.hasSuffix("2") || $0.id.hasSuffix("4") }
        #expect(filtered.count == 2)
        #expect(filtered.map(\.id) == ["id_2", "id_4"])

        // Cutoff far in the future
        let futureCutoff = t0.addingTimeInterval(100.0)
        #expect(buffer.events(since: futureCutoff).isEmpty)
    }
}
