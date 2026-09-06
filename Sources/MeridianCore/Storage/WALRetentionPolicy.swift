//
//  WALRetentionPolicy.swift
//  MeridianCore
//

import Foundation

/// Retention policy governing the lifecycle and pruning of archived Write-Ahead Log segments.
///
/// Prevents disk exhaustion in continuous high-throughput systems by discarding or archiving
/// completed historical segments once configured retention thresholds are reached.
public enum WALRetentionPolicy: Sendable, Equatable {
    /// Retains at most `count` active segment files (the newest `count` segments).
    case keepLastSegments(count: Int)

    /// Retains segments whose cumulative file size does not exceed `bytes`.
    case keepTotalBytes(bytes: UInt64)

    /// Retains segments containing records written within the last `seconds` interval.
    case keepTimeWindow(seconds: TimeInterval)

    /// Evaluates multiple retention policies concurrently; any segment failing any policy is pruned.
    case composite([WALRetentionPolicy])

    /// Preserves all historical segments without automated pruning.
    case unlimited

    /// Evaluates whether a set of discovered segment files should be pruned, returning the file paths to delete.
    ///
    /// - Parameter segments: Array of segment metadata sorted in ascending chronological order (oldest first).
    /// - Parameter now: Current reference date for time-window calculations (default: `Date()`).
    /// - Returns: Array of segment file paths that exceed the retention policy and should be unlinked.
    public func evaluatePruning(segments: [WALSegmentMetadata], now: Date = Date()) -> [String] {
        guard !segments.isEmpty else { return [] }

        switch self {
        case .unlimited:
            return []

        case .keepLastSegments(let count):
            guard count > 0, segments.count > count else { return [] }
            let excess = segments.count - count
            return segments.prefix(excess).map(\.path)

        case .keepTotalBytes(let maxBytes):
            var toDelete: [String] = []
            var currentBytes = segments.reduce(UInt64(0)) { $0 + $1.byteSize }

            // Prune from oldest until within budget, always keeping at least the latest segment
            for seg in segments.dropLast() {
                if currentBytes <= maxBytes { break }
                toDelete.append(seg.path)
                currentBytes -= min(currentBytes, seg.byteSize)
            }
            return toDelete

        case .keepTimeWindow(let windowSeconds):
            let cutoff = now.addingTimeInterval(-windowSeconds)
            var toDelete: [String] = []

            // Prune oldest segments whose endTime is older than cutoff, keeping at least the active segment
            for seg in segments.dropLast() {
                if let endTime = seg.endTime, endTime < cutoff {
                    toDelete.append(seg.path)
                }
            }
            return toDelete

        case .composite(let policies):
            var allToDelete = Set<String>()
            for policy in policies {
                let paths = policy.evaluatePruning(segments: segments, now: now)
                allToDelete.formUnion(paths)
            }
            // Sort by segment index order
            return segments.filter { allToDelete.contains($0.path) }.map(\.path)
        }
    }
}

/// Metadata descriptor for a single WAL segment file on disk.
public struct WALSegmentMetadata: Sendable, Equatable {
    /// 1-based monotonically increasing segment index.
    public let index: Int

    /// Absolute filesystem path of this segment file.
    public let path: String

    /// Physical file size on disk in bytes.
    public let byteSize: UInt64

    /// Earliest record timestamp in this segment, if known.
    public let startTime: Date?

    /// Latest record timestamp in this segment, if known.
    public let endTime: Date?

    /// First sequence number recorded in this segment, if known.
    public let firstSequenceNumber: UInt64?

    /// Last sequence number recorded in this segment, if known.
    public let lastSequenceNumber: UInt64?

    public init(
        index: Int,
        path: String,
        byteSize: UInt64,
        startTime: Date? = nil,
        endTime: Date? = nil,
        firstSequenceNumber: UInt64? = nil,
        lastSequenceNumber: UInt64? = nil
    ) {
        self.index = index
        self.path = path
        self.byteSize = byteSize
        self.startTime = startTime
        self.endTime = endTime
        self.firstSequenceNumber = firstSequenceNumber
        self.lastSequenceNumber = lastSequenceNumber
    }
}
