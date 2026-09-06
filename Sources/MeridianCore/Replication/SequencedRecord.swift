//
//  SequencedRecord.swift
//  DataStructuresSwift
//

import Foundation

/// Defines an ordered, timestamped record envelope suitable for streaming replication.
public protocol SequencedRecord: Sendable {
    /// Monotonically increasing sequence number identifying this mutation.
    var sequenceNumber: UInt64 { get }

    /// Timestamp at which the record was generated.
    var timestamp: Date { get }
}

extension WALRecord: SequencedRecord {}
