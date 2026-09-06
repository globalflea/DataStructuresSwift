//
//  WALFrame.swift
//  DataStructuresSwift
//

import Foundation

/// Default magic header for binary WAL files ("WAL1" = 0x57414C31).
public let defaultWALBinaryMagic: UInt32 = 0x57414C31

/// Fixed byte length of the binary WAL frame header:
/// 4 bytes (Magic) + 8 bytes (Sequence) + 8 bytes (Timestamp) + 4 bytes (Length) + 8 bytes (CRC-64) = 32 bytes.
public let walHeaderSize: Int = 32

/// Binary framing codec for Write-Ahead Log records.
public enum WALFrame {
    /// Encodes a 32-byte binary frame header.
    public static func encodeHeader(
        magic: UInt32 = defaultWALBinaryMagic,
        sequenceNumber: UInt64,
        timestampMillis: Int64,
        payloadLength: UInt32,
        crc64: UInt64
    ) -> Data {
        var data = Data(capacity: walHeaderSize)
        var m = magic.bigEndian
        var seq = sequenceNumber.bigEndian
        var ts = UInt64(bitPattern: timestampMillis).bigEndian
        var len = payloadLength.bigEndian
        var crc = crc64.bigEndian

        data.append(contentsOf: Swift.withUnsafeBytes(of: &m) { Array($0) })
        data.append(contentsOf: Swift.withUnsafeBytes(of: &seq) { Array($0) })
        data.append(contentsOf: Swift.withUnsafeBytes(of: &ts) { Array($0) })
        data.append(contentsOf: Swift.withUnsafeBytes(of: &len) { Array($0) })
        data.append(contentsOf: Swift.withUnsafeBytes(of: &crc) { Array($0) })
        return data
    }

    /// Decodes a 32-byte binary frame header.
    public static func decodeHeader(
        from data: Data,
        offset: Int = 0
    ) -> (magic: UInt32, sequenceNumber: UInt64, timestampMillis: Int64, payloadLength: UInt32, crc64: UInt64)? {
        guard data.count >= offset + walHeaderSize else { return nil }

        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            let ptr = baseAddress.advanced(by: offset)

            let m = ptr.loadUnaligned(fromByteOffset: 0, as: UInt32.self).bigEndian
            let seq = ptr.loadUnaligned(fromByteOffset: 4, as: UInt64.self).bigEndian
            let rawTs = ptr.loadUnaligned(fromByteOffset: 12, as: UInt64.self).bigEndian
            let ts = Int64(bitPattern: rawTs)
            let len = ptr.loadUnaligned(fromByteOffset: 20, as: UInt32.self).bigEndian
            let crc = ptr.loadUnaligned(fromByteOffset: 24, as: UInt64.self).bigEndian

            return (m, seq, ts, len, crc)
        }
    }
}
