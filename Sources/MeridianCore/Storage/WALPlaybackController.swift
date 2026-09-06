//
//  WALPlaybackController.swift
//  MeridianCore
//

import Foundation

/// Swift 6 actor-isolated timeline playback controller for Write-Ahead Log history.
///
/// Features:
/// - Virtual timeline pacing with configurable speed multipliers (`0.5x`, `1.0x`, `2.0x`, `10.0x`, or unthrottled `0.0x`).
/// - Standard VCR transport controls: `play`, `pause`, `resume`, `stop`, `step`, and `seek`.
/// - Reactive streaming via native Swift `AsyncStream<WALRecord>` and listener callbacks.
public actor WALPlaybackController {
    /// Operational state of the playback timeline.
    public enum PlaybackState: Sendable, Equatable {
        case idle
        case playing(speedMultiplier: Double)
        case paused
        case stopped
        case completed
    }

    /// Complete sorted record journal available for playback.
    private var records: [WALRecord]

    /// Sparse B-Tree index for $O(\log N)$ random-access seeking.
    private var index: WALIndex

    /// Current timeline record cursor (0-indexed).
    public private(set) var cursor: Int

    /// Current playback state.
    public private(set) var state: PlaybackState

    /// Active playback speed multiplier (1.0 = real-time, 2.0 = double speed, 0.0 = unthrottled burst).
    public private(set) var speedMultiplier: Double

    /// Background task driving the virtual clock playback loop.
    private var playbackTask: Task<Void, Never>?

    /// Dedicated listener callback invoked on every played record.
    private var recordHandler: (@Sendable (WALRecord) async -> Void)?

    /// AsyncStream continuation emitting replayed records.
    private var streamContinuation: AsyncStream<WALRecord>.Continuation?

    /// Public asynchronous stream yielding replayed records.
    public let recordStream: AsyncStream<WALRecord>

    /// Initializes a playback controller from pre-loaded records.
    public init(records: [WALRecord], initialSpeed: Double = 1.0) {
        let sorted = records.sorted { $0.sequenceNumber < $1.sequenceNumber }
        self.records = sorted
        self.cursor = 0
        self.state = .idle
        self.speedMultiplier = max(0.0, initialSpeed)
        self.recordHandler = nil
        self.playbackTask = nil

        var idx = WALIndex()
        idx.index(records: sorted, segmentIndex: 1, segmentPath: "")
        self.index = idx

        var continuation: AsyncStream<WALRecord>.Continuation?
        self.recordStream = AsyncStream<WALRecord> { cont in
            continuation = cont
        }
        self.streamContinuation = continuation
    }

    /// Initializes a playback controller loading records from a single WAL file.
    public init(filePath: String, format: WALFormat = .binary, expectedMagic: UInt32? = defaultWALBinaryMagic, initialSpeed: Double = 1.0) throws {
        let reader = WALReader(path: filePath, format: format, expectedMagic: expectedMagic)
        let loaded = try reader.readAll()
        self.init(records: loaded, initialSpeed: initialSpeed)
    }

    /// Initializes a playback controller loading records across a segmented directory.
    public init(segmentedDirectoryPath: String, format: WALFormat = .binary, expectedMagic: UInt32? = defaultWALBinaryMagic, initialSpeed: Double = 1.0) throws {
        let reader = SegmentedWALReader(directoryPath: segmentedDirectoryPath, format: format, expectedMagic: expectedMagic)
        let loaded = try reader.readAll()
        self.init(records: loaded, initialSpeed: initialSpeed)
    }

    deinit {
        streamContinuation?.finish()
        playbackTask?.cancel()
    }

    /// Registers a custom subscriber invoked as records are replayed.
    public func onRecord(_ handler: @escaping @Sendable (WALRecord) async -> Void) {
        self.recordHandler = handler
    }

    /// Starts or resumes playback at the specified speed multiplier.
    public func play(speedMultiplier: Double? = nil) {
        if let speed = speedMultiplier {
            self.speedMultiplier = max(0.0, speed)
        }
        playbackTask?.cancel()
        state = .playing(speedMultiplier: self.speedMultiplier)

        let speed = self.speedMultiplier
        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop(speed: speed)
        }
    }

    /// Pauses playback at the current record cursor.
    public func pause() {
        guard case .playing = state else { return }
        playbackTask?.cancel()
        playbackTask = nil
        state = .paused
    }

    /// Resumes playback from the current paused position.
    public func resume() {
        if state == .paused {
            play()
        }
    }

    /// Stops playback, terminating tasks and rewinding the cursor to the beginning.
    public func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        cursor = 0
        state = .stopped
    }

    /// Adjusts the playback speed multiplier dynamically during playback.
    public func setSpeed(_ multiplier: Double) {
        self.speedMultiplier = max(0.0, multiplier)
        if case .playing = state {
            play(speedMultiplier: self.speedMultiplier)
        }
    }

    /// Steps forward by `count` records immediately without timeline delays and pauses.
    @discardableResult
    public func step(count: Int = 1) async -> [WALRecord] {
        playbackTask?.cancel()
        playbackTask = nil

        var stepped: [WALRecord] = []
        let target = min(cursor + count, records.count)

        while cursor < target {
            let rec = records[cursor]
            stepped.append(rec)
            streamContinuation?.yield(rec)
            await recordHandler?(rec)
            cursor += 1
        }

        if cursor >= records.count {
            state = .completed
        } else {
            state = .paused
        }

        return stepped
    }

    /// Jumps the timeline cursor to the record nearest to `timestamp`.
    public func seek(to timestamp: Date) {
        let targetMillis = Int64(timestamp.timeIntervalSince1970 * 1000)

        // Binary search for closest record
        var low = 0
        var high = records.count - 1
        var bestIndex = 0

        while low <= high {
            let mid = low + (high - low) / 2
            let recMillis = records[mid].timestampMillis

            if recMillis <= targetMillis {
                bestIndex = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        cursor = bestIndex
        if case .playing = state {
            play()
        }
    }

    /// Jumps the timeline cursor to the record with sequence number `sequenceNumber`.
    public func seek(toSequence sequenceNumber: UInt64) {
        var low = 0
        var high = records.count - 1
        var bestIndex = 0

        while low <= high {
            let mid = low + (high - low) / 2
            let seq = records[mid].sequenceNumber

            if seq <= sequenceNumber {
                bestIndex = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        cursor = bestIndex
        if case .playing = state {
            play()
        }
    }

    /// Returns timeline progress diagnostics: `(cursor, totalRecords, currentRecord)`.
    public func progress() -> (cursor: Int, total: Int, currentRecord: WALRecord?) {
        let current = cursor < records.count ? records[cursor] : nil
        return (cursor, records.count, current)
    }

    // MARK: - Playback Loop

    private func runPlaybackLoop(speed: Double) async {
        while cursor < records.count && !Task.isCancelled {
            let current = records[cursor]

            // Calculate timestamp delta from previous record
            if cursor > 0 && speed > 0 {
                let prev = records[cursor - 1]
                let deltaMillis = max(0, current.timestampMillis - prev.timestampMillis)
                let sleepSeconds = (Double(deltaMillis) / 1000.0) / speed

                // Sleep if greater than 1 millisecond
                if sleepSeconds >= 0.001 {
                    let nanos = UInt64(sleepSeconds * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                }
            }

            if Task.isCancelled { break }

            // Dispatch record
            streamContinuation?.yield(current)
            await recordHandler?(current)

            cursor += 1
        }

        if cursor >= records.count && !Task.isCancelled {
            state = .completed
        }
    }
}
