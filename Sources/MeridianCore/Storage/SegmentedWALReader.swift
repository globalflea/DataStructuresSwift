//
//  SegmentedWALReader.swift
//  MeridianCore
//

import Foundation

/// Sequential reader for decoding records across multi-file segmented Write-Ahead Logs.
///
/// Seamlessly traverses segment boundaries in generation order, tolerating purged historical
/// segments and validating 64-bit CRC-64 checksums across all files.
public struct SegmentedWALReader: Sendable {
    /// Directory containing the segmented WAL files.
    public let directoryPath: String

    /// Serialization format (`.binary` or `.json`).
    public let format: WALFormat

    /// Expected 4-byte magic identifier.
    public let expectedMagic: UInt32?

    /// Whether to gracefully recover from partial trailing records in the latest active segment.
    public let allowTruncatedTail: Bool

    /// Initializes a `SegmentedWALReader`.
    public init(
        directoryPath: String,
        format: WALFormat = .binary,
        expectedMagic: UInt32? = defaultWALBinaryMagic,
        allowTruncatedTail: Bool = true
    ) {
        self.directoryPath = directoryPath
        self.format = format
        self.expectedMagic = expectedMagic
        self.allowTruncatedTail = allowTruncatedTail
    }

    /// Discovers all available segment files in the directory sorted by generation index.
    public func listSegments() throws -> [WALSegmentMetadata] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryPath) else {
            return []
        }

        let items = try fileManager.contentsOfDirectory(atPath: directoryPath)
        var segments: [WALSegmentMetadata] = []

        for file in items {
            guard file.hasPrefix("wal-") && file.hasSuffix(".wal") else { continue }
            let indexPart = file.dropFirst(4).dropLast(4)
            guard let index = Int(indexPart) else { continue }

            let fullPath = URL(fileURLWithPath: directoryPath).appendingPathComponent(file).path
            let attrs = try fileManager.attributesOfItem(atPath: fullPath)
            let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0

            // Read header/tail metadata if file is non-empty
            var startTime: Date? = nil
            var endTime: Date? = nil
            var firstSeq: UInt64? = nil
            var lastSeq: UInt64? = nil

            if size > 0 {
                let inspector = WALInspector(path: fullPath, format: format, expectedMagic: expectedMagic)
                if let summary = try? inspector.summary() {
                    startTime = summary.startTime
                    endTime = summary.endTime
                    firstSeq = summary.firstSequenceNumber
                    lastSeq = summary.lastSequenceNumber
                }
            }

            segments.append(WALSegmentMetadata(
                index: index,
                path: fullPath,
                byteSize: size,
                startTime: startTime,
                endTime: endTime,
                firstSequenceNumber: firstSeq,
                lastSequenceNumber: lastSeq
            ))
        }

        return segments.sorted { $0.index < $1.index }
    }

    /// Reads all valid records across all segment files in chronological order.
    public func readAll() throws -> [WALRecord] {
        let segments = try listSegments()
        var allRecords: [WALRecord] = []

        for (i, seg) in segments.enumerated() {
            let isLatest = (i == segments.count - 1)
            let reader = WALReader(
                path: seg.path,
                format: format,
                expectedMagic: expectedMagic,
                allowTruncatedTail: isLatest ? allowTruncatedTail : false
            )
            let records = try reader.readAll()
            allRecords.append(contentsOf: records)
        }

        return allRecords
    }

    /// Reads records across segments starting from a minimum sequence number.
    public func readRecords(fromSequence startSequence: UInt64) throws -> [WALRecord] {
        let all = try readAll()
        return all.filter { $0.sequenceNumber >= startSequence }
    }

    /// Reads records across segments starting from a minimum timestamp.
    public func readRecords(fromTimestamp startTimestamp: Date) throws -> [WALRecord] {
        let all = try readAll()
        return all.filter { $0.timestamp >= startTimestamp }
    }
}

extension SegmentedWALReader {
    /// Exports all records across all segments into RFC 4180 CSV format.
    ///
    /// - Parameters:
    ///   - reverseOrder: When `true` (default), records are sorted in descending reverse-time order (newest first).
    ///   - payloadDecoder: Optional closure providing custom human-readable decoding for payloads.
    /// - Returns: A formatted CSV string with standard headers.
    public func exportCSV(
        reverseOrder: Bool = true,
        payloadDecoder: (@Sendable (Data) -> String?)? = nil
    ) throws -> String {
        let records = try readAll()
        return WALInspector.formatCSV(records: records, reverseOrder: reverseOrder, payloadDecoder: payloadDecoder)
    }

    /// Exports all records across all segments into a CSV file at `destinationPath`.
    public func exportCSV(
        toPath destinationPath: String,
        reverseOrder: Bool = true,
        payloadDecoder: (@Sendable (Data) -> String?)? = nil
    ) throws {
        let csv = try exportCSV(reverseOrder: reverseOrder, payloadDecoder: payloadDecoder)
        try csv.write(toFile: destinationPath, atomically: true, encoding: .utf8)
    }
}
