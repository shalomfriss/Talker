import XCTest
@testable import OpenVoice

final class FeelingsLogTests: XCTestCase {
    func testSpanishFeelingPhrasesRemainGrammatical() {
        XCTAssertEqual(FeelingMessageComposer.message(englishFeeling: "scared", displayedFeeling: "tengo miedo",
                                                       language: "es", intensity: 4, support: nil),
                       "Tengo miedo. Intensidad 4 de 5.")
        XCTAssertEqual(FeelingMessageComposer.message(englishFeeling: "happy", displayedFeeling: "feliz",
                                                       language: "es", intensity: 3, support: "Necesito ayuda."),
                       "Me siento feliz. Intensidad 3 de 5. Necesito ayuda.")
        XCTAssertEqual(FeelingMessageComposer.message(englishFeeling: "custom", displayedFeeling: "confundido",
                                                       language: "es", intensity: 2, support: nil),
                       "Así me siento: confundido. Intensidad 2 de 5.")
    }

    @MainActor
    func testSavingRequiresOptInAndEntriesStayWithProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID

        XCTAssertFalse(store.saveFeelingEntry(label: "happy", symbol: "😊", intensity: 3,
                                                support: nil, message: "I feel happy."))
        XCTAssertTrue(store.feelingsLog.isEmpty)
        store.settings.saveFeelingsLog = true
        XCTAssertFalse(store.saveFeelingEntry(label: "happy", symbol: "😊", intensity: 6,
                                                support: nil, message: "I feel happy."))
        XCTAssertTrue(store.saveFeelingEntry(label: "happy", symbol: "😊", intensity: 3,
                                               support: "Please stay with me.", message: "I feel happy."))
        let entry = try XCTUnwrap(store.feelingsLog.first)
        XCTAssertEqual(entry.language, "en")
        XCTAssertEqual(entry.support, "Please stay with me.")
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertTrue(store.feelingsLog.isEmpty)
        XCTAssertFalse(store.settings.saveFeelingsLog)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.feelingsLog, [entry])
        XCTAssertTrue(store.settings.saveFeelingsLog)
        XCTAssertEqual(CommunicationStore(storageURL: file).feelingsLog, [entry])

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.feelingsLog, [entry])
        imported.deleteFeelingEntry(id: entry.id)
        XCTAssertTrue(imported.feelingsLog.isEmpty)
    }

    @MainActor
    func testLogKeepsLanguageAndCanBeClearedAfterOptOut() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("data.json"))
        store.settings.communicationLanguage = "es"
        store.settings.saveFeelingsLog = true
        XCTAssertTrue(store.saveFeelingEntry(label: "feliz", symbol: "😊", intensity: 2,
                                               support: "Necesito ayuda.",
                                               message: "Me siento feliz. Intensidad 2 de 5. Necesito ayuda."))
        XCTAssertEqual(store.feelingsLog.first?.language, "es")
        store.settings.saveFeelingsLog = false
        XCTAssertEqual(store.feelingsLog.count, 1)
        store.clearFeelingsLog()
        XCTAssertTrue(store.feelingsLog.isEmpty)
    }
}
