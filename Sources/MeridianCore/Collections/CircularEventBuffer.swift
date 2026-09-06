//
//  CircularEventBuffer.swift
//  DataStructures
//
//  Created on 2026-09-06.
//

import Foundation

/// Contract for any domain element bearing a chronological timestamp.
public protocol TimestampedItem: Sendable {
    var timestamp: Date { get }
}

/// A high-performance, bounded $O(1)$ circular ring buffer specifically optimized
/// for chronological event recording and point-in-time replay catch-up queries.
///
/// Thread safety is achieved at the caller or enclosing actor level, guaranteeing
/// maximum single-thread throughput without unnecessary lock contention.
public struct CircularEventBuffer<Element: TimestampedItem>: Sendable {
    /// Maximum number of historical events retained in the ring buffer.
    public let capacity: Int

    private var buffer: [Element?]
    private var writeIndex: Int = 0
    private var isBufferFull: Bool = false

    /// Initializes a circular event buffer with a fixed maximum capacity.
    ///
    /// - Parameter capacity: Maximum number of events retained before oldest entries are overwritten.
    public init(capacity: Int = 10_000) {
        precondition(capacity > 0, "Capacity must be strictly positive")
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    /// Appends a new event into the circular buffer in $O(1)$ constant time.
    ///
    /// If the buffer is full, the oldest event at `writeIndex` is overwritten.
    ///
    /// - Parameter event: The timestamped event to record.
    public mutating func append(_ event: Element) {
        buffer[writeIndex] = event
        writeIndex = (writeIndex + 1) % capacity
        if writeIndex == 0 {
            isBufferFull = true
        }
    }

    /// Number of active events currently recorded in the buffer.
    public var count: Int {
        isBufferFull ? capacity : writeIndex
    }

    /// Returns `true` if the buffer contains zero recorded events.
    public var isEmpty: Bool {
        count == 0
    }

    /// Returns `true` if the buffer has filled its capacity and is currently overwriting oldest entries.
    public var isFull: Bool {
        isBufferFull
    }

    /// Queries the buffer for historical events occurring strictly after `since`,
    /// evaluated in chronological FIFO order (oldest to newest).
    ///
    /// - Parameters:
    ///   - since: Cutoff timestamp. Only events with `timestamp > since` will be returned.
    ///   - predicate: Optional custom predicate filtering matching events.
    /// - Returns: An ordered array of missed events matching the cutoff and criteria.
    public func events(
        since: Date,
        where predicate: ((Element) -> Bool)? = nil
    ) -> [Element] {
        let sinceMillis = Int64(since.timeIntervalSince1970 * 1000)
        return events(sinceTimestampMillis: sinceMillis, where: predicate)
    }

    /// Queries the buffer for historical events occurring strictly after `sinceTimestampMillis` (inclusive cutoff comparison),
    /// evaluated in chronological FIFO order.
    ///
    /// - Parameters:
    ///   - sinceTimestampMillis: Millisecond epoch cutoff timestamp.
    ///   - predicate: Optional custom predicate filtering matching events.
    /// - Returns: An ordered array of events occurring after `sinceTimestampMillis`.
    public func events(
        sinceTimestampMillis: Int64,
        where predicate: ((Element) -> Bool)? = nil
    ) -> [Element] {
        guard count > 0 else { return [] }

        var result: [Element] = []
        result.reserveCapacity(min(count, 128))

        let total = count
        let startIndex = isBufferFull ? writeIndex : 0

        for i in 0..<total {
            let idx = (startIndex + i) % capacity
            guard let event = buffer[idx] else { continue }

            let eventMillis = Int64(event.timestamp.timeIntervalSince1970 * 1000)
            if eventMillis <= sinceTimestampMillis {
                continue
            }

            if let predicate = predicate, !predicate(event) {
                continue
            }

            result.append(event)
        }

        return result
    }

    /// Returns all currently stored events in chronological order (oldest to newest).
    public func allEvents() -> [Element] {
        guard count > 0 else { return [] }
        var result: [Element] = []
        result.reserveCapacity(count)

        let total = count
        let startIndex = isBufferFull ? writeIndex : 0

        for i in 0..<total {
            let idx = (startIndex + i) % capacity
            if let event = buffer[idx] {
                result.append(event)
            }
        }
        return result
    }

    /// Clears all historical events from the buffer and resets head/tail indices.
    public mutating func clear() {
        buffer = Array(repeating: nil, count: capacity)
        writeIndex = 0
        isBufferFull = false
    }
}
