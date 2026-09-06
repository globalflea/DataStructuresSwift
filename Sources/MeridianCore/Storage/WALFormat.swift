//
//  WALFormat.swift
//  DataStructuresSwift
//

import Foundation

/// Serialization encoding formats supported by the Write-Ahead Log.
public enum WALFormat: String, Sendable, Equatable, Hashable, Codable, CaseIterable, CustomStringConvertible {
    /// High-density binary framing preceded by fixed header and CRC-64 checksum.
    case binary = "binary"

    /// Textual JSON lines representation enabling human-readable inspection, log tailing, and offline auditing.
    case json = "json"

    public var description: String { rawValue }
}
