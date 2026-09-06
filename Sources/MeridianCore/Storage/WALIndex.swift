//
//  WALIndex.swift
//  MeridianCore
//

import Foundation

/// Fast random-access pointer locating a specific record within a WAL segment file.
public struct WALRecordPointer: Sendable, Equatable {
    /// 1-based index of the containing segment file.
    public let segmentIndex: Int

    /// Absolute filesystem path to the segment file.
    public let segmentPath: String

    /// Byte offset within the segment file.
    public let offset: UInt64

    /// Sequence number of the record.
    public let sequenceNumber: UInt64

    /// Record timestamp in milliseconds since Unix epoch.
    public let timestampMillis: Int64

    /// Date representation of the record timestamp.
    public var timestamp: Date {
        Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0)
    }

    public init(
        segmentIndex: Int,
        segmentPath: String,
        offset: UInt64,
        sequenceNumber: UInt64,
        timestampMillis: Int64
    ) {
        self.segmentIndex = segmentIndex
        self.segmentPath = segmentPath
        self.offset = offset
        self.sequenceNumber = sequenceNumber
        self.timestampMillis = timestampMillis
    }
}

/// Sparse B-Tree backed index for sub-millisecond random-access seeking by timestamp or sequence number.
public struct WALIndex: Sendable {
    /// Index mapping timestamp in epoch milliseconds to nearest record pointer.
    private var timeTree: BTree<Int64, WALRecordPointer>

    /// Index mapping sequence number to record pointer.
    private var sequenceTree: BTree<UInt64, WALRecordPointer>

    /// Number of checkpoints stored in the index.
    public var count: Int { timeTree.count }

    /// Initializes an empty `WALIndex`.
    public init() {
        self.timeTree = BTree<Int64, WALRecordPointer>(degree: 16)
        self.sequenceTree = BTree<UInt64, WALRecordPointer>(degree: 16)
    }

    /// Inserts a checkpoint pointer into both time and sequence indices.
    public mutating func insert(_ pointer: WALRecordPointer) {
        timeTree[pointer.timestampMillis] = pointer
        sequenceTree[pointer.sequenceNumber] = pointer
    }

    /// Indexes an array of decoded records, inserting a checkpoint every `interval` records plus the first and last.
    public mutating func index(
        records: [WALRecord],
        segmentIndex: Int,
        segmentPath: String,
        interval: Int = 100
    ) {
        guard !records.isEmpty else { return }

        for (i, rec) in records.enumerated() {
            let isCheckpoint = (i == 0) || (i == records.count - 1) || (i % interval == 0)
            if isCheckpoint {
                let ptr = WALRecordPointer(
                    segmentIndex: segmentIndex,
                    segmentPath: segmentPath,
                    offset: rec.offset,
                    sequenceNumber: rec.sequenceNumber,
                    timestampMillis: rec.timestampMillis
                )
                insert(ptr)
            }
        }
    }

    /// Finds the nearest checkpoint pointer occurring at or immediately preceding `timestamp`.
    public func findNearest(timestamp: Date) -> WALRecordPointer? {
        let targetMillis = Int64(timestamp.timeIntervalSince1970 * 1000)
        // Scan range up to targetMillis and pick the highest key
        let candidates = timeTree.scan(from: 0, to: targetMillis)
        return candidates.last?.value
    }

    /// Finds the nearest checkpoint pointer occurring at or immediately preceding `sequenceNumber`.
    public func findNearest(sequenceNumber: UInt64) -> WALRecordPointer? {
        let candidates = sequenceTree.scan(from: 0, to: sequenceNumber)
        return candidates.last?.value
    }
}
