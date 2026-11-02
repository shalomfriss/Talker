import XCTest
@testable import OpenVoice

final class CommunicationNoteTests: XCTestCase {
    func testOldStoredDataWithoutNotesStartsEmpty() throws {
        let stored = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                phrases: StarterVocabulary.phrases, settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        object.removeValue(forKey: "notes")
        let restored = try JSONDecoder().decode(StoredData.self,
                                                from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(restored.notes.isEmpty)
    }

    @MainActor
    func testNotesStayWithProfileAndBackupAndCanBeEdited() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        XCTAssertFalse(store.saveNote(title: " ", topic: "Plans", text: "Meet at noon"))
        XCTAssertTrue(store.saveNote(title: "  Meeting  ", topic: "  Plans  ", text: "  Meet at noon  "))
        let note = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(note.title, "Meeting")
        XCTAssertEqual(note.topic, "Plans")
        XCTAssertEqual(note.text, "Meet at noon")
        XCTAssertTrue(store.saveNote(id: note.id, title: "Meeting tomorrow", topic: "plans",
                                     text: "Meet at one"))
        XCTAssertEqual(store.notes.first?.id, note.id)
        XCTAssertEqual(store.notes.first?.topic, "Plans")
        XCTAssertEqual(store.notes.first?.text, "Meet at one")
        XCTAssertFalse(store.saveNote(id: UUID(), title: "Missing", topic: "", text: "No"))

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.notes.first?.text, "Meet at one")
        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.notes, store.notes)

        XCTAssertTrue(store.addProfile("Another voice"))
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertTrue(store.saveNote(title: "My note", topic: "", text: "Another profile"))
        XCTAssertEqual(store.notes.first?.topic, "General")
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.notes.map(\.title), ["Meeting tomorrow"])
        XCTAssertTrue(store.deleteNote(id: note.id))
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertFalse(store.deleteNote(id: note.id))
    }

    @MainActor
    func testUsingNoteTextKeepsPictureDraft() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let want = try XCTUnwrap(store.items.first { $0.label == "want" })
        store.select(want)
        store.typedMessage = "Hello"
        XCTAssertTrue(store.saveNote(title: "At the doctor", topic: "Health",
                                     text: "Please explain that again."))
        XCTAssertTrue(store.appendTypedPhrase(try XCTUnwrap(store.notes.first?.text)))
        XCTAssertEqual(store.composedMessage, "want")
        XCTAssertEqual(store.typedMessage, "Hello Please explain that again.")
    }
}
