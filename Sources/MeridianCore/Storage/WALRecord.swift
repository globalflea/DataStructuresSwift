//
//  WALRecord.swift
//  DataStructuresSwift
//

import Foundation

/// A structured Write-Ahead Log record envelope.
public struct WALRecord: Sendable, Equatable {
    /// Monotonically increasing sequence number.
    public let sequenceNumber: UInt64

    /// Timestamp when the record was persisted.
    public let timestamp: Date

    /// Timestamp in epoch milliseconds.
    public var timestampMillis: Int64 {
        Int64(timestamp.timeIntervalSince1970 * 1000)
    }

    /// Raw binary or serialized payload bytes.
    public let payload: Data

    /// Byte offset within the WAL file where this record begins.
    public let offset: UInt64

    /// Total framed byte size on disk (header + payload, plus trailing newline if JSON).
    public let byteSize: Int

    /// Computed 64-bit CRC checksum of the payload.
    public let crc64: UInt64

    /// 4-byte magic identifier used for binary framing.
    public let magic: UInt32

    public init(
        sequenceNumber: UInt64,
        timestamp: Date,
        payload: Data,
        offset: UInt64 = 0,
        byteSize: Int = 0,
        crc64: UInt64 = 0,
        magic: UInt32 = defaultWALBinaryMagic
    ) {
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.payload = payload
        self.offset = offset
        self.byteSize = byteSize
        self.crc64 = crc64
        self.magic = magic
    }
}
