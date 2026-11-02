import Foundation

enum ScanCueSound {
    static let sampleRate = 22_050
    private static let blip = makeWAV(mode: .blip)
    private static let woodblock = makeWAV(mode: .woodblock)

    static func wavData(for mode: ScanCueMode) -> Data? {
        switch mode {
        case .off, .spoken: nil
        case .blip: blip
        case .woodblock: woodblock
        }
    }

    private static func makeWAV(mode: ScanCueMode) -> Data {
        let duration = mode == .blip ? 0.11 : 0.14
        let frames = Int(Double(sampleRate) * duration)
        let byteCount = frames * MemoryLayout<Int16>.size
        var data = Data(capacity: 44 + byteCount)
        data.append(contentsOf: "RIFF".utf8)
        appendLE(UInt32(36 + byteCount), to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        appendLE(UInt32(16), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(UInt32(sampleRate), to: &data)
        appendLE(UInt32(sampleRate * 2), to: &data)
        appendLE(UInt16(2), to: &data)
        appendLE(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        appendLE(UInt32(byteCount), to: &data)

        var noiseSeed: UInt32 = 0x5EED_1234
        for frame in 0..<frames {
            let time = Double(frame) / Double(sampleRate)
            let attack = min(1, time / 0.003)
            let wave: Double
            if mode == .blip {
                wave = sin(2 * .pi * 880 * time) * attack * exp(-18 * time) * 0.65
            } else {
                noiseSeed = noiseSeed &* 1_664_525 &+ 1_013_904_223
                let noise = Double(noiseSeed) / Double(UInt32.max) * 2 - 1
                let tone = sin(2 * .pi * 610 * time) * 0.65
                    + sin(2 * .pi * 1_220 * time) * 0.24 + noise * 0.11
                wave = tone * attack * exp(-32 * time) * 0.82
            }
            let sample = Int16((max(-1, min(1, wave)) * Double(Int16.max)).rounded())
            appendLE(sample, to: &data)
        }
        return data
    }

    private static func appendLE<Value: FixedWidthInteger>(_ value: Value, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
