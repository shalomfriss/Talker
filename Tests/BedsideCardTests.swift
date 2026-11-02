import XCTest
@testable import OpenVoice

final class BedsideCardTests: XCTestCase {
    func testStarterCardsCoverUrgentNeedsInEnglishAndSpanish() {
        for language in ["en", "es"] {
            let cards = BedsideCard.starterCards(language: language)
            XCTAssertEqual(cards.count, 12)
            XCTAssertTrue(cards.allSatisfy { !$0.label.isEmpty && !$0.message.isEmpty })
            XCTAssertEqual(Set(cards.map(\.id)).count, cards.count)
            XCTAssertEqual(cards.map(\.id), BedsideCard.starterCards(language: language).map(\.id))
        }
        XCTAssertEqual(BedsideCard.starterCards(language: "en")[2].message,
                       "I am having trouble breathing.")
        XCTAssertEqual(BedsideCard.starterCards(language: "es")[2].message,
                       "Me cuesta respirar.")
    }

    func testOlderSettingsUseStarterCardsAndCustomCardsSurviveCoding() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "bedsideCards")
        json.removeValue(forKey: "showUrgentBar")
        let old = try JSONDecoder().decode(
            AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.cardsForBedside(language: "en").count, 12)
        XCTAssertFalse(old.showUrgentBar)
        var settings = old
        settings.showUrgentBar = true
        let card = BedsideCard(symbol: "💬", label: "My phrase", message: "Please ask me first.")
        settings.setBedsideCards([card], language: "en")
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.cardsForBedside(language: "en"), [card])
        XCTAssertEqual(restored.cardsForBedside(language: "es").count, 12)
        XCTAssertTrue(restored.showUrgentBar)
    }

    @MainActor
    func testBedsideCardsStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let profileID = store.activeProfileID
        let card = BedsideCard(symbol: "⭐", label: "My helper", message: "Please ask my helper.")
        store.settings.setBedsideCards([card], language: "en")
        store.settings.showUrgentBar = true
        XCTAssertTrue(store.addProfile("Another communicator"))
        XCTAssertEqual(store.settings.cardsForBedside(language: "en").count, 12)
        XCTAssertFalse(store.settings.showUrgentBar)
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.cardsForBedside(language: "en"), [card])
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.showUrgentBar)
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.settings.cardsForBedside(language: "en"), [card])
        XCTAssertTrue(imported.settings.showUrgentBar)
    }
}
