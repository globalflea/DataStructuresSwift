//
//  WALSyncPolicy.swift
//  DataStructuresSwift
//

import Foundation

/// Durability synchronization policies for the Write-Ahead Log (WAL).
///
/// Controls when buffered data is forced to physical disk via the POSIX `fsync()` system call.
public enum WALSyncPolicy: String, Sendable, Equatable, Hashable, Codable, CaseIterable, CustomStringConvertible {
    /// Forces an `fsync()` to persistent storage after every mutating operation.
    case always = "always"

    /// Flushes write buffers and forces an `fsync()` asynchronously every 1.0 second.
    case everySecond = "everysec"

    /// Relies on the host operating system's virtual memory kernel page cache write-back daemon.
    case no = "no"

    public var description: String { rawValue }
}
