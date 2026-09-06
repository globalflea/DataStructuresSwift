//
//  CRC64.swift
//  Tile38Swift
//
//  Created on 2026-09-05.
//

import Foundation

/// High-performance 64-bit Cyclic Redundancy Check (CRC-64) calculator.
///
/// Implements the standardized ECMA-182 polynomial ($x^{64} + x^{62} + x^{57} + x^{55} + x^{54} + x^{53} + x^{52} + x^{47} + x^{46} + x^{45} + x^{40} + x^{39} + x^{38} + x^{37} + x^{35} + x^{33} + x^{32} + x^{31} + x^{29} + x^{27} + x^{24} + x^{23} + x^{22} + x^{21} + x^{19} + x^{17} + x^{13} + x^{12} + x^{10} + x^9 + x^7 + x^4 + x + 1$)
/// represented in reversed/reflected form as `0x42F0E1EBA9EA3693`.
///
/// Utilizes a precomputed 256-entry lookup table for $O(N)$ byte-at-a-time throughput,
/// serving as the data integrity verification standard for WAL records and snapshot blocks.
public enum CRC64: Sendable {
    /// Reversed representation of ECMA-182 polynomial: `0x42F0E1EBA9EA3693`.
    public static let polynomial: UInt64 = 0x42F0E1EBA9EA3693

    /// Precomputed 256-entry table for accelerated byte-level computation.
    private static let table: [UInt64] = {
        var tbl = [UInt64](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt64(i)
            for _ in 0..<8 {
                if (crc & 1) == 1 {
                    crc = (crc >> 1) ^ polynomial
                } else {
                    crc >>= 1
                }
            }
            tbl[i] = crc
        }
        return tbl
    }()

    /// Computes the 64-bit CRC checksum of binary data.
    ///
    /// - Parameter data: Contiguous data buffer to verify.
    /// - Returns: Computed 64-bit checksum.
    public static func checksum(_ data: Data) -> UInt64 {
        data.withUnsafeBytes { buffer in
            checksum(buffer)
        }
    }

    /// Computes the 64-bit CRC checksum of an unsafe raw byte buffer.
    ///
    /// - Parameter buffer: Memory buffer to checksum.
    /// - Returns: Computed 64-bit checksum.
    public static func checksum(_ buffer: UnsafeRawBufferPointer) -> UInt64 {
        var crc: UInt64 = 0
        for byte in buffer {
            let index = Int((crc ^ UInt64(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        return crc
    }

    /// Incrementally updates an existing CRC-64 checksum with an additional data buffer.
    ///
    /// - Parameters:
    ///   - initial: The existing CRC value from previous chunks.
    ///   - data: Additional contiguous data buffer.
    /// - Returns: Updated 64-bit checksum.
    public static func update(crc initial: UInt64, with data: Data) -> UInt64 {
        data.withUnsafeBytes { buffer in
            var crc = initial
            for byte in buffer {
                let index = Int((crc ^ UInt64(byte)) & 0xFF)
                crc = (crc >> 8) ^ table[index]
            }
            return crc
        }
    }
}
