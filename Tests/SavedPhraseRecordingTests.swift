import XCTest
@testable import OpenVoice

final class SavedPhraseRecordingTests: XCTestCase {
    func testOlderSavedPhraseDecodesWithoutAudio() throws {
        let id = UUID()
        let data = Data("{\"id\":\"\(id.uuidString)\",\"text\":\"Please wait for me.\"}".utf8)
        let phrase = try JSONDecoder().decode(SavedPhrase.self, from: data)
        XCTAssertEqual(phrase.id, id)
        XCTAssertEqual(phrase.text, "Please wait for me.")
        XCTAssertNil(phrase.audioData)
    }

    @MainActor
    func testSavedPhraseRecordingStaysWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        source.addPhrase("Please wait for me.")
        let phrase = try XCTUnwrap(source.phrases.first { $0.text == "Please wait for me." })
        let recording = Data([1, 2, 3, 4, 5])
        source.updatePhraseRecording(phrase, audioData: recording)

        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).phrases.first { $0.id == phrase.id }?.audioData,
                       recording)
        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second communicator"))
        XCTAssertFalse(source.phrases.contains { $0.id == phrase.id })
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.phrases.first { $0.id == phrase.id }?.audioData, recording)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.phrases.first { $0.text == phrase.text }?.audioData, recording)

        source.updatePhraseRecording(phrase, audioData: nil)
        XCTAssertNil(source.phrases.first { $0.id == phrase.id }?.audioData)
    }
}
