//
//  CRC64Tests.swift
//  DataStructuresSwift
//

import Foundation
import Testing
@testable import DataStructures

@Suite("CRC-64 ECMA-182 Data Integrity Tests")
struct CRC64Tests {
    @Test("Empty data produces zero checksum")
    func testEmptyData() {
        let empty = Data()
        let result = CRC64.checksum(empty)
        #expect(result == 0)

        empty.withUnsafeBytes { rawBuffer in
            #expect(CRC64.checksum(rawBuffer) == 0)
        }
    }

    @Test("Incremental update matches one-shot computation")
    func testIncrementalUpdateMatchesOneShot() {
        let part1 = Data("Hello, ".utf8)
        let part2 = Data("World!".utf8)
        let full = Data("Hello, World!".utf8)

        let oneShot = CRC64.checksum(full)
        let step1 = CRC64.checksum(part1)
        let step2 = CRC64.update(crc: step1, with: part2)

        #expect(oneShot != 0)
        #expect(oneShot == step2)
    }

    @Test("Idempotency across multiple invocations")
    func testIdempotency() {
        let data = Data("DataStructuresSwift Write-Ahead Log Integrity".utf8)
        let crc1 = CRC64.checksum(data)
        let crc2 = CRC64.checksum(data)
        #expect(crc1 == crc2)
        #expect(crc1 != 0)
    }

    @Test("Different inputs yield distinct checksums")
    func testDistinctInputs() {
        let dataA = Data("Mutation Alpha".utf8)
        let dataB = Data("Mutation Beta".utf8)
        #expect(CRC64.checksum(dataA) != CRC64.checksum(dataB))
    }

    @Test("Large buffer chunking verification")
    func testLargeBufferChunking() {
        var bigData = Data(count: 65536)
        for i in 0..<bigData.count {
            bigData[i] = UInt8(i & 0xFF)
        }

        let fullChecksum = CRC64.checksum(bigData)
        var incrementalCRC: UInt64 = 0
        let chunkSize = 4096
        for offset in stride(from: 0, to: bigData.count, by: chunkSize) {
            let chunk = bigData.subdata(in: offset..<min(offset + chunkSize, bigData.count))
            incrementalCRC = CRC64.update(crc: incrementalCRC, with: chunk)
        }

        #expect(fullChecksum == incrementalCRC)
    }
}
