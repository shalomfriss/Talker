import XCTest
@testable import OpenVoice

final class EnglishWordFormsTests: XCTestCase {
    func testSpanishNounAndVerbFormsUseExplicitMeanings() {
        func words(_ base: String) -> [String] { SpanishWordForms.options(for: base).map(\.text) }
        XCTAssertEqual(words("baño"), ["baño", "baños"])
        XCTAssertEqual(words("luz"), ["luz", "luces"])
        XCTAssertEqual(words("camión"), ["camión", "camiones"])
        XCTAssertEqual(words("Lápiz"), ["Lápiz", "Lápices"])
        XCTAssertEqual(words("mes"), ["mes", "meses"])
        XCTAssertTrue(words("baños").isEmpty)
        XCTAssertEqual(words("comer"), ["comer", "como", "estoy comiendo", "comí", "comeré"])
        XCTAssertEqual(words("jugar"), ["jugar", "juego", "estoy jugando", "jugué", "jugaré"])
        XCTAssertEqual(words("leer"), ["leer", "leo", "estoy leyendo", "leí", "leeré"])
        XCTAssertTrue(words("quiero").isEmpty)
        XCTAssertTrue(words("como").isEmpty)
        XCTAssertTrue(SpanishWordForms.options(for: "comer", role: .noun).isEmpty)
        XCTAssertTrue(words("me gusta").isEmpty)
        XCTAssertEqual(SpanishWordForms.options(for: "comer")[1].title, "I do it now (yo)")
        XCTAssertEqual(SpanishWordForms.options(for: "comer")[1].language, "es")
    }

    @MainActor
    func testSpanishPictureWordFormsPersistWithLanguageAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        store.settings.communicationLanguage = "es"
        let eat = try XCTUnwrap(store.items.first { $0.label == "eat" })
        store.select(eat)
        XCTAssertEqual(store.composedMessage, "comer")
        XCTAssertEqual(store.lastWordFormOptions.map(\.text),
                       ["comer", "como", "estoy comiendo", "comí", "comeré"])
        XCTAssertTrue(store.changeLastWordForm(to: .past))
        XCTAssertEqual(store.composedMessage, "comí")
        XCTAssertEqual(store.messageSpeechSegments().map(\.language), ["es"])
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.composedMessage, "comí")
        XCTAssertTrue(imported.changeLastWordForm(to: .future))
        XCTAssertEqual(imported.composedMessage, "comeré")
    }

    func testRegularAndCommonIrregularForms() {
        func words(_ base: String) -> [String] { EnglishWordForms.options(for: base).map(\.text) }
        XCTAssertEqual(words("walk"), ["walk", "walks", "walking", "walked", "will walk"])
        XCTAssertEqual(words("go"), ["go", "goes", "going", "went", "will go"])
        XCTAssertEqual(words("run"), ["run", "runs", "running", "ran", "will run"])
        XCTAssertEqual(words("try"), ["try", "tries", "trying", "tried", "will try"])
        XCTAssertEqual(words("child")[1], "children")
        XCTAssertEqual(words("Go")[3], "Went")
        XCTAssertTrue(words("no").isEmpty)
        XCTAssertTrue(words("all done").isEmpty)
    }

    @MainActor
    func testChangedWordPersistsWithConversationAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("word-forms.json")
        let store = CommunicationStore(storageURL: file)
        let originalID = store.activeConversationID
        let go = try XCTUnwrap(store.items.first { $0.label == "go" })
        store.select(go)
        XCTAssertTrue(store.changeLastWordForm(to: .past))
        XCTAssertEqual(store.composedMessage, "went")
        XCTAssertEqual(store.messageSpeechSegments().map(\.text), ["went"])
        XCTAssertTrue(store.addConversation("Other"))
        XCTAssertTrue(store.switchConversation(to: originalID))
        XCTAssertEqual(store.composedMessage, "went")
        XCTAssertEqual(store.lastWordFormOptions.first { $0.kind == .ongoing }?.text, "going")
        let backup = try store.backupData()
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(backup)
        XCTAssertEqual(imported.composedMessage, "went")
        XCTAssertTrue(imported.changeLastWordForm(to: .ongoing))
        XCTAssertEqual(imported.composedMessage, "going")
        let reloaded = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        XCTAssertEqual(reloaded.composedMessage, "going")
        XCTAssertEqual(reloaded.lastWordFormOptions.first { $0.kind == .past }?.text, "went")
        reloaded.removeLast()
        XCTAssertTrue(reloaded.lastWordFormOptions.isEmpty)
        reloaded.settings.communicationLanguage = "es"
        reloaded.select(go)
        XCTAssertTrue(reloaded.lastWordFormOptions.isEmpty)
    }
}
