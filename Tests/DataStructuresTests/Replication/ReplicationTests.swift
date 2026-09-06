//
//  ReplicationTests.swift
//  DataStructuresTests
//

import Testing
import Foundation
@testable import DataStructures

struct MockRecord: SequencedRecord, Equatable {
    let sequenceNumber: UInt64
    let timestamp: Date
    let message: String

    init(sequenceNumber: UInt64, timestamp: Date = Date(), message: String) {
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.message = message
    }
}

@Suite("Streaming Replication Engine Tests")
struct ReplicationTests {

    // MARK: - 1. ReplicationBroadcaster Fan-out & RingBuffer

    @Test("ReplicationBroadcaster fans out live records to multiple active subscribers")
    func testBroadcasterFanOut() async throws {
        let broadcaster = ReplicationBroadcaster<MockRecord>(ringBufferCapacity: 10)
        #expect(await broadcaster.connectedCount == 0)

        let (stream1, needsSnap1) = await broadcaster.subscribe(subscriberID: "node-1", fromSequenceNumber: 0)
        let (_, needsSnap2) = await broadcaster.subscribe(subscriberID: "node-2", fromSequenceNumber: 0)

        #expect(!needsSnap1) // Leader is empty initially
        #expect(!needsSnap2)
        #expect(await broadcaster.connectedCount == 2)

        let r1 = MockRecord(sequenceNumber: 1, message: "init")
        let r2 = MockRecord(sequenceNumber: 2, message: "mutation")

        await broadcaster.broadcast(r1)
        await broadcaster.broadcast(r2)

        #expect(await broadcaster.lastSequenceNumber == 2)
        #expect(await broadcaster.totalBroadcastedRecords == 2)

        // Read stream1
        var iter1 = stream1.makeAsyncIterator()
        let received1 = await iter1.next()
        let received2 = await iter1.next()
        #expect(received1 == r1)
        #expect(received2 == r2)

        // Telemetry
        let subs = await broadcaster.activeSubscribers
        #expect(subs.count == 2)
        #expect(subs[0].id == "node-1")
        #expect(subs[0].lastSequenceNumber == 2)

        // Unsubscribe
        await broadcaster.unsubscribe(subscriberID: "node-1")
        #expect(await broadcaster.connectedCount == 1)

        await broadcaster.closeAll()
        #expect(await broadcaster.connectedCount == 0)
    }

    @Test("ReplicationBroadcaster delta catch-up yields missed records from RingBuffer")
    func testDeltaCatchup() async throws {
        let broadcaster = ReplicationBroadcaster<MockRecord>(ringBufferCapacity: 5)

        // Broadcast 4 records: seq 1, 2, 3, 4
        for seq: UInt64 in 1...4 {
            await broadcaster.broadcast(MockRecord(sequenceNumber: seq, message: "msg_\(seq)"))
        }

        #expect(await broadcaster.oldestBufferedSequenceNumber == 1)

        // Follower joins having already seen seq 2 -> needs delta for 3, 4
        let (stream, needsSnap) = await broadcaster.subscribe(subscriberID: "catchup-node", fromSequenceNumber: 2)
        #expect(!needsSnap)

        var iter = stream.makeAsyncIterator()
        let rec3 = await iter.next()
        let rec4 = await iter.next()
        #expect(rec3?.sequenceNumber == 3)
        #expect(rec4?.sequenceNumber == 4)

        // Broadcast a new record live
        await broadcaster.broadcast(MockRecord(sequenceNumber: 5, message: "msg_5"))
        let rec5 = await iter.next()
        #expect(rec5?.sequenceNumber == 5)

        await broadcaster.closeAll()
    }

    @Test("ReplicationBroadcaster gap detection flags needsFullSnapshot when lag exceeds RingBuffer")
    func testSnapshotRequiredGapDetection() async throws {
        let broadcaster = ReplicationBroadcaster<MockRecord>(ringBufferCapacity: 3)

        // Push 5 records to cause RingBuffer eviction: retains [3, 4, 5]
        for seq: UInt64 in 1...5 {
            await broadcaster.broadcast(MockRecord(sequenceNumber: seq, message: "m\(seq)"))
        }

        #expect(await broadcaster.oldestBufferedSequenceNumber == 3)

        // Case A: Fresh follower joining non-empty leader
        let (_, freshNeedsSnap) = await broadcaster.subscribe(subscriberID: "fresh", fromSequenceNumber: 0)
        #expect(freshNeedsSnap == true)

        // Case B: Lagged follower whose last sequence was 1 (oldest retained is 3, so gap is too large)
        let (_, lagNeedsSnap) = await broadcaster.subscribe(subscriberID: "lagged", fromSequenceNumber: 1)
        #expect(lagNeedsSnap == true)

        // Case C: Up-to-date follower with seq 4
        let (_, caughtUpNeedsSnap) = await broadcaster.subscribe(subscriberID: "current", fromSequenceNumber: 4)
        #expect(caughtUpNeedsSnap == false)

        await broadcaster.closeAll()
    }

    // MARK: - 2. ReplicationFollowerEngine State & Deduplication

    @Test("ReplicationFollowerEngine deduplication and monotonic sequence enforcement")
    func testFollowerEngineDeduplication() async throws {
        let engine = ReplicationFollowerEngine<MockRecord>(initialSequenceNumber: 10)
        #expect(await engine.lastAppliedSequenceNumber == 10)

        // Sequence <= 10 must be discarded
        #expect(await engine.shouldApply(sequenceNumber: 10) == false)
        #expect(await engine.shouldApply(sequenceNumber: 9) == false)
        #expect(await engine.shouldApply(sequenceNumber: 0) == false)

        // Sequence > 10 is accepted
        #expect(await engine.shouldApply(sequenceNumber: 11) == true)

        // Applying sequence 11
        let now = Date()
        await engine.recordApplied(sequenceNumber: 11, timestamp: now)
        #expect(await engine.lastAppliedSequenceNumber == 11)
        #expect(await engine.totalReplicatedRecords == 1)
        #expect(await engine.lastSyncTimestamp == now)
        #expect(await engine.state == .streaming(lastSequence: 11))

        // Duplicate sequence 11 rejected
        #expect(await engine.shouldApply(sequenceNumber: 11) == false)
    }

    @Test("ReplicationFollowerEngine snapshot rehydration resets sequence baseline")
    func testFollowerEngineSnapshot() async throws {
        let engine = ReplicationFollowerEngine<MockRecord>(initialSequenceNumber: 0)

        await engine.startSyncingSnapshot()
        #expect(await engine.state == .syncingSnapshot)

        await engine.snapshotApplied(sequenceNumber: 100)
        #expect(await engine.lastAppliedSequenceNumber == 100)
        #expect(await engine.state == .streaming(lastSequence: 100))

        #expect(await engine.shouldApply(sequenceNumber: 99) == false)
        #expect(await engine.shouldApply(sequenceNumber: 101) == true)
    }

    @Test("ReplicationFollowerEngine exponential backoff and recovery transitions")
    func testFollowerEngineBackoff() async throws {
        let engine = ReplicationFollowerEngine<MockRecord>(
            initialBackoffNanoseconds: 100_000_000, // 100ms
            maxBackoffNanoseconds: 400_000_000,    // 400ms
            backoffMultiplier: 2.0
        )

        // Attempt 1: 100ms
        let b1 = await engine.recordConnectionFailure()
        #expect(b1 == 100_000_000)
        #expect(await engine.reconnectAttempts == 1)

        // Attempt 2: 200ms
        let b2 = await engine.recordConnectionFailure()
        #expect(b2 == 200_000_000)
        #expect(await engine.reconnectAttempts == 2)

        // Attempt 3: 400ms (hits ceiling)
        let b3 = await engine.recordConnectionFailure()
        #expect(b3 == 400_000_000)

        // Attempt 4: capped at 400ms
        let b4 = await engine.recordConnectionFailure()
        #expect(b4 == 400_000_000)

        let status = await engine.status
        #expect(status.reconnectAttempts == 4)

        // Connect success resets backoff
        await engine.recordConnectionSuccess()
        #expect(await engine.reconnectAttempts == 0)

        // Disconnect
        await engine.disconnect()
        #expect(await engine.state == .disconnected)
    }
}
