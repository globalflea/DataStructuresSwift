//
//  SlidingDeduplicator.swift
//  Resilience
//
//  Created on 2026-09-06.
//

import Foundation

/// Protocol for domain events capable of generating a deterministic deduplication key.
public protocol Deduplicatable: Sendable {
    associatedtype DeduplicationKey: Hashable & Sendable
    var deduplicationKey: DeduplicationKey { get }
}

/// Thread-safe sliding TTL idempotency cache filtering duplicate event notifications
/// across network reconnections, replay catch-up, and redundant webhook deliveries.
///
/// Guarantees exactly-once processing semantics even under at-least-once transport delivery.
public actor SlidingDeduplicator<Key: Hashable & Sendable>: Sendable {
    private var seenKeys: [Key: Date] = [:]
    public let ttl: TimeInterval
    private var lastPruneDate: Date = Date()
    private let pruneInterval: TimeInterval

    /// Initializes a deduplicator with a configurable sliding TTL and prune frequency.
    ///
    /// - Parameters:
    ///   - ttl: Time-to-live for recorded event keys in seconds (default: 300s = 5m).
    ///   - pruneInterval: Frequency of expired key purging (default: 60s).
    public init(ttl: TimeInterval = 300.0, pruneInterval: TimeInterval = 60.0) {
        self.ttl = ttl
        self.pruneInterval = pruneInterval
    }

    /// Evaluates if the key is new or a duplicate.
    ///
    /// - Parameters:
    ///   - key: The unique event key.
    ///   - now: Reference date for sliding TTL calculation (default: current date).
    /// - Returns: `true` if the event is NEW and has been recorded; `false` if it is a DUPLICATE within the TTL window.
    public func checkAndRecord(key: Key, now: Date = Date()) -> Bool {
        pruneIfNeeded(now: now)

        if let seenDate = seenKeys[key] {
            if now.timeIntervalSince(seenDate) <= ttl {
                return false // Duplicate within TTL window
            }
        }

        seenKeys[key] = now
        return true // New event
    }

    /// Evaluates any domain model conforming to `Deduplicatable`.
    public func checkAndRecord<E: Deduplicatable>(item: E, now: Date = Date()) -> Bool where E.DeduplicationKey == Key {
        checkAndRecord(key: item.deduplicationKey, now: now)
    }

    /// Number of active keys currently tracked in the cache.
    public var count: Int {
        seenKeys.count
    }

    /// Returns `true` if zero keys are currently recorded.
    public var isEmpty: Bool {
        seenKeys.isEmpty
    }

    /// Clears all recorded keys.
    public func clear() {
        seenKeys.removeAll()
    }

    private func pruneIfNeeded(now: Date) {
        guard now.timeIntervalSince(lastPruneDate) >= pruneInterval else { return }
        lastPruneDate = now

        let cutoff = now.addingTimeInterval(-ttl)
        seenKeys = seenKeys.filter { _, date in
            date > cutoff
        }
    }
}
