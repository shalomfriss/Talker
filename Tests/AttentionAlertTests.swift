import XCTest
@testable import OpenVoice

final class AttentionAlertTests: XCTestCase {
    func testDefaultAndCustomMessageFollowCommunicationLanguage() throws {
        var settings = AppSettings()
        XCTAssertEqual(settings.attentionMessage, "Excuse me. I have something to say.")
        settings.communicationLanguage = "es"
        XCTAssertEqual(settings.attentionMessage, "Disculpa. Tengo algo que decir.")
        settings.attentionMessageSpanish = "  Mira, tengo algo que decir.  "
        XCTAssertEqual(settings.attentionMessage, "Mira, tengo algo que decir.")
        settings.attentionMessageEnglish = "Please listen."
        settings.communicationLanguage = "en"
        XCTAssertEqual(settings.attentionMessage, "Please listen.")
        settings.attentionHaptics = true

        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.attentionMessageEnglish, "Please listen.")
        XCTAssertEqual(restored.attentionMessageSpanish, "  Mira, tengo algo que decir.  ")
        XCTAssertTrue(restored.attentionHaptics)
        settings.attentionMessageEnglish = "  \n "
        XCTAssertEqual(settings.attentionMessage, "Excuse me. I have something to say.")
    }

    @MainActor
    func testAttentionSettingsStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let firstID = store.activeProfileID
        store.settings.attentionMessageEnglish = "Please come here."
        store.settings.attentionMessageSpanish = "Por favor, ven aquí."
        store.settings.attentionHaptics = true
        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertEqual(store.settings.attentionMessage, "Excuse me. I have something to say.")
        XCTAssertFalse(store.settings.attentionHaptics)

        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.settings.attentionMessage, "Please come here.")
        XCTAssertEqual(store.settings.attentionMessageSpanish, "Por favor, ven aquí.")
        XCTAssertTrue(store.settings.attentionHaptics)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.attentionMessage, "Please come here.")
        XCTAssertEqual(restored.settings.attentionMessageSpanish, "Por favor, ven aquí.")
        XCTAssertTrue(restored.settings.attentionHaptics)
    }
}
