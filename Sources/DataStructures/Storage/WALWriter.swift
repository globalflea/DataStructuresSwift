//
//  WALWriter.swift
//  DataStructuresSwift
//

import Foundation

/// Swift 6 actor-isolated append-only Write-Ahead Log writer.
///
/// Provides framed binary or JSON serialization, 64-bit CRC-64 checksumming,
/// memory write buffering, and background `fsync` scheduling per `WALSyncPolicy`.
public actor WALWriter {
    /// Filesystem path of the target WAL file.
    public let path: String

    /// Serialization wire format (`.binary` or `.json`).
    public let format: WALFormat

    /// Durability synchronization policy (`.always`, `.everySecond`, `.no`).
    public let syncPolicy: WALSyncPolicy

    /// 4-byte magic identifier distinguishing this WAL stream.
    public let magic: UInt32

    /// Maximum in-memory byte capacity before triggering an automatic buffer flush.
    public let bufferCapacity: Int

    /// In-memory write buffer accumulating framed bytes.
    private var buffer: Data

    /// Low-level file handle for sequential appends.
    private var fileHandle: FileHandle?

    /// Monotonically increasing sequence number counter.
    private var sequenceNumber: UInt64

    /// Current file byte offset.
    private var fileOffset: UInt64

    /// Background periodic timer task for `.everySecond` fsync scheduling.
    private var syncTask: Task<Void, Never>?

    /// Indicates whether the writer is active and open for appends.
    public private(set) var isOpen: Bool

    /// Initializes a `WALWriter`.
    public init(
        path: String,
        format: WALFormat = .binary,
        syncPolicy: WALSyncPolicy = .everySecond,
        magic: UInt32 = defaultWALBinaryMagic,
        bufferCapacity: Int = 64 * 1024,
        initialSequenceNumber: UInt64 = 0
    ) {
        self.path = path
        self.format = format
        self.syncPolicy = syncPolicy
        self.magic = magic
        self.bufferCapacity = bufferCapacity
        self.buffer = Data(capacity: bufferCapacity)
        self.sequenceNumber = initialSequenceNumber
        self.fileOffset = 0
        self.fileHandle = nil
        self.syncTask = nil
        self.isOpen = false
    }

    deinit {
        syncTask?.cancel()
        try? fileHandle?.close()
    }

    /// Opens the WAL file for writing and starts background sync timers if configured.
    public func open() throws {
        guard !isOpen else { return }

        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil)
        }

        guard let handle = FileHandle(forUpdatingAtPath: path) else {
            throw WALError.ioError(reason: "Failed to open FileHandle for writing at: \(path)")
        }

        self.fileOffset = try handle.seekToEnd()
        self.fileHandle = handle
        self.isOpen = true

        if syncPolicy == .everySecond {
            startPeriodicSync()
        }
    }

    /// Returns the current monotonic sequence number.
    public func currentSequenceNumber() -> UInt64 {
        sequenceNumber
    }

    /// Returns the current byte offset on disk including buffered writes.
    public func currentOffset() -> UInt64 {
        fileOffset + UInt64(buffer.count)
    }

    /// Appends a raw binary payload to the log.
    @discardableResult
    public func append(payload: Data, timestamp: Date = Date()) throws -> WALRecord {
        guard isOpen, fileHandle != nil else {
            throw WALError.writerClosed
        }

        sequenceNumber += 1
        let recordOffset = fileOffset + UInt64(buffer.count)
        let tsMillis = Int64(timestamp.timeIntervalSince1970 * 1000)

        switch format {
        case .binary:
            let crc = CRC64.checksum(payload)
            let header = WALFrame.encodeHeader(
                magic: magic,
                sequenceNumber: sequenceNumber,
                timestampMillis: tsMillis,
                payloadLength: UInt32(payload.count),
                crc64: crc
            )

            buffer.append(header)
            buffer.append(payload)

            let recordSize = walHeaderSize + payload.count
            let record = WALRecord(
                sequenceNumber: sequenceNumber,
                timestamp: timestamp,
                payload: payload,
                offset: recordOffset,
                byteSize: recordSize,
                crc64: crc,
                magic: magic
            )

            try handleBufferThreshold()
            return record

        case .json:
            var jsonLine = payload
            if jsonLine.last != 0x0A {
                jsonLine.append(0x0A) // Append newline delimiter
            }

            buffer.append(jsonLine)
            let recordSize = jsonLine.count
            let record = WALRecord(
                sequenceNumber: sequenceNumber,
                timestamp: timestamp,
                payload: payload,
                offset: recordOffset,
                byteSize: recordSize,
                crc64: 0,
                magic: magic
            )

            try handleBufferThreshold()
            return record
        }
    }

    /// Forces all in-memory buffered records to the underlying file descriptor.
    public func flush() throws {
        guard isOpen, let handle = fileHandle else {
            throw WALError.writerClosed
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            fileOffset += UInt64(buffer.count)
            buffer.removeAll(keepingCapacity: true)
        }

        if syncPolicy == .always || syncPolicy == .everySecond {
            try handle.synchronize()
        }
    }

    /// Closes the writer, flushing pending buffers and terminating background timers.
    public func close() throws {
        guard isOpen else { return }
        syncTask?.cancel()
        syncTask = nil

        try flush()
        try fileHandle?.close()
        fileHandle = nil
        isOpen = false
    }

    /// Truncates the log file to zero length and resets sequence numbering to `newSequenceNumber`.
    public func truncate(newSequenceNumber: UInt64 = 0) throws {
        guard isOpen, let handle = fileHandle else {
            throw WALError.writerClosed
        }

        buffer.removeAll(keepingCapacity: true)
        try handle.truncate(atOffset: 0)
        try handle.seek(toOffset: 0)
        self.fileOffset = 0
        self.sequenceNumber = newSequenceNumber
        try handle.synchronize()
    }

    private func handleBufferThreshold() throws {
        if buffer.count >= bufferCapacity || syncPolicy == .always {
            try flush()
        }
    }

    private func startPeriodicSync() {
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
                guard let self = self else { break }
                try? await self.flush()
            }
        }
    }
}
