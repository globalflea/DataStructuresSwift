//
//  WALReader.swift
//  DataStructuresSwift
//

import Foundation

/// Sequential stream reader for decoding and replaying Write-Ahead Log entries.
///
/// Validates 64-bit CRC-64 checksums, recovers from torn trailing writes caused by unexpected crashes,
/// and rehydrates in-memory state during system recovery.
public struct WALReader: Sendable {
    /// Filesystem path to the WAL file.
    public let path: String

    /// Serialization format (`.binary` or `.json`).
    public let format: WALFormat

    /// Expected 4-byte magic identifier (nil to accept any magic).
    public let expectedMagic: UInt32?

    /// Whether to recover gracefully from a partial trailing record at EOF caused by a crash.
    public let allowTruncatedTail: Bool

    /// Initializes a `WALReader`.
    public init(
        path: String,
        format: WALFormat = .binary,
        expectedMagic: UInt32? = defaultWALBinaryMagic,
        allowTruncatedTail: Bool = true
    ) {
        self.path = path
        self.format = format
        self.expectedMagic = expectedMagic
        self.allowTruncatedTail = allowTruncatedTail
    }

    /// Reads and decodes all valid records sequentially from the log file.
    public func readAll() throws -> [WALRecord] {
        try readRecords(fromOffset: 0).records
    }

    /// Reads records starting from a specific byte offset, returning decoded entries and any torn tail offset.
    public func readRecords(fromOffset startOffset: UInt64 = 0) throws -> (records: [WALRecord], truncatedTailOffset: UInt64?) {
        guard FileManager.default.fileExists(atPath: path) else {
            return ([], nil)
        }

        let fileURL = URL(fileURLWithPath: path)
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL, options: .alwaysMapped)
        } catch {
            throw WALError.ioError(reason: "Failed to read WAL file at \(path): \(error.localizedDescription)")
        }

        guard !fileData.isEmpty else {
            return ([], nil)
        }

        switch format {
        case .binary:
            return try readBinaryRecords(from: fileData, startOffset: startOffset)
        case .json:
            return try readJSONRecords(from: fileData, startOffset: startOffset)
        }
    }

    /// Returns the highest sequence number present in the log file, or nil if empty.
    public func lastSequenceNumber() throws -> UInt64? {
        let (records, _) = try readRecords()
        return records.last?.sequenceNumber
    }

    /// Repairs a corrupted log file by truncating any partial / torn write at EOF.
    @discardableResult
    public func repair() throws -> (validCount: Int, truncatedBytes: Int) {
        let (records, tailOffset) = try readRecords()
        guard let tail = tailOffset else {
            return (records.count, 0)
        }
        let fileHandle = try FileHandle(forUpdating: URL(fileURLWithPath: path))
        let fullSize = try fileHandle.seekToEnd()
        try fileHandle.truncate(atOffset: tail)
        try fileHandle.synchronize()
        try fileHandle.close()
        return (records.count, Int(fullSize - tail))
    }

    // MARK: - Internal Decoding

    private func readBinaryRecords(
        from data: Data,
        startOffset: UInt64
    ) throws -> (records: [WALRecord], truncatedTailOffset: UInt64?) {
        var records: [WALRecord] = []
        var offset = Int(startOffset)
        let totalBytes = data.count
        var truncatedOffset: UInt64? = nil

        while offset < totalBytes {
            let recordStart = UInt64(offset)
            let remaining = totalBytes - offset

            // Check if there is enough space for the fixed header
            if remaining < walHeaderSize {
                if allowTruncatedTail {
                    truncatedOffset = recordStart
                    break
                } else {
                    throw WALError.truncatedLog(offset: recordStart)
                }
            }

            guard let header = WALFrame.decodeHeader(from: data, offset: offset) else {
                if allowTruncatedTail {
                    truncatedOffset = recordStart
                    break
                } else {
                    throw WALError.corruptedRecord(offset: recordStart, reason: "Unable to parse frame header")
                }
            }

            // Verify magic header
            if let expected = expectedMagic, header.magic != expected {
                throw WALError.invalidMagic(expected: expected, found: header.magic)
            }

            let payloadLen = Int(header.payloadLength)
            let frameTotalSize = walHeaderSize + payloadLen

            // Check if entire payload is present
            if remaining < frameTotalSize {
                if allowTruncatedTail {
                    truncatedOffset = recordStart
                    break
                } else {
                    throw WALError.truncatedLog(offset: recordStart)
                }
            }

            let payloadStart = offset + walHeaderSize
            let payloadEnd = payloadStart + payloadLen
            let payload = data.subdata(in: payloadStart..<payloadEnd)

            // Validate CRC-64 checksum
            let actualCRC = CRC64.checksum(payload)
            if actualCRC != header.crc64 {
                throw WALError.checksumMismatch(expected: header.crc64, actual: actualCRC)
            }

            let date = Date(timeIntervalSince1970: Double(header.timestampMillis) / 1000.0)
            let record = WALRecord(
                sequenceNumber: header.sequenceNumber,
                timestamp: date,
                payload: payload,
                offset: recordStart,
                byteSize: frameTotalSize,
                crc64: header.crc64,
                magic: header.magic
            )

            records.append(record)
            offset += frameTotalSize
        }

        return (records, truncatedOffset)
    }

    private func readJSONRecords(
        from data: Data,
        startOffset: UInt64
    ) throws -> (records: [WALRecord], truncatedTailOffset: UInt64?) {
        var records: [WALRecord] = []
        var offset = Int(startOffset)
        var sequenceNumber: UInt64 = 0
        let totalBytes = data.count

        while offset < totalBytes {
            let recordStart = UInt64(offset)
            var lineEnd = offset
            while lineEnd < totalBytes && data[lineEnd] != 0x0A {
                lineEnd += 1
            }

            let lineLength = lineEnd - offset
            if lineLength > 0 {
                let payload = data.subdata(in: offset..<lineEnd)
                sequenceNumber += 1
                let record = WALRecord(
                    sequenceNumber: sequenceNumber,
                    timestamp: Date(),
                    payload: payload,
                    offset: recordStart,
                    byteSize: (lineEnd < totalBytes ? lineLength + 1 : lineLength),
                    crc64: 0,
                    magic: defaultWALBinaryMagic
                )
                records.append(record)
            }

            offset = lineEnd + 1
        }

        return (records, nil)
    }
}
