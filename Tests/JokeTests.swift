import XCTest
@testable import OpenVoice

final class JokeTests: XCTestCase {
    @MainActor
    func testJokesValidateAndStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID

        XCTAssertFalse(store.addJoke(title: " ", setup: "Why?", punchline: "Because."))
        XCTAssertFalse(store.addJoke(title: "A joke", setup: " ", punchline: "Because."))
        XCTAssertTrue(store.addJoke(title: "  A joke  ", setup: "  Why? ", punchline: " Because.  ",
                                    soundEffectData: Data([1, 2, 3])))
        XCTAssertFalse(store.addJoke(title: "a JOKE", setup: "Another?", punchline: "No."))
        XCTAssertEqual(store.jokes.first?.title, "A joke")
        XCTAssertEqual(store.jokes.first?.setup, "Why?")
        XCTAssertEqual(store.jokes.first?.punchline, "Because.")

        var revised = try XCTUnwrap(store.jokes.first)
        revised.punchline = "A new answer."
        XCTAssertTrue(store.updateJoke(revised))
        XCTAssertEqual(store.jokes.first?.punchline, "A new answer.")
        XCTAssertTrue(store.addProfile("Another person"))
        XCTAssertTrue(store.jokes.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.jokes.count, 1)
        XCTAssertEqual(CommunicationStore(storageURL: file).jokes, store.jokes)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.jokes, store.jokes)
        XCTAssertEqual(restored.jokes.first?.soundEffectData, Data([1, 2, 3]))

        store.deleteJoke(revised)
        XCTAssertTrue(store.jokes.isEmpty)
    }

    func testOlderBackupWithoutJokesStillLoads() throws {
        let current = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                 phrases: StarterVocabulary.phrases, settings: AppSettings())
        let encoded = try JSONEncoder().encode(current)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "jokes")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(StoredData.self, from: oldData)
        XCTAssertTrue(restored.jokes.isEmpty)
    }
}
