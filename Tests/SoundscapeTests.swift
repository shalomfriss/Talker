import AVFoundation
import XCTest
@testable import OpenVoice

final class SoundscapeTests: XCTestCase {
    func testBundledLoopsArePlayableAndContainAudio() throws {
        for track in SoundscapeTrack.allCases {
            let url = try XCTUnwrap(track.fileURL, "Missing \(track.rawValue)")
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertEqual(player.duration, 16, accuracy: 0.1)
            XCTAssertEqual(player.numberOfChannels, 1)
            let bytes = Array(try Data(contentsOf: url).dropFirst(44))
            let frames = min(16_000, bytes.count / 2)
            let sum = (0..<frames).reduce(0.0) { total, index in
                let bits = UInt16(bytes[index * 2]) | (UInt16(bytes[index * 2 + 1]) << 8)
                let sample = Double(Int16(bitPattern: bits)) / Double(Int16.max)
                return total + sample * sample
            }
            XCTAssertGreaterThan(sqrt(sum / Double(frames)), 0.01)
        }
    }

    @MainActor
    func testOnlyOneSoundPlaysAndStopClearsState() throws {
        let playback = SoundscapePlayback()
        defer { playback.stop() }
        try playback.toggle(.rain, volume: 0.3)
        XCTAssertEqual(playback.current, .rain)
        try playback.toggle(.waves, volume: 0.3)
        XCTAssertEqual(playback.current, .waves)
        try playback.toggle(.waves, volume: 0.3)
        XCTAssertNil(playback.current)
    }
}
