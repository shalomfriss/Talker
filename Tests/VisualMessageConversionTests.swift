import XCTest
@testable import OpenVoice

final class VisualMessageConversionTests: XCTestCase {
    func testLongestPhraseAndPersonalPhotoWinWhileUnknownWordsStayReadable() {
        let photo = Data([1, 2, 3])
        let phrase = CommunicationItem(label: "help me", symbol: "🙋", message: "help me",
                                       category: "Needs", imageData: photo, isCustom: true)
        let plain = CommunicationItem(label: "help", symbol: "❓", message: "help", category: "Core")
        let basicWater = CommunicationItem(label: "water", symbol: "💧", message: "water",
                                           category: "Needs")
        let personalWater = CommunicationItem(label: "water", symbol: "", message: "water",
                                              category: "Needs", imageData: photo, isCustom: true)
        let action = CommunicationItem(label: "please", symbol: "⚠️", message: "please",
                                       category: "Core", action: .clearMessage)
        let parts = VisualMessageConversion.convert("Please help me, water!", items: [plain, basicWater,
            personalWater, phrase, action], label: { $0.label }, message: { $0.message })

        XCTAssertEqual(parts.map(\.text), ["Please", "help me,", "water!"])
        XCTAssertNil(parts[0].itemID)
        XCTAssertEqual(parts[1].itemID, phrase.id)
        XCTAssertEqual(parts[2].itemID, personalWater.id)
        XCTAssertEqual(parts[2].imageData, photo)
    }

    func testPictureChoicesCanReplaceAMatchAndGiveAnUnknownWordAPicture() {
        let photo = Data([4, 5, 6])
        let personalWater = CommunicationItem(label: "water", symbol: "", message: "water",
                                              category: "Needs", imageData: photo, isCustom: true)
        let starterWater = CommunicationItem(label: "water", symbol: "💧", message: "water",
                                             category: "Needs")
        let items = [personalWater, starterWater]
        let chosen = VisualMessageConversion.convert("water mystery", items: items,
            label: { $0.label }, message: { $0.message },
            pictureSelections: [0: .item(starterWater.id), 1: .item(personalWater.id)])
        XCTAssertEqual(chosen.map(\.text), ["water", "mystery"])
        XCTAssertEqual(chosen[0].itemID, starterWater.id)
        XCTAssertEqual(chosen[0].symbol, "💧")
        XCTAssertEqual(chosen[1].itemID, personalWater.id)
        XCTAssertEqual(chosen[1].imageData, photo)

        let textOnly = VisualMessageConversion.convert("water", items: items,
            label: { $0.label }, message: { $0.message }, pictureSelections: [0: .textOnly])
        XCTAssertNil(textOnly[0].itemID)
        XCTAssertNil(textOnly[0].imageData)
        let removed = VisualMessageConversion.convert("water", items: items,
            label: { $0.label }, message: { $0.message },
            pictureSelections: [0: .item(UUID())])
        XCTAssertNil(removed[0].itemID)
    }

    @MainActor
    func testConvertedWordsAppendToPictureDraftWithoutSpeakingAndSurviveRelaunch() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("open-voice.json")
        let store = CommunicationStore(storageURL: url)
        store.settings.saveHistory = true
        let word = store.items.first { $0.label == "water" }
        XCTAssertNotNil(word)
        let historyCount = store.history.count

        XCTAssertTrue(store.appendVisualMessage("water, xylophonezz!"))
        XCTAssertEqual(store.composedMessage, "water, xylophonezz!")
        XCTAssertEqual(store.pictureMessageTokens.first?.symbol, word?.symbol)
        XCTAssertNil(store.pictureMessageTokens.last?.symbol)
        XCTAssertEqual(store.history.count, historyCount)
        XCTAssertFalse(store.appendVisualMessage("  "))

        let reloaded = CommunicationStore(storageURL: url)
        XCTAssertEqual(reloaded.composedMessage, "water, xylophonezz!")
        XCTAssertEqual(reloaded.pictureMessageTokens.first?.symbol, word?.symbol)
        reloaded.settings.communicationLanguage = "es"
        let yes = reloaded.items.first { $0.label == "yes" }
        XCTAssertEqual(reloaded.visualMessageParts(for: "Sí!").first?.itemID, yes?.id)
    }

    @MainActor
    func testChosenPictureStaysWithMessageAfterRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("open-voice.json")
        let store = CommunicationStore(storageURL: url)
        let help = try XCTUnwrap(store.items.first { $0.label == "help" })
        XCTAssertTrue(store.appendVisualMessage("water", pictureSelections: [0: .item(help.id)]))
        XCTAssertEqual(store.composedMessage, "water")
        XCTAssertEqual(store.pictureMessageTokens.first?.symbol, help.symbol)

        let restored = CommunicationStore(storageURL: url)
        XCTAssertEqual(restored.composedMessage, "water")
        XCTAssertEqual(restored.pictureMessageTokens.first?.symbol, help.symbol)

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.composedMessage, "water")
        XCTAssertEqual(imported.pictureMessageTokens.first?.symbol, help.symbol)
    }
}
