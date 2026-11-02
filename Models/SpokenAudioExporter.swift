import AVFoundation
import Foundation

enum SpokenAudioExportError: LocalizedError, Equatable {
    case emptyMessage
    case noAudio
    case conversionFailed
    case phraseUnavailable
    case unfinishedPhrase

    var errorDescription: String? {
        switch self {
        case .emptyMessage: "There is no message to share."
        case .noAudio: "The selected voice could not make an audio clip."
        case .conversionFailed: "The audio clip could not be saved."
        case .phraseUnavailable: "This saved phrase is no longer available."
        case .unfinishedPhrase: "Fill in the phrase before sharing its audio."
        }
    }
}

/// Produces a WAV file that can be attached to a message or saved in Files.
/// A fixed output format lets words spoken in different languages share one clip.
@MainActor
enum SpokenAudioExporter {
    static func export(utterances: [AVSpeechUtterance], recordingData: Data? = nil) async throws -> URL {
        guard !utterances.isEmpty || recordingData != nil else { throw SpokenAudioExportError.emptyMessage }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpenVoiceAudioShares", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let staleDate = Date().addingTimeInterval(-24 * 60 * 60)
        let previous = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey])
        for file in previous where file.pathExtension == "wav" {
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let modified = values.contentModificationDate, modified < staleDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
        let url = directory.appendingPathComponent("Open Voice Message \(UUID().uuidString).wav")
        let writer = try PCMClipWriter(url: url)
        do {
            if let recordingData {
                try writer.appendRecording(recordingData)
            } else {
                for utterance in utterances {
                    try await write(utterance, to: writer)
                }
            }
            guard writer.frameCount > 0 else { throw SpokenAudioExportError.noAudio }
            writer.finish()
            return url
        } catch {
            writer.finish()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private static func write(_ utterance: AVSpeechUtterance, to writer: PCMClipWriter) async throws {
        let renderer = SpeechBufferRenderer(writer: writer)
        try await renderer.render(utterance)
    }
}

private final class SpeechBufferRenderer: @unchecked Sendable {
    private let writer: PCMClipWriter
    private let synthesizer = AVSpeechSynthesizer()
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var completed = false

    init(writer: PCMClipWriter) { self.writer = writer }

    @MainActor
    func render(_ utterance: AVSpeechUtterance) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            synthesizer.write(utterance) { [self] buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                lock.lock()
                defer { lock.unlock() }
                guard !completed else { return }
                if pcm.frameLength == 0 {
                    completed = true
                    self.continuation?.resume()
                    self.continuation = nil
                } else {
                    do { try writer.append(pcm) }
                    catch {
                        completed = true
                        self.continuation?.resume(throwing: error)
                        self.continuation = nil
                    }
                }
            }
        }
    }
}

private final class PCMClipWriter: @unchecked Sendable {
    private let file: AVAudioFile
    private var converters: [String: AVAudioConverter] = [:]
    private(set) var frameCount: AVAudioFramePosition = 0

    init(url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        file = try AVAudioFile(forWriting: url, settings: settings,
                               commonFormat: .pcmFormatFloat32, interleaved: false)
    }

    func appendRecording(_ data: Data) throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: source, options: .atomic)
        defer { try? FileManager.default.removeItem(at: source) }
        let recording = try AVAudioFile(forReading: source)
        while recording.framePosition < recording.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: recording.processingFormat, frameCapacity: 4096) else {
                throw SpokenAudioExportError.conversionFailed
            }
            try recording.read(into: buffer)
            if buffer.frameLength == 0 { break }
            try append(buffer)
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) throws {
        if buffer.format == file.processingFormat {
            try file.write(from: buffer)
            frameCount += AVAudioFramePosition(buffer.frameLength)
            return
        }
        let format = buffer.format
        let key = "\(format.sampleRate)-\(format.channelCount)-\(format.commonFormat.rawValue)-\(format.isInterleaved)"
        let converter: AVAudioConverter
        if let cached = converters[key] {
            converter = cached
        } else {
            guard let made = AVAudioConverter(from: format, to: file.processingFormat) else {
                throw SpokenAudioExportError.conversionFailed
            }
            converters[key] = made
            converter = made
        }
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 44_100 / format.sampleRate)) + 256
        guard let output = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
            throw SpokenAudioExportError.conversionFailed
        }
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        if conversionError != nil || status == .error { throw conversionError ?? SpokenAudioExportError.conversionFailed }
        if output.frameLength > 0 {
            try file.write(from: output)
            frameCount += AVAudioFramePosition(output.frameLength)
        }
    }

    func finish() { file.close() }
}
