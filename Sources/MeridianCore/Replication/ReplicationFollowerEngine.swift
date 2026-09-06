//
//  ReplicationFollowerEngine.swift
//  DataStructuresSwift
//

import Foundation

/// Lifecycle state of a replication follower connection.
public enum ReplicationFollowerState: Sendable, Equatable, CustomStringConvertible {
    case disconnected
    case syncingSnapshot
    case streaming(lastSequence: UInt64)
    case recovering(backoffNanoseconds: UInt64, attempts: Int)

    public var isStreaming: Bool {
        if case .streaming = self { return true }
        return false
    }

    public var description: String {
        switch self {
        case .disconnected:
            return "disconnected"
        case .syncingSnapshot:
            return "syncingSnapshot"
        case .streaming(let seq):
            return "streaming(seq: \(seq))"
        case .recovering(let backoff, let attempts):
            return "recovering(backoff: \(Double(backoff) / 1e9)s, attempt: \(attempts))"
        }
    }
}

/// Point-in-time telemetry snapshot of the replication follower engine.
public struct ReplicationEngineStatus: Sendable, Equatable {
    public let state: ReplicationFollowerState
    public let lastAppliedSequenceNumber: UInt64
    public let totalReplicatedRecords: UInt64
    public let lastSyncTimestamp: Date?
    public let reconnectAttempts: Int

    public init(
        state: ReplicationFollowerState,
        lastAppliedSequenceNumber: UInt64,
        totalReplicatedRecords: UInt64,
        lastSyncTimestamp: Date?,
        reconnectAttempts: Int
    ) {
        self.state = state
        self.lastAppliedSequenceNumber = lastAppliedSequenceNumber
        self.totalReplicatedRecords = totalReplicatedRecords
        self.lastSyncTimestamp = lastSyncTimestamp
        self.reconnectAttempts = reconnectAttempts
    }
}

/// Swift 6 actor coordinating follower replication state, monotonic deduplication,
/// and exponential reconnect backoff with jitter.
public actor ReplicationFollowerEngine<Record: SequencedRecord> {
    public private(set) var state: ReplicationFollowerState = .disconnected
    public private(set) var lastAppliedSequenceNumber: UInt64
    public private(set) var totalReplicatedRecords: UInt64 = 0
    public private(set) var lastSyncTimestamp: Date?
    public private(set) var reconnectAttempts: Int = 0

    private var currentBackoffNanoseconds: UInt64
    public let initialBackoffNanoseconds: UInt64
    public let maxBackoffNanoseconds: UInt64
    public let backoffMultiplier: Double

    /// Initializes a `ReplicationFollowerEngine`.
    ///
    /// - Parameters:
    ///   - initialSequenceNumber: Starting sequence number baseline.
    ///   - initialBackoffNanoseconds: Base backoff delay (default: 250ms).
    ///   - maxBackoffNanoseconds: Maximum backoff ceiling (default: 5.0s).
    ///   - backoffMultiplier: Exponential backoff factor (default: 2.0).
    public init(
        initialSequenceNumber: UInt64 = 0,
        initialBackoffNanoseconds: UInt64 = 250_000_000,
        maxBackoffNanoseconds: UInt64 = 5_000_000_000,
        backoffMultiplier: Double = 2.0
    ) {
        self.lastAppliedSequenceNumber = initialSequenceNumber
        self.initialBackoffNanoseconds = initialBackoffNanoseconds
        self.maxBackoffNanoseconds = maxBackoffNanoseconds
        self.backoffMultiplier = backoffMultiplier
        self.currentBackoffNanoseconds = initialBackoffNanoseconds
    }

    /// Determines whether an incoming record should be applied or ignored as a duplicate.
    public func shouldApply(sequenceNumber: UInt64) -> Bool {
        if sequenceNumber <= lastAppliedSequenceNumber && lastAppliedSequenceNumber > 0 {
            return false
        }
        return true
    }

    /// Records that a mutation has been applied locally, updating sequence numbers and metrics.
    public func recordApplied(sequenceNumber: UInt64, timestamp: Date = Date()) {
        lastAppliedSequenceNumber = max(lastAppliedSequenceNumber, sequenceNumber)
        totalReplicatedRecords += 1
        lastSyncTimestamp = timestamp
        state = .streaming(lastSequence: lastAppliedSequenceNumber)
        resetBackoff()
    }

    /// Updates sequence number and resets backoff upon completing a full snapshot synchronization.
    public func snapshotApplied(sequenceNumber: UInt64, timestamp: Date = Date()) {
        lastAppliedSequenceNumber = sequenceNumber
        lastSyncTimestamp = timestamp
        state = .streaming(lastSequence: sequenceNumber)
        resetBackoff()
    }

    /// Transitions the engine into `.syncingSnapshot` state.
    public func startSyncingSnapshot() {
        state = .syncingSnapshot
    }

    /// Marks the connection as established and transitioning to active streaming.
    public func recordConnectionSuccess() {
        state = .streaming(lastSequence: lastAppliedSequenceNumber)
        resetBackoff()
    }

    /// Records a connection failure, updates state to `.recovering`, and returns the next backoff duration.
    public func recordConnectionFailure() -> UInt64 {
        reconnectAttempts += 1
        let backoff = currentBackoffNanoseconds
        currentBackoffNanoseconds = min(
            UInt64(Double(currentBackoffNanoseconds) * backoffMultiplier),
            maxBackoffNanoseconds
        )
        state = .recovering(backoffNanoseconds: backoff, attempts: reconnectAttempts)
        return backoff
    }

    /// Resets the reconnect backoff and attempts counter.
    public func resetBackoff() {
        currentBackoffNanoseconds = initialBackoffNanoseconds
        reconnectAttempts = 0
    }

    /// Transitions the engine to `.disconnected`.
    public func disconnect() {
        state = .disconnected
    }

    /// Returns a point-in-time status snapshot.
    public var status: ReplicationEngineStatus {
        ReplicationEngineStatus(
            state: state,
            lastAppliedSequenceNumber: lastAppliedSequenceNumber,
            totalReplicatedRecords: totalReplicatedRecords,
            lastSyncTimestamp: lastSyncTimestamp,
            reconnectAttempts: reconnectAttempts
        )
    }
}
