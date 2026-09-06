//
//  WALCSVExportTests.swift
//  MeridianCore
//

import Foundation
import Testing
@testable import MeridianCore

@Suite("Write-Ahead Log (WAL) CSV Export Tests")
struct WALCSVExportTests {
    private func createTempWALPath() -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueName = "test_export_\(UUID().uuidString).wal"
        return tempDir.appendingPathComponent(uniqueName).path
    }

    private func createTempDir() throws -> String {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("segmented_export_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir.path
    }

    private func cleanup(path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("WALInspector exports CSV with header and records sorted in reverse time order")
    func testCSVExportReverseOrder() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .binary, syncPolicy: .always)
        try await writer.open()

        let t0 = Date(timeIntervalSince1970: 1700000000)
        _ = try await writer.append(payload: Data("First payload".utf8), timestamp: t0)
        _ = try await writer.append(payload: Data("Second payload".utf8), timestamp: t0.addingTimeInterval(5))
        _ = try await writer.append(payload: Data("Third payload".utf8), timestamp: t0.addingTimeInterval(10))
        try await writer.close()

        let inspector = WALInspector(path: path, format: .binary)
        let csv = try inspector.exportCSV(reverseOrder: true)

        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 4) // 1 header + 3 records

        // Verify header
        #expect(lines[0] == "sequence_number,timestamp_iso8601,offset,byte_size,payload_size,crc64_hex,magic_hex,payload")

        // In reverse order: Row 1 = Seq 3, Row 2 = Seq 2, Row 3 = Seq 1
        #expect(lines[1].hasPrefix("3,"))
        #expect(lines[1].contains("Third payload"))

        #expect(lines[2].hasPrefix("2,"))
        #expect(lines[2].contains("Second payload"))

        #expect(lines[3].hasPrefix("1,"))
        #expect(lines[3].contains("First payload"))
    }

    @Test("WALInspector exports CSV in forward order when reverseOrder is false")
    func testCSVExportForwardOrder() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .binary, syncPolicy: .always)
        try await writer.open()

        _ = try await writer.append(payload: Data("Alpha".utf8))
        _ = try await writer.append(payload: Data("Beta".utf8))
        try await writer.close()

        let inspector = WALInspector(path: path, format: .binary)
        let csv = try inspector.exportCSV(reverseOrder: false)

        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines[1].hasPrefix("1,"))
        #expect(lines[2].hasPrefix("2,"))
    }

    @Test("WALInspector properly escapes CSV special characters (quotes, commas, newlines) per RFC 4180")
    func testCSVExportRFC4180Escaping() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .binary, syncPolicy: .always)
        try await writer.open()

        // Complex payload with quotes, commas, and embedded newlines
        let complexText = "Alice, Bob & Charlie said \"Hello\""
        _ = try await writer.append(payload: Data(complexText.utf8))
        try await writer.close()

        let inspector = WALInspector(path: path, format: .binary)
        let csv = try inspector.exportCSV()

        // RFC 4180: The field must be enclosed in quotes because it contains commas and quotes.
        // Embedded quotes must be escaped with double quotes: ""Hello""
        #expect(csv.contains(#""Alice, Bob & Charlie said ""Hello""""#))
    }
    @Test("SegmentedWALReader exports entire multi-segment directory to unified CSV in reverse time order")
    func testSegmentedDirectoryCSVExport() async throws {
        let dir = try createTempDir()
        defer { cleanup(path: dir) }

        let writer = SegmentedWALWriter(
            directoryPath: dir,
            format: .binary,
            syncPolicy: .always,
            maxSegmentBytes: 150, // Force multiple segments
            retentionPolicy: .unlimited
        )
        try await writer.open()

        for i in 1...6 {
            _ = try await writer.append(payload: Data("Segment Payload #\(i)".utf8))
        }
        try await writer.close()

        let reader = SegmentedWALReader(directoryPath: dir)
        let segments = try reader.listSegments()
        #expect(segments.count >= 2)

        let csv = try reader.exportCSV(reverseOrder: true)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }

        #expect(lines.count == 7) // 1 header + 6 records
        #expect(lines[0].hasPrefix("sequence_number,"))
        #expect(lines[1].hasPrefix("6,")) // Newest first
        #expect(lines[6].hasPrefix("1,")) // Oldest last
    }
}
