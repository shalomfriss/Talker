import AVFoundation
import XCTest
@testable import OpenVoice

final class SpokenAudioExporterTests: XCTestCase {
    @MainActor
    func testSynthesizedMessageCreatesPlayableWAV() async throws {
        let english = AVSpeechUtterance(string: "I need water")
        english.voice = AVSpeechSynthesisVoice(language: "en-US")
        let spanish = AVSpeechUtterance(string: "por favor")
        spanish.voice = AVSpeechSynthesisVoice(language: "es-ES")
        let url = try await SpokenAudioExporter.export(utterances: [english, spanish])
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.pathExtension, "wav")
        let file = try AVAudioFile(forReading: url)
        XCTAssertGreaterThan(file.length, 4_410)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(file.fileFormat.sampleRate, 44_100)
        XCTAssertNotNil(try? AVAudioPlayer(contentsOf: url))
        XCTAssertTrue(try containsAudibleSamples(in: url))
    }

    @MainActor
    func testRecordedMessageIsExportedAsPlayableWAV() async throws {
        let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: inputURL) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1))
        let source = try AVAudioFile(forWriting: inputURL, settings: format.settings)
        let samples = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 2_205))
        samples.frameLength = 2_205
        let channel = try XCTUnwrap(samples.floatChannelData?[0])
        for index in 0..<2_205 { channel[index] = sin(Float(index) * 0.1) * 0.2 }
        try source.write(from: samples)
        source.close()
        let data = try Data(contentsOf: inputURL)
        let url = try await SpokenAudioExporter.export(utterances: [], recordingData: data)
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        XCTAssertGreaterThan(file.length, 1_000)
        XCTAssertNotNil(try? AVAudioPlayer(contentsOf: url))
        XCTAssertTrue(try containsAudibleSamples(in: url))
    }

    @MainActor
    func testSavedPhraseAudioUsesRecordingAndStaysInItsProfile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("store.json"))
        XCTAssertTrue(store.addPhrase("Please wait for me"))
        let phrase = try XCTUnwrap(store.phrases.first { $0.text == "Please wait for me" })

        let inputURL = directory.appendingPathComponent("recording.wav")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1))
        let source = try AVAudioFile(forWriting: inputURL, settings: format.settings)
        let samples = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 2_205))
        samples.frameLength = 2_205
        let channel = try XCTUnwrap(samples.floatChannelData?[0])
        for index in 0..<2_205 { channel[index] = sin(Float(index) * 0.1) * 0.2 }
        try source.write(from: samples)
        source.close()
        store.updatePhraseRecording(phrase, audioData: try Data(contentsOf: inputURL))

        let outputURL = try await store.exportPhraseAudio(phrase)
        defer { try? FileManager.default.removeItem(at: outputURL) }
        XCTAssertEqual(outputURL.pathExtension, "wav")
        XCTAssertTrue(try containsAudibleSamples(in: outputURL))
        XCTAssertTrue(store.addProfile("Another person"))
        do {
            _ = try await store.exportPhraseAudio(phrase)
            XCTFail("Expected a phrase from another profile to be unavailable")
        } catch {
            XCTAssertEqual(error as? SpokenAudioExportError, .phraseUnavailable)
        }
    }

    @MainActor
    func testUnfinishedPhraseCannotBeSharedAsRawAudio() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("store.json"))
        XCTAssertTrue(store.addPhrase("I would like {drink}"))
        let phrase = try XCTUnwrap(store.phrases.first { $0.text == "I would like {drink}" })
        do {
            _ = try await store.exportPhraseAudio(phrase)
            XCTFail("Expected an unfilled phrase to need values")
        } catch {
            XCTAssertEqual(error as? SpokenAudioExportError, .unfinishedPhrase)
        }
    }

    @MainActor
    func testEmptyAudioRequestIsRejected() async {
        do {
            _ = try await SpokenAudioExporter.export(utterances: [])
            XCTFail("Expected an empty message error")
        } catch {
            XCTAssertEqual(error as? SpokenAudioExportError, .emptyMessage)
        }
    }

    private func containsAudibleSamples(in url: URL) throws -> Bool {
        let file = try AVAudioFile(forReading: url)
        while file.framePosition < file.length {
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096))
            try file.read(into: buffer)
            if let samples = buffer.floatChannelData?[0],
               (0..<Int(buffer.frameLength)).contains(where: { abs(samples[$0]) > 0.001 }) {
                return true
            }
        }
        return false
    }
}
