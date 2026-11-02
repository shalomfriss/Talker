import XCTest
@testable import OpenVoice

final class SpanishVocabularyTests: XCTestCase {
    func testEveryStarterPictureWordHasSpanishText() {
        let translations = StarterTranslations.forItems(StarterVocabulary.items)
        for item in StarterVocabulary.items {
            let translation = translations[item.id.uuidString]?["es"]
            XCTAssertNotNil(translation, "Missing Spanish text for \(item.label)")
            XCTAssertFalse(translation?.label.isEmpty ?? true)
            XCTAssertFalse(translation?.message.isEmpty ?? true)
        }
    }

    @MainActor
    func testSpanishSelectionAndCustomTranslationsSurviveProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let firstProfile = store.activeProfileID
        store.settings.communicationLanguage = "es"
        let yes = try XCTUnwrap(store.items.first(where: { $0.label == "yes" }))
        XCTAssertEqual(store.displayLabel(for: yes), "sí")
        store.select(yes)
        XCTAssertEqual(store.composedMessage, "sí")

        store.addItem(label: "my dog", symbol: "🐕", message: "my dog", category: "People",
                      imageData: nil, spanishLabel: "mi perro", spanishMessage: "quiero a mi perro")
        let dog = try XCTUnwrap(store.items.first(where: { $0.label == "my dog" }))
        XCTAssertEqual(store.displayLabel(for: dog), "mi perro")
        store.select(dog)
        XCTAssertEqual(store.composedMessage, "sí quiero a mi perro")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertEqual(restored.settings.communicationLanguage, "es")
        XCTAssertEqual(restored.displayMessage(for: dog), "quiero a mi perro")

        XCTAssertTrue(store.addProfile("Second speaker"))
        XCTAssertEqual(store.settings.communicationLanguage, "en")
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.displayLabel(for: dog), "mi perro")

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.settings.communicationLanguage, "es")
        XCTAssertEqual(imported.displayMessage(for: dog), "quiero a mi perro")
        imported.updateSpanishTranslation(for: dog.id, label: "", message: "")
        XCTAssertEqual(imported.displayLabel(for: dog), "my dog")
    }
}
