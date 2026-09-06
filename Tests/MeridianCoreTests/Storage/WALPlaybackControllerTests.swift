//
//  WALPlaybackControllerTests.swift
//  MeridianCore
//

import Foundation
import Testing
@testable import MeridianCore

@Suite("WAL History Playback Controller & Sparse Index Tests")
struct WALPlaybackControllerTests {

    private func generateSampleRecords(count: Int, startEpoch: Double = 1700000000) -> [WALRecord] {
        var records: [WALRecord] = []
        for i in 1...count {
            let ts = Date(timeIntervalSince1970: startEpoch + Double(i))
            let p = Data("Telemetry Payload #\(i)".utf8)
            records.append(WALRecord(
                sequenceNumber: UInt64(i),
                timestamp: ts,
                payload: p,
                offset: UInt64(i * 100),
                byteSize: 100,
                crc64: 0x12345678,
                magic: defaultWALBinaryMagic
            ))
        }
        return records
    }

    @Test("WALIndex performs O(log N) sparse checkpoint lookups by time and sequence")
    func testWALIndexLookups() {
        let records = generateSampleRecords(count: 500)
        var index = WALIndex()
        index.index(records: records, segmentIndex: 1, segmentPath: "/tmp/wal-000001.wal", interval: 50)

        // Checkpoint count: 1st (seq 1), last (seq 500), and multiples of 50
        #expect(index.count > 0)

        // Seek sequence 125 -> nearest checkpoint <= 125 is seq 100 or 50
        let ptrSeq = index.findNearest(sequenceNumber: 125)
        #expect(ptrSeq != nil)
        #expect(ptrSeq!.sequenceNumber <= 125)

        // Seek time
        let targetTime = Date(timeIntervalSince1970: 1700000000 + 250)
        let ptrTime = index.findNearest(timestamp: targetTime)
        #expect(ptrTime != nil)
        #expect(ptrTime!.timestamp <= targetTime)
    }

    @Test("WALPlaybackController step mode advances frame-by-frame synchronously")
    func testPlaybackStepMode() async {
        let records = generateSampleRecords(count: 10)
        let player = WALPlaybackController(records: records)

        let step1 = await player.step(count: 1)
        #expect(step1.count == 1)
        #expect(step1.first?.sequenceNumber == 1)
        let p1 = await player.progress()
        #expect(p1.cursor == 1)
        #expect(await player.state == .paused)

        let step3 = await player.step(count: 3)
        #expect(step3.count == 3)
        #expect(step3.map(\.sequenceNumber) == [2, 3, 4])
        let p2 = await player.progress()
        #expect(p2.cursor == 4)

        // Step through remaining records
        _ = await player.step(count: 10)
        let p3 = await player.progress()
        #expect(p3.cursor == 10)
        #expect(await player.state == .completed)
    }

    @Test("WALPlaybackController seek jumps timeline cursor to target sequence and timestamp")
    func testPlaybackSeekControls() async {
        let records = generateSampleRecords(count: 50)
        let player = WALPlaybackController(records: records)

        await player.seek(toSequence: 25)
        var p = await player.progress()
        #expect(p.cursor == 24) // 0-indexed cursor for sequence 25
        #expect(p.currentRecord?.sequenceNumber == 25)

        let targetTime = Date(timeIntervalSince1970: 1700000000 + 10)
        await player.seek(to: targetTime)
        p = await player.progress()
        #expect(p.currentRecord?.sequenceNumber == 10)
    }

    @Test("WALPlaybackController plays and yields records through listener callback at high speed")
    func testPlaybackStreamingExecution() async throws {
        let records = generateSampleRecords(count: 20)
        let player = WALPlaybackController(records: records, initialSpeed: 0.0) // unthrottled burst

        final class ReceivedBox: @unchecked Sendable {
            var items: [WALRecord] = []
            let lock = NSLock()
            func add(_ r: WALRecord) {
                lock.lock()
                defer { lock.unlock() }
                items.append(r)
            }
            func count() -> Int {
                lock.lock()
                defer { lock.unlock() }
                return items.count
            }
        }

        let box = ReceivedBox()
        await player.onRecord { rec in
            box.add(rec)
        }

        await player.play(speedMultiplier: 0.0)

        // Wait for unthrottled completion
        for _ in 0..<50 {
            if box.count() == 20 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(box.count() == 20)
        let state = await player.state
        #expect(state == .completed)
    }

    @Test("WALPlaybackController pause and resume state controls")
    func testPlaybackPauseAndResume() async {
        let records = generateSampleRecords(count: 10)
        let player = WALPlaybackController(records: records, initialSpeed: 10.0)

        await player.play()
        #expect(await player.state == .playing(speedMultiplier: 10.0))

        await player.pause()
        #expect(await player.state == .paused)

        await player.resume()
        #expect(await player.state == .playing(speedMultiplier: 10.0))

        await player.stop()
        #expect(await player.state == .stopped)
        let p = await player.progress()
        #expect(p.cursor == 0)
    }

    @Test("WALPlaybackController dynamic speed adjustments and stream consumption")
    func testPlaybackDynamicSpeedAndStream() async throws {
        let records = generateSampleRecords(count: 8)
        let player = WALPlaybackController(records: records, initialSpeed: 1.0)

        #expect(await player.speedMultiplier == 1.0)
        await player.setSpeed(5.0)
        #expect(await player.speedMultiplier == 5.0)

        // Read records via step and verify stream
        let stepped = await player.step(count: 3)
        #expect(stepped.count == 3)
        #expect(stepped.map(\.sequenceNumber) == [1, 2, 3])

        let prog = await player.progress()
        #expect(prog.cursor == 3)
        #expect(prog.total == 8)
        #expect(prog.currentRecord?.sequenceNumber == 4)
    }

    @Test("WALPlaybackController initializes directly from file path and segmented directory")
    func testPlaybackInitFromPaths() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("wal_player_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let singlePath = tempDir.appendingPathComponent("single.wal").path
        let writer = WALWriter(path: singlePath, format: .binary, syncPolicy: .always)
        try await writer.open()
        _ = try await writer.append(payload: Data("File Payload 1".utf8))
        _ = try await writer.append(payload: Data("File Payload 2".utf8))
        try await writer.close()

        let filePlayer = try WALPlaybackController(filePath: singlePath)
        let fileProg = await filePlayer.progress()
        #expect(fileProg.total == 2)

        let segDir = tempDir.appendingPathComponent("segmented").path
        let segWriter = SegmentedWALWriter(directoryPath: segDir, maxSegmentBytes: 150)
        try await segWriter.open()
        _ = try await segWriter.append(payload: Data("Seg Payload 1".utf8))
        _ = try await segWriter.append(payload: Data("Seg Payload 2".utf8))
        try await segWriter.close()

        let dirPlayer = try WALPlaybackController(segmentedDirectoryPath: segDir)
        let dirProg = await dirPlayer.progress()
        #expect(dirProg.total == 2)
    }
}
