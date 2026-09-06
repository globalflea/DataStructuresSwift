//
//  WALInspector.swift
//  DataStructuresSwift
//

import Foundation

/// High-level inspection summary of a Write-Ahead Log file.
public struct WALSummary: Sendable, Equatable, CustomStringConvertible {
    public let path: String
    public let format: WALFormat
    public let totalRecords: Int
    public let fileSizeBytes: UInt64
    public let totalPayloadBytes: UInt64
    public let firstSequenceNumber: UInt64?
    public let lastSequenceNumber: UInt64?
    public let startTime: Date?
    public let endTime: Date?
    public let truncatedTailOffset: UInt64?
    public let isTruncated: Bool

    public var description: String {
        var lines: [String] = []
        lines.append("=== WAL Inspection Summary ===")
        lines.append("File Path:       \(path)")
        lines.append("Format:          \(format.rawValue)")
        lines.append("Total Records:   \(totalRecords)")
        lines.append("File Size:       \(fileSizeBytes) bytes")
        lines.append("Payload Size:    \(totalPayloadBytes) bytes")
        if let first = firstSequenceNumber, let last = lastSequenceNumber {
            lines.append("Sequence Range:  \(first) -> \(last)")
        } else {
            lines.append("Sequence Range:  None")
        }
        if let start = startTime, let end = endTime {
            let df = ISO8601DateFormatter()
            lines.append("Time Range:      \(df.string(from: start)) -> \(df.string(from: end))")
        }
        if isTruncated, let tail = truncatedTailOffset {
            lines.append("Integrity:       ⚠️ Torn trailing record detected and recovered at byte offset \(tail)")
        } else {
            lines.append("Integrity:       ✅ All records valid (CRC-64 verified)")
        }
        lines.append("==============================")
        return lines.joined(separator: "\n")
    }
}

/// Detailed inspection information for a single WAL record.
public struct WALRecordInspection: Sendable, Equatable {
    public let sequenceNumber: UInt64
    public let timestamp: Date
    public let offset: UInt64
    public let byteSize: Int
    public let payloadSize: Int
    public let crc64Hex: String
    public let magicHex: String
    public let payloadSummary: String
}

/// Generic Write-Ahead Log inspector and diagnostic dumping tool.
public struct WALInspector: Sendable {
    public let path: String
    public let format: WALFormat
    public let expectedMagic: UInt32?

    public init(
        path: String,
        format: WALFormat = .binary,
        expectedMagic: UInt32? = defaultWALBinaryMagic
    ) {
        self.path = path
        self.format = format
        self.expectedMagic = expectedMagic
    }

    /// Computes a structural summary of the WAL file.
    public func summary() throws -> WALSummary {
        let reader = WALReader(path: path, format: format, expectedMagic: expectedMagic, allowTruncatedTail: true)
        let (records, truncatedTail) = try reader.readRecords()

        let fileAttrs = try? FileManager.default.attributesOfItem(atPath: path)
        let fileSize = (fileAttrs?[.size] as? NSNumber)?.uint64Value ?? 0
        let totalPayload = records.reduce(UInt64(0)) { $0 + UInt64($1.payload.count) }

        return WALSummary(
            path: path,
            format: format,
            totalRecords: records.count,
            fileSizeBytes: fileSize,
            totalPayloadBytes: totalPayload,
            firstSequenceNumber: records.first?.sequenceNumber,
            lastSequenceNumber: records.last?.sequenceNumber,
            startTime: records.first?.timestamp,
            endTime: records.last?.timestamp,
            truncatedTailOffset: truncatedTail,
            isTruncated: truncatedTail != nil
        )
    }

    /// Generates structured diagnostic records with optional custom payload decoders.
    public func inspect(
        payloadDecoder: (@Sendable (Data) -> String?)? = nil
    ) throws -> [WALRecordInspection] {
        let reader = WALReader(path: path, format: format, expectedMagic: expectedMagic, allowTruncatedTail: true)
        let (records, _) = try reader.readRecords()

        return records.map { rec in
            let crcHex = String(format: "0x%016llX", rec.crc64)
            let magicHex = String(format: "0x%08X", rec.magic)
            let summaryStr: String
            if let custom = payloadDecoder?(rec.payload) {
                summaryStr = custom
            } else if let str = String(data: rec.payload, encoding: .utf8), !str.isEmpty {
                summaryStr = str.replacingOccurrences(of: "\n", with: " ")
            } else {
                summaryStr = "\(rec.payload.count) bytes"
            }

            return WALRecordInspection(
                sequenceNumber: rec.sequenceNumber,
                timestamp: rec.timestamp,
                offset: rec.offset,
                byteSize: rec.byteSize,
                payloadSize: rec.payload.count,
                crc64Hex: crcHex,
                magicHex: magicHex,
                payloadSummary: summaryStr
            )
        }
    }

    /// Dumps a human-readable diagnostic view of all records in the log.
    public func dump(
        verbose: Bool = false,
        payloadDecoder: (@Sendable (Data) -> String?)? = nil
    ) throws -> String {
        let sum = try summary()
        let inspections = try inspect(payloadDecoder: payloadDecoder)

        var lines: [String] = []
        lines.append(sum.description)
        lines.append("")
        lines.append(formatColumn("SEQ", width: 8) + " | " +
                     formatColumn("TIMESTAMP", width: 24) + " | " +
                     formatColumn("OFFSET", width: 10) + " | " +
                     formatColumn("SIZE", width: 8) + " | " +
                     formatColumn("CRC-64", width: 18) + " | PAYLOAD")
        lines.append(String(repeating: "-", count: 96))

        let df = ISO8601DateFormatter()
        for item in inspections {
            let tsStr = df.string(from: item.timestamp)
            let payloadText = verbose ? item.payloadSummary : String(item.payloadSummary.prefix(60))
            let line = formatColumn(String(item.sequenceNumber), width: 8) + " | " +
                       formatColumn(tsStr, width: 24) + " | " +
                       formatColumn(String(item.offset), width: 10) + " | " +
                       formatColumn(String(item.byteSize), width: 8) + " | " +
                       formatColumn(item.crc64Hex, width: 18) + " | " +
                       payloadText
            lines.append(line)
        }

        if sum.isTruncated, let tail = sum.truncatedTailOffset {
            lines.append(String(repeating: "-", count: 96))
            lines.append("⚠️ NOTICE: File contains incomplete / truncated write at offset \(tail). Tail was safely isolated.")
        }

        return lines.joined(separator: "\n")
    }

    private func formatColumn(_ string: String, width: Int) -> String {
        if string.count < width {
            return string + String(repeating: " ", count: width - string.count)
        } else {
            return String(string.prefix(width))
        }
    }

    // MARK: - CSV Export

    /// Exports the WAL records into RFC 4180 compliant CSV format.
    ///
    /// - Parameters:
    ///   - reverseOrder: When `true` (default), records are sorted in descending reverse-time order (newest first).
    ///   - payloadDecoder: Optional closure providing custom human-readable decoding for payloads.
    /// - Returns: A formatted CSV string with standard headers.
    public func exportCSV(
        reverseOrder: Bool = true,
        payloadDecoder: (@Sendable (Data) -> String?)? = nil
    ) throws -> String {
        let reader = WALReader(path: path, format: format, expectedMagic: expectedMagic, allowTruncatedTail: true)
        let (records, _) = try reader.readRecords()
        return Self.formatCSV(records: records, reverseOrder: reverseOrder, payloadDecoder: payloadDecoder)
    }

    /// Exports WAL records to a CSV file at `destinationPath`.
    public func exportCSV(
        toPath destinationPath: String,
        reverseOrder: Bool = true,
        payloadDecoder: (@Sendable (Data) -> String?)? = nil
    ) throws {
        let csv = try exportCSV(reverseOrder: reverseOrder, payloadDecoder: payloadDecoder)
        try csv.write(toFile: destinationPath, atomically: true, encoding: .utf8)
    }

    /// Formats an array of WALRecords into an RFC 4180 CSV string.
    public static func formatCSV(
        records: [WALRecord],
        reverseOrder: Bool = true,
        payloadDecoder: (@Sendable (Data) -> String?)? = nil
    ) -> String {
        let sorted = reverseOrder
            ? records.sorted {
                if $0.timestamp == $1.timestamp {
                    return $0.sequenceNumber > $1.sequenceNumber
                }
                return $0.timestamp > $1.timestamp
            }
            : records.sorted {
                if $0.timestamp == $1.timestamp {
                    return $0.sequenceNumber < $1.sequenceNumber
                }
                return $0.timestamp < $1.timestamp
            }

        var rows: [String] = []
        rows.append("sequence_number,timestamp_iso8601,offset,byte_size,payload_size,crc64_hex,magic_hex,payload")

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for rec in sorted {
            let seq = String(rec.sequenceNumber)
            let ts = df.string(from: rec.timestamp)
            let offset = String(rec.offset)
            let byteSize = String(rec.byteSize)
            let payloadSize = String(rec.payload.count)
            let crcHex = String(format: "0x%016llX", rec.crc64)
            let magicHex = String(format: "0x%08X", rec.magic)

            let payloadStr: String
            if let custom = payloadDecoder?(rec.payload) {
                payloadStr = custom
            } else if let str = String(data: rec.payload, encoding: .utf8), !str.isEmpty {
                payloadStr = str
            } else {
                payloadStr = rec.payload.map { String(format: "%02x", $0) }.joined()
            }

            let escapedPayload = escapeCSVField(payloadStr)
            rows.append("\(seq),\(ts),\(offset),\(byteSize),\(payloadSize),\(crcHex),\(magicHex),\(escapedPayload)")
        }

        return rows.joined(separator: "\r\n")
    }

    /// Escapes a single string value to conform to RFC 4180 CSV specifications.
    public static func escapeCSVField(_ value: String) -> String {
        let containsSpecial = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        if containsSpecial {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        } else {
            return value
        }
    }

}

