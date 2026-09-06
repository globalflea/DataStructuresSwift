//
//  SegmentedWALWriter.swift
//  MeridianCore
//

import Foundation

/// Swift 6 actor-isolated segmented Write-Ahead Log writer.
///
/// Divides a continuous stream of append-only records across generation-indexed segment files
/// (`wal-%06d.wal`), rolling to new files upon size or duration thresholds, and pruning old
/// segments atomically per `WALRetentionPolicy`.
public actor SegmentedWALWriter {
    /// Directory containing the segmented WAL files.
    public let directoryPath: String

    /// Serialization wire format (`.binary` or `.json`).
    public let format: WALFormat

    /// Durability synchronization policy (`.always`, `.everySecond`, `.no`).
    public let syncPolicy: WALSyncPolicy

    /// 4-byte magic identifier distinguishing this WAL stream.
    public let magic: UInt32

    /// Maximum byte size per individual segment file before automatic rotation.
    public let maxSegmentBytes: UInt64

    /// Maximum lifespan of an active segment before automatic rotation.
    public let maxSegmentDuration: TimeInterval?

    /// Active retention policy governing pruning of older completed segments.
    public let retentionPolicy: WALRetentionPolicy

    /// In-memory buffer capacity allocated per active segment writer.
    public let bufferCapacity: Int

    /// Current active segment index (1-based).
    public private(set) var currentSegmentIndex: Int

    /// Active segment writer.
    private var currentWriter: WALWriter?

    /// Timestamp when current segment was opened.
    private var currentSegmentStartTime: Date?

    /// Global monotonically increasing sequence number counter across all segments.
    public private(set) var sequenceNumber: UInt64

    /// Indicates whether the segmented writer is currently open and accepting appends.
    public private(set) var isOpen: Bool

    /// Initializes a `SegmentedWALWriter`.
    public init(
        directoryPath: String,
        format: WALFormat = .binary,
        syncPolicy: WALSyncPolicy = .everySecond,
        magic: UInt32 = defaultWALBinaryMagic,
        maxSegmentBytes: UInt64 = 64 * 1024 * 1024, // 64 MB default
        maxSegmentDuration: TimeInterval? = nil,
        retentionPolicy: WALRetentionPolicy = .keepLastSegments(count: 10),
        bufferCapacity: Int = 64 * 1024,
        initialSequenceNumber: UInt64 = 0
    ) {
        self.directoryPath = directoryPath
        self.format = format
        self.syncPolicy = syncPolicy
        self.magic = magic
        self.maxSegmentBytes = maxSegmentBytes
        self.maxSegmentDuration = maxSegmentDuration
        self.retentionPolicy = retentionPolicy
        self.bufferCapacity = bufferCapacity
        self.sequenceNumber = initialSequenceNumber
        self.currentSegmentIndex = 1
        self.currentWriter = nil
        self.currentSegmentStartTime = nil
        self.isOpen = false
    }

    deinit {
        // Best effort actor deinit cleanup
    }

    /// Opens the segmented writer, discovering existing segments or initializing segment 1.
    public func open() async throws {
        guard !isOpen else { return }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryPath) {
            try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
        }

        let existingSegments = try discoverSegments()
        if let latest = existingSegments.last {
            // Recover global sequence number from latest segment
            let inspector = WALInspector(path: latest.path, format: format, expectedMagic: magic)
            let summary = try inspector.summary()
            self.sequenceNumber = (summary.lastSequenceNumber ?? 0)

            if latest.byteSize < maxSegmentBytes {
                self.currentSegmentIndex = latest.index
                let writer = WALWriter(
                    path: latest.path,
                    format: format,
                    syncPolicy: syncPolicy,
                    magic: magic,
                    bufferCapacity: bufferCapacity,
                    initialSequenceNumber: sequenceNumber
                )
                try await writer.open()
                self.currentWriter = writer
                self.currentSegmentStartTime = summary.startTime ?? Date()
            } else {
                // Latest segment is full; rotate to next segment
                self.currentSegmentIndex = latest.index + 1
                try await openSegment(index: currentSegmentIndex)
            }
        } else {
            // First time initialization
            self.currentSegmentIndex = 1
            try await openSegment(index: currentSegmentIndex)
        }

        self.isOpen = true
        try pruneExpiredSegments()
    }

    /// Appends a payload record into the active segment, triggering rotation if thresholds are exceeded.
    @discardableResult
    public func append(payload: Data, timestamp: Date = Date()) async throws -> WALRecord {
        guard isOpen, let writer = currentWriter else {
            throw WALError.writerClosed
        }

        // Check rotation conditions
        let currentSize = await writer.currentOffset()
        let hasDurationExpired: Bool = {
            guard let maxDur = maxSegmentDuration, let start = currentSegmentStartTime else { return false }
            return timestamp.timeIntervalSince(start) >= maxDur
        }()

        let projectedSize = currentSize + UInt64(walHeaderSize + payload.count)
        let wouldExceed = (projectedSize > maxSegmentBytes) && currentSize > 0

        if wouldExceed || (currentSize >= maxSegmentBytes && currentSize > 0) || hasDurationExpired {
            try await rotate(timestamp: timestamp)
        }

        guard let activeWriter = currentWriter else {
            throw WALError.writerClosed
        }

        let record = try await activeWriter.append(payload: payload, timestamp: timestamp)
        self.sequenceNumber = record.sequenceNumber
        return record
    }

    /// Explicitly forces a segment roll, closing the current segment and opening a new one.
    public func rotate(timestamp: Date = Date()) async throws {
        guard isOpen, let writer = currentWriter else {
            throw WALError.writerClosed
        }

        try await writer.close()
        currentSegmentIndex += 1
        try await openSegment(index: currentSegmentIndex)
        try pruneExpiredSegments(now: timestamp)
    }

    /// Flushes all pending write buffers in the active segment.
    public func flush() async throws {
        guard isOpen, let writer = currentWriter else {
            throw WALError.writerClosed
        }
        try await writer.flush()
    }

    /// Closes the active segment writer.
    public func close() async throws {
        guard isOpen else { return }
        try await currentWriter?.close()
        currentWriter = nil
        isOpen = false
    }

    /// Discovers all valid segment files in the directory sorted in ascending index order.
    public func listSegments() throws -> [WALSegmentMetadata] {
        try discoverSegments()
    }

    // MARK: - Private Helpers

    private func openSegment(index: Int) async throws {
        let segmentFileName = String(format: "wal-%06d.wal", index)
        let segmentPath = URL(fileURLWithPath: directoryPath).appendingPathComponent(segmentFileName).path

        let writer = WALWriter(
            path: segmentPath,
            format: format,
            syncPolicy: syncPolicy,
            magic: magic,
            bufferCapacity: bufferCapacity,
            initialSequenceNumber: sequenceNumber
        )
        try await writer.open()
        self.currentWriter = writer
        self.currentSegmentStartTime = Date()
    }

    private func discoverSegments() throws -> [WALSegmentMetadata] {
        let fileManager = FileManager.default
        let items = try fileManager.contentsOfDirectory(atPath: directoryPath)

        var segments: [WALSegmentMetadata] = []
        for file in items {
            guard file.hasPrefix("wal-") && file.hasSuffix(".wal") else { continue }
            let indexPart = file.dropFirst(4).dropLast(4)
            guard let index = Int(indexPart) else { continue }

            let fullPath = URL(fileURLWithPath: directoryPath).appendingPathComponent(file).path
            let attrs = try fileManager.attributesOfItem(atPath: fullPath)
            let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0

            segments.append(WALSegmentMetadata(index: index, path: fullPath, byteSize: size))
        }

        return segments.sorted { $0.index < $1.index }
    }

    private func pruneExpiredSegments(now: Date = Date()) throws {
        guard retentionPolicy != .unlimited else { return }
        let segments = try discoverSegments()
        guard segments.count > 1 else { return }

        let pathsToDelete = retentionPolicy.evaluatePruning(segments: segments, now: now)
        let fileManager = FileManager.default
        let activeSegmentFileName = String(format: "wal-%06d.wal", currentSegmentIndex)

        for path in pathsToDelete {
            // Guarantee that the currently active segment is never unlinked
            guard !path.hasSuffix(activeSegmentFileName) else { continue }
            try? fileManager.removeItem(atPath: path)
        }
    }
}
