//
//  WALTests.swift
//  DataStructuresSwift
//

import Foundation
import Testing
@testable import MeridianCore

@Suite("Write-Ahead Log (WAL) Storage & Inspector Tests")
struct WALTests {
    private func createTempWALPath(suffix: String = "wal") -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueName = "test_wal_\(UUID().uuidString).\(suffix)"
        return tempDir.appendingPathComponent(uniqueName).path
    }

    private func cleanup(path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("WALWriter and WALReader binary round-trip with CRC-64 validation")
    func testBinaryRoundTrip() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(
            path: path,
            format: .binary,
            syncPolicy: .always,
            magic: defaultWALBinaryMagic
        )
        try await writer.open()

        let payload1 = Data("First transaction mutation".utf8)
        let payload2 = Data("Second transaction mutation".utf8)
        let payload3 = Data("Third transaction mutation".utf8)

        let r1 = try await writer.append(payload: payload1)
        let r2 = try await writer.append(payload: payload2)
        let r3 = try await writer.append(payload: payload3)

        #expect(r1.sequenceNumber == 1)
        #expect(r2.sequenceNumber == 2)
        #expect(r3.sequenceNumber == 3)
        #expect(r1.crc64 == CRC64.checksum(payload1))

        try await writer.close()

        let reader = WALReader(path: path, format: .binary)
        let records = try reader.readAll()

        #expect(records.count == 3)
        #expect(records[0].sequenceNumber == 1)
        #expect(records[0].payload == payload1)
        #expect(records[0].crc64 == CRC64.checksum(payload1))
        #expect(records[1].sequenceNumber == 2)
        #expect(records[1].payload == payload2)
        #expect(records[2].sequenceNumber == 3)
        #expect(records[2].payload == payload3)
    }

    @Test("WALWriter write buffering threshold and explicit flush")
    func testWriteBuffering() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        // Large 64KB buffer with syncPolicy = .no
        let writer = WALWriter(
            path: path,
            format: .binary,
            syncPolicy: .no,
            bufferCapacity: 64 * 1024
        )
        try await writer.open()

        let smallPayload = Data("Small payload".utf8)
        try await writer.append(payload: smallPayload)

        // File size on disk should still be 0 because payload is in memory buffer
        let attrsBefore = try FileManager.default.attributesOfItem(atPath: path)
        let diskSizeBefore = (attrsBefore[.size] as? NSNumber)?.intValue ?? 0
        #expect(diskSizeBefore == 0)

        // Explicit flush
        try await writer.flush()

        let attrsAfter = try FileManager.default.attributesOfItem(atPath: path)
        let diskSizeAfter = (attrsAfter[.size] as? NSNumber)?.intValue ?? 0
        #expect(diskSizeAfter > 0)

        try await writer.close()
    }

    @Test("WALReader rejects corrupted payload with CRC-64 mismatch")
    func testChecksumMismatchDetection() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .binary, syncPolicy: .always)
        try await writer.open()
        let payload = Data("Crucial immutable transaction".utf8)
        try await writer.append(payload: payload)
        try await writer.close()

        // Tamper with file byte in the payload area
        var fileData = try Data(contentsOf: URL(fileURLWithPath: path))
        fileData[fileData.count - 1] ^= 0xFF
        try fileData.write(to: URL(fileURLWithPath: path))

        let reader = WALReader(path: path, format: .binary, allowTruncatedTail: false)
        #expect(throws: WALError.self) {
            try reader.readAll()
        }
    }

    @Test("WALReader recovers from torn trailing write at EOF")
    func testTornWriteRecovery() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .binary, syncPolicy: .always)
        try await writer.open()
        try await writer.append(payload: Data("Record 1".utf8))
        try await writer.append(payload: Data("Record 2".utf8))
        try await writer.close()

        // Append 15 bytes of an incomplete header (torn write mid-crash)
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x57, 0x41, 0x4C, 0x31, 0x00, 0x00, 0x00, 0x03]))
        try handle.close()

        // allowTruncatedTail = true should recover first 2 records and isolate truncated offset
        let reader = WALReader(path: path, format: .binary, allowTruncatedTail: true)
        let (records, truncatedOffset) = try reader.readRecords()

        #expect(records.count == 2)
        #expect(records[0].payload == Data("Record 1".utf8))
        #expect(records[1].payload == Data("Record 2".utf8))
        #expect(truncatedOffset != nil)

        // allowTruncatedTail = false should throw truncatedLog
        let strictReader = WALReader(path: path, format: .binary, allowTruncatedTail: false)
        #expect(throws: WALError.self) {
            try strictReader.readAll()
        }
    }

    @Test("WALInspector generates summary, inspections, and formatted dump")
    func testWALInspector() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .binary, syncPolicy: .always)
        try await writer.open()
        try await writer.append(payload: Data("Mutation Alpha".utf8))
        try await writer.append(payload: Data("Mutation Beta".utf8))
        try await writer.close()

        let inspector = WALInspector(path: path, format: .binary)
        let summary = try inspector.summary()

        #expect(summary.totalRecords == 2)
        #expect(summary.firstSequenceNumber == 1)
        #expect(summary.lastSequenceNumber == 2)
        #expect(!summary.isTruncated)
        #expect(summary.fileSizeBytes > 0)

        let inspections = try inspector.inspect()
        #expect(inspections.count == 2)
        #expect(inspections[0].sequenceNumber == 1)
        #expect(inspections[0].payloadSummary == "Mutation Alpha")

        let dumpText = try inspector.dump(verbose: true)
        #expect(dumpText.contains("Mutation Alpha"))
        #expect(dumpText.contains("Mutation Beta"))
        #expect(dumpText.contains("CRC-64 verified"))
    }

    @Test("WALWriter truncate clears log and resets sequence number")
    func testTruncate() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .binary, syncPolicy: .always)
        try await writer.open()
        try await writer.append(payload: Data("Record To Wipe".utf8))
        #expect(await writer.currentSequenceNumber() == 1)

        try await writer.truncate()
        #expect(await writer.currentSequenceNumber() == 0)
        #expect(await writer.currentOffset() == 0)

        let record = try await writer.append(payload: Data("New Record".utf8))
        #expect(record.sequenceNumber == 1)
        try await writer.close()

        let reader = WALReader(path: path, format: .binary)
        let records = try reader.readAll()
        #expect(records.count == 1)
        #expect(records[0].payload == Data("New Record".utf8))
    }

    @Test("WALFormat JSON lines writing and reading")
    func testJSONFormat() async throws {
        let path = createTempWALPath(suffix: "json.wal")
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .json, syncPolicy: .always)
        try await writer.open()
        try await writer.append(payload: Data("{\"action\":\"set\",\"key\":\"user:1\"}".utf8))
        try await writer.append(payload: Data("{\"action\":\"del\",\"key\":\"user:2\"}".utf8))
        try await writer.close()

        let reader = WALReader(path: path, format: .json)
        let records = try reader.readAll()
        #expect(records.count == 2)
        #expect(String(data: records[0].payload, encoding: .utf8)?.contains("user:1") == true)
        #expect(String(data: records[1].payload, encoding: .utf8)?.contains("user:2") == true)
    }
}

extension WALTests {
    @Test("WALReader repair truncates torn EOF tail cleanly")
    func testRepairTornTail() async throws {
        let path = createTempWALPath()
        defer { cleanup(path: path) }

        let writer = WALWriter(path: path, format: .binary, syncPolicy: .always)
        try await writer.open()
        try await writer.append(payload: Data("Valid 1".utf8))
        try await writer.append(payload: Data("Valid 2".utf8))
        try await writer.close()

        let validSize = try Data(contentsOf: URL(fileURLWithPath: path)).count

        // Append 9 bytes of garbage simulating interrupted power cut write
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0x57, 0x41, 0x4C, 0x31, 0x01, 0x02, 0x03, 0x04, 0x05]))
        try handle.close()

        let reader = WALReader(path: path, format: .binary)
        let (validCount, truncatedBytes) = try reader.repair()

        #expect(validCount == 2)
        #expect(truncatedBytes == 9)

        let repairedSize = try Data(contentsOf: URL(fileURLWithPath: path)).count
        #expect(repairedSize == validSize)
    }
}
