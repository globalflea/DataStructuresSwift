//
//  WALError.swift
//  DataStructuresSwift
//

import Foundation

/// Errors thrown during Write-Ahead Log operations.
public enum WALError: Error, Sendable, CustomStringConvertible, Equatable {
    case fileNotFound(path: String)
    case ioError(reason: String)
    case invalidMagic(expected: UInt32, found: UInt32)
    case checksumMismatch(expected: UInt64, actual: UInt64)
    case truncatedLog(offset: UInt64)
    case corruptedRecord(offset: UInt64, reason: String)
    case writerClosed

    public static func invalidMagic(found: UInt32) -> WALError {
        .invalidMagic(expected: 0, found: found)
    }

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "WAL file not found at path: \(path)"
        case .ioError(let reason):
            return "WAL I/O error: \(reason)"
        case .invalidMagic(let expected, let found):
            if expected == 0 {
                return "WAL invalid magic header: found 0x\(String(found, radix: 16))"
            }
            return "WAL invalid magic header: expected 0x\(String(expected, radix: 16)), found 0x\(String(found, radix: 16))"
        case .checksumMismatch(let expected, let actual):
            return "WAL CRC-64 checksum mismatch: expected 0x\(String(expected, radix: 16)), actual 0x\(String(actual, radix: 16))"
        case .truncatedLog(let offset):
            return "WAL truncated incomplete write encountered at byte offset \(offset)"
        case .corruptedRecord(let offset, let reason):
            return "WAL corrupted record at offset \(offset): \(reason)"
        case .writerClosed:
            return "WAL writer is closed"
        }
    }
}
