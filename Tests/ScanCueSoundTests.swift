import AVFoundation
import XCTest
@testable import OpenVoice

final class ScanCueSoundTests: XCTestCase {
    func testSoundCuesAreShortPlayablePCMWaveFiles() throws {
        XCTAssertNil(ScanCueSound.wavData(for: .off))
        XCTAssertNil(ScanCueSound.wavData(for: .spoken))
        let blip = try XCTUnwrap(ScanCueSound.wavData(for: .blip))
        let woodblock = try XCTUnwrap(ScanCueSound.wavData(for: .woodblock))
        XCTAssertNotEqual(blip, woodblock)

        for wave in [blip, woodblock] {
            XCTAssertEqual(String(data: wave.prefix(4), encoding: .ascii), "RIFF")
            XCTAssertEqual(String(data: wave[8..<12], encoding: .ascii), "WAVE")
            XCTAssertEqual(String(data: wave[12..<16], encoding: .ascii), "fmt ")
            XCTAssertEqual(String(data: wave[36..<40], encoding: .ascii), "data")
            XCTAssertEqual(readUInt32(wave, at: 4), UInt32(wave.count - 8))
            XCTAssertEqual(readUInt32(wave, at: 24), UInt32(ScanCueSound.sampleRate))
            XCTAssertEqual(readUInt16(wave, at: 22), 1)
            XCTAssertEqual(readUInt16(wave, at: 34), 16)
            XCTAssertEqual(readUInt32(wave, at: 40), UInt32(wave.count - 44))
            XCTAssertLessThan(wave.count, 44 + ScanCueSound.sampleRate * 2 / 5)
            XCTAssertTrue(wave.dropFirst(44).contains { $0 != 0 })
            let player = try AVAudioPlayer(data: wave)
            XCTAssertGreaterThan(player.duration, 0.05)
            XCTAssertLessThan(player.duration, 0.2)
        }
    }

    private func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[data.startIndex + offset])
            | UInt16(data[data.startIndex + offset + 1]) << 8
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(readUInt16(data, at: offset))
            | UInt32(readUInt16(data, at: offset + 2)) << 16
    }
}
