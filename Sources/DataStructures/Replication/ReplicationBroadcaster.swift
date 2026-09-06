//
//  ReplicationBroadcaster.swift
//  DataStructuresSwift
//

import Foundation

/// Subscriber telemetry information for an active follower stream.
public struct ReplicationSubscriberInfo: Sendable, Identifiable, Equatable {
    public let id: String
    public let registeredAt: Date
    public var lastSequenceNumber: UInt64

    public init(id: String, registeredAt: Date = Date(), lastSequenceNumber: UInt64 = 0) {
        self.id = id
        self.registeredAt = registeredAt
        self.lastSequenceNumber = lastSequenceNumber
    }
}

/// Swift 6 actor managing live sequence fan-out to connected follower nodes.
///
/// Backed by a high-performance, $O(1)$ `RingBuffer` for retaining recent mutations
/// to enable fast delta catch-up without requiring full snapshot rehydration.
public actor ReplicationBroadcaster<Record: SequencedRecord> {
    private struct Subscriber {
        let id: String
        let continuation: AsyncStream<Record>.Continuation
        let registeredAt: Date
        var lastSequenceNumber: UInt64
    }

    /// User-configured capacity of recent records retained for delta catch-up.
    public let ringBufferCapacity: Int

    /// In-memory ring buffer of recent mutations.
    private var ringBuffer: RingBuffer<Record>

    /// Active connected subscribers keyed by unique subscriber ID.
    private var subscribers: [String: Subscriber]

    /// Monotonically tracked highest sequence number broadcasted.
    public private(set) var lastSequenceNumber: UInt64 = 0

    /// Total count of records broadcasted since startup.
    public private(set) var totalBroadcastedRecords: UInt64 = 0

    /// Initializes a `ReplicationBroadcaster`.
    ///
    /// - Parameter ringBufferCapacity: Maximum recent records to retain in memory (default: 1,000).
    public init(ringBufferCapacity: Int = 1000) {
        self.ringBufferCapacity = max(1, ringBufferCapacity)
        self.ringBuffer = RingBuffer<Record>(capacity: ringBufferCapacity)
        self.subscribers = [:]
    }

    // MARK: - Subscriber Management

    /// Subscribes a follower node, returning an `AsyncStream` of live mutations and gap status.
    ///
    /// If `fromSequenceNumber` is within the ring buffer range, missed records are yielded
    /// into the stream immediately. If the follower has lagged past the oldest buffered record,
    /// `needsFullSnapshot` is returned as `true`.
    ///
    /// - Parameters:
    ///   - subscriberID: Unique identifier for the subscriber node.
    ///   - fromSequenceNumber: The sequence number last applied by the follower (0 = fresh node).
    /// - Returns: Tuple of `(stream, needsFullSnapshot)`.
    public func subscribe(
        subscriberID: String,
        fromSequenceNumber: UInt64 = 0
    ) -> (stream: AsyncStream<Record>, needsFullSnapshot: Bool) {
        // If subscriber previously existed, close old continuation
        if let existing = subscribers[subscriberID] {
            existing.continuation.finish()
            subscribers.removeValue(forKey: subscriberID)
        }

        var needsSnapshot = false
        var catchupRecords: [Record] = []

        if fromSequenceNumber == 0 && lastSequenceNumber > 0 {
            // Fresh follower joining non-empty leader requires initial snapshot
            needsSnapshot = true
        } else if fromSequenceNumber > 0 && fromSequenceNumber < lastSequenceNumber {
            if let oldest = ringBuffer.first?.sequenceNumber, fromSequenceNumber < oldest - 1 {
                // Gap exceeds ring buffer retention
                needsSnapshot = true
            } else {
                // Yield missed delta records
                catchupRecords = ringBuffer.filter { $0.sequenceNumber > fromSequenceNumber }
            }
        }

        let (stream, continuation) = AsyncStream<Record>.makeStream()

        for record in catchupRecords {
            continuation.yield(record)
        }

        let sub = Subscriber(
            id: subscriberID,
            continuation: continuation,
            registeredAt: Date(),
            lastSequenceNumber: catchupRecords.last?.sequenceNumber ?? fromSequenceNumber
        )
        subscribers[subscriberID] = sub

        return (stream, needsSnapshot)
    }

    /// Unsubscribes a follower and closes its stream continuation.
    ///
    /// - Parameter subscriberID: The subscriber identifier.
    public func unsubscribe(subscriberID: String) {
        if let sub = subscribers.removeValue(forKey: subscriberID) {
            sub.continuation.finish()
        }
    }

    // MARK: - Broadcasting

    /// Broadcasts a record to all active subscribers and retains it in the recent ring buffer.
    ///
    /// - Parameter record: The sequenced record to distribute.
    public func broadcast(_ record: Record) {
        lastSequenceNumber = max(lastSequenceNumber, record.sequenceNumber)
        totalBroadcastedRecords += 1

        ringBuffer.append(record)

        for (id, var sub) in subscribers {
            sub.lastSequenceNumber = record.sequenceNumber
            subscribers[id] = sub
            sub.continuation.yield(record)
        }
    }

    /// Closes all subscriber streams and clears buffers.
    public func closeAll() {
        for (_, sub) in subscribers {
            sub.continuation.finish()
        }
        subscribers.removeAll()
        ringBuffer = RingBuffer<Record>(capacity: ringBufferCapacity)
    }

    // MARK: - Telemetry & Metrics

    /// Number of currently active connected subscribers.
    public var connectedCount: Int {
        subscribers.count
    }

    /// Sorted list of active subscriber telemetry snapshots.
    public var activeSubscribers: [ReplicationSubscriberInfo] {
        subscribers.values.map {
            ReplicationSubscriberInfo(
                id: $0.id,
                registeredAt: $0.registeredAt,
                lastSequenceNumber: $0.lastSequenceNumber
            )
        }.sorted(by: { $0.id < $1.id })
    }

    /// Oldest sequence number currently retained in the memory ring buffer.
    public var oldestBufferedSequenceNumber: UInt64? {
        ringBuffer.first?.sequenceNumber
    }
}
