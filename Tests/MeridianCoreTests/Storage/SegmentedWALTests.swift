//
//  SegmentedWALTests.swift
//  MeridianCore
//

import Foundation
import Testing
@testable import MeridianCore

@Suite("Segmented Write-Ahead Log (WAL) & Retention Policy Tests")
struct SegmentedWALTests {
    private func createTempDir() throws -> String {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("segmented_wal_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir.path
    }

    private func cleanup(dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }

    @Test("SegmentedWALWriter rotates automatically when segment byte threshold is reached")
    func testSegmentRotationOnSize() async throws {
        let dir = try createTempDir()
        defer { cleanup(dir: dir) }

        // Max 200 bytes per segment to force rapid rotation
        let writer = SegmentedWALWriter(
            directoryPath: dir,
            format: .binary,
            syncPolicy: .always,
            maxSegmentBytes: 200,
            retentionPolicy: .unlimited
        )
        try await writer.open()

        let payload = Data(repeating: 0x42, count: 60) // framed: 32 header + 60 = 92 bytes per record

        let r1 = try await writer.append(payload: payload)
        let r2 = try await writer.append(payload: payload)
        #expect(await writer.currentSegmentIndex == 1)

        // Third record exceeds 200 bytes threshold -> forces rotation to segment 2
        let r3 = try await writer.append(payload: payload)
        #expect(await writer.currentSegmentIndex == 2)
        #expect(r3.sequenceNumber == 3)

        // Fourth record exceeds 200 bytes in segment 2 -> forces rotation to segment 3
        let r4 = try await writer.append(payload: payload)
        let r5 = try await writer.append(payload: payload)
        #expect(await writer.currentSegmentIndex == 3)
        #expect(r5.sequenceNumber == 5)

        try await writer.close()

        // Read all records across all segments using SegmentedWALReader
        let reader = SegmentedWALReader(directoryPath: dir)
        let segments = try reader.listSegments()
        #expect(segments.count == 3)
        #expect(segments[0].index == 1)
        #expect(segments[1].index == 2)
        #expect(segments[2].index == 3)

        let allRecords = try reader.readAll()
        #expect(allRecords.count == 5)
        #expect(allRecords.map(\.sequenceNumber) == [1, 2, 3, 4, 5])
        #expect(allRecords.allSatisfy { $0.payload == payload })
    }

    @Test("SegmentedWALWriter enforces keepLastSegments retention policy by unlinking oldest files")
    func testRetentionPolicyKeepSegments() async throws {
        let dir = try createTempDir()
        defer { cleanup(dir: dir) }

        // Retain only the last 2 completed segments + 1 active
        let writer = SegmentedWALWriter(
            directoryPath: dir,
            format: .binary,
            syncPolicy: .always,
            maxSegmentBytes: 150,
            retentionPolicy: .keepLastSegments(count: 2)
        )
        try await writer.open()

        let payload = Data("Transaction Record Payload".utf8)

        // Segment 1
        _ = try await writer.append(payload: payload)
        _ = try await writer.append(payload: payload)
        try await writer.rotate() // Segment 2
        _ = try await writer.append(payload: payload)
        try await writer.rotate() // Segment 3
        _ = try await writer.append(payload: payload)
        try await writer.rotate() // Segment 4
        _ = try await writer.append(payload: payload)

        try await writer.close()

        let reader = SegmentedWALReader(directoryPath: dir)
        let segments = try reader.listSegments()

        // With retention of 2, oldest segments 1 and 2 should be deleted, leaving segments 3 and 4
        #expect(segments.count <= 2)
        let indices = segments.map(\.index)
        #expect(!indices.contains(1))
        #expect(!indices.contains(2))
        #expect(indices.contains(3) || indices.contains(4))
    }

    @Test("SegmentedWALReader filters records by sequence number and timestamp")
    func testSegmentedReaderFiltering() async throws {
        let dir = try createTempDir()
        defer { cleanup(dir: dir) }

        let writer = SegmentedWALWriter(
            directoryPath: dir,
            format: .binary,
            syncPolicy: .always,
            maxSegmentBytes: 120,
            retentionPolicy: .unlimited
        )
        try await writer.open()

        let t0 = Date(timeIntervalSince1970: 1700000000)
        for i in 1...6 {
            let p = Data("Record #\(i)".utf8)
            let ts = t0.addingTimeInterval(Double(i * 10))
            _ = try await writer.append(payload: p, timestamp: ts)
        }
        try await writer.close()

        let reader = SegmentedWALReader(directoryPath: dir)
        let fromSeq = try reader.readRecords(fromSequence: 4)
        #expect(fromSeq.map(\.sequenceNumber) == [4, 5, 6])

        let fromTime = try reader.readRecords(fromTimestamp: t0.addingTimeInterval(35))
        #expect(fromTime.map(\.sequenceNumber) == [4, 5, 6])
    }

    @Test("SegmentedWALWriter enforces keepTotalBytes retention policy")
    func testRetentionPolicyKeepTotalBytes() async throws {
        let dir = try createTempDir()
        defer { cleanup(dir: dir) }

        // Retain segments whose total size <= 150 bytes (fits only 1 completed ~82B segment + active)
        let writer = SegmentedWALWriter(
            directoryPath: dir,
            format: .binary,
            syncPolicy: .always,
            maxSegmentBytes: 100,
            retentionPolicy: .keepTotalBytes(bytes: 150)
        )
        try await writer.open()

        let payload = Data(repeating: 0x5A, count: 50)

        // Write 4 segments
        for _ in 1...4 {
            _ = try await writer.append(payload: payload)
            try await writer.rotate()
        }
        try await writer.close()

        let reader = SegmentedWALReader(directoryPath: dir)
        let segments = try reader.listSegments()
        let totalBytes = segments.reduce(0) { $0 + $1.byteSize }

        #expect(totalBytes <= 150)
        #expect(segments.count <= 2)
        let indices = segments.map(\.index)
        #expect(!indices.contains(1))
        #expect(!indices.contains(2))
    }

    @Test("WALRetentionPolicy evaluatePruning handles time window and composite rules")
    func testRetentionPolicyPruningDirect() {
        let now = Date(timeIntervalSince1970: 1700001000)
        let seg1 = WALSegmentMetadata(index: 1, path: "/p/wal-000001.wal", byteSize: 500, endTime: now.addingTimeInterval(-3600))
        let seg2 = WALSegmentMetadata(index: 2, path: "/p/wal-000002.wal", byteSize: 500, endTime: now.addingTimeInterval(-1800))
        let seg3 = WALSegmentMetadata(index: 3, path: "/p/wal-000003.wal", byteSize: 500, endTime: now.addingTimeInterval(-300))
        let seg4 = WALSegmentMetadata(index: 4, path: "/p/wal-000004.wal", byteSize: 500, endTime: now)

        let segments = [seg1, seg2, seg3, seg4]

        // Time window 1000 seconds -> seg1 (-3600s) and seg2 (-1800s) are expired
        let timePolicy = WALRetentionPolicy.keepTimeWindow(seconds: 1000)
        let prunedByTime = timePolicy.evaluatePruning(segments: segments, now: now)
        #expect(prunedByTime == [seg1.path, seg2.path])

        // Composite policy: keepLastSegments(2) AND keepTimeWindow(1000)
        let compositePolicy = WALRetentionPolicy.composite([
            .keepLastSegments(count: 2),
            .keepTimeWindow(seconds: 1000)
        ])
        let prunedComposite = compositePolicy.evaluatePruning(segments: segments, now: now)
        #expect(prunedComposite.contains(seg1.path))
        #expect(prunedComposite.contains(seg2.path))
        #expect(!prunedComposite.contains(seg3.path))
        #expect(!prunedComposite.contains(seg4.path))
    }
}
