import AVFoundation
import XCTest
import ZIPFoundation
@testable import OpenVoice

final class MessageBankImportTests: XCTestCase {
    @MainActor
    func testAudioFilesAndZipBecomeEditableBackedUpPhrases() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let audio = makeWAV()
        let directURL = directory.appendingPathComponent("Please_wait.wav")
        let invalidURL = directory.appendingPathComponent("broken.wav")
        let zipURL = directory.appendingPathComponent("bank.zip")
        try audio.write(to: directURL)
        try Data("not audio".utf8).write(to: invalidURL)
        let archive = try Archive(accessMode: .create)
        try archive.addEntry(with: "greetings/Good_morning.wav", type: .file,
                             uncompressedSize: Int64(audio.count), compressionMethod: .deflate) { offset, size in
            audio.subdata(in: Int(offset)..<Int(offset) + size)
        }
        try XCTUnwrap(archive.data).write(to: zipURL)

        let batch = MessageBankImporter.read([directURL, invalidURL, zipURL])
        XCTAssertEqual(batch.messages.map(\.text), ["Please wait", "Good morning"])
        XCTAssertEqual(batch.skipped, 1)

        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let imported = source.importBankedMessages(batch)
        XCTAssertEqual(imported.imported, 2)
        XCTAssertEqual(imported.skipped, 1)
        let phrase = try XCTUnwrap(source.phrases.first { $0.text == "Good morning" })
        XCTAssertEqual(phrase.folder, "Message bank")
        XCTAssertEqual(phrase.audioData, audio)
        XCTAssertNotNil(try? AVAudioPlayer(data: try XCTUnwrap(phrase.audioData)))
        XCTAssertEqual(source.bankedRecording(matching: "  good morning  "), audio)
        XCTAssertNil(source.bankedRecording(matching: "Good morning!"))
        XCTAssertNil(source.bankedRecording(matching: "Good morning again"))

        let duplicate = source.importBankedMessages(batch)
        XCTAssertEqual(duplicate.imported, 0)
        XCTAssertEqual(duplicate.skipped, 3)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.phrases.first { $0.text == "Good morning" }?.audioData, audio)
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
            .phrases.first { $0.text == "Please wait" }?.audioData, audio)

        XCTAssertTrue(source.addProfile("Second communicator"))
        XCTAssertNil(source.bankedRecording(matching: "Good morning"))
    }

    private func makeWAV() -> Data {
        var data = Data("RIFF".utf8)
        appendLE(UInt32(1_636), to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        appendLE(UInt32(16), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(UInt32(8_000), to: &data)
        appendLE(UInt32(16_000), to: &data)
        appendLE(UInt16(2), to: &data)
        appendLE(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        appendLE(UInt32(1_600), to: &data)
        data.append(Data(repeating: 0, count: 1_600))
        return data
    }

    private func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
}
