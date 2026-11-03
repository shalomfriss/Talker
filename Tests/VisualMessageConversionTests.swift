import XCTest
@testable import OpenVoice

final class VisualMessageConversionTests: XCTestCase {
    func testLargeVocabularyKeepsLongestMatchAndChosenPicture() {
        let fillers = (0..<2_500).map { number in
            CommunicationItem(label: "filler \(number)", symbol: "", message: "filler \(number)",
                              category: "Custom")
        }
        let short = CommunicationItem(label: "I need", symbol: "🙋", message: "I need", category: "Core")
        let long = CommunicationItem(label: "I need help", symbol: "🆘", message: "I need help", category: "Core")
        let hidden = CommunicationItem(label: "filler 2499", symbol: "⚠️", message: "filler 2499",
                                       category: "Custom", visibility: .hidden)
        let input = Array(repeating: "unknown", count: 80).joined(separator: " ") + " I need help filler 2499"
        let parts = VisualMessageConversion.convert(input, items: fillers + [short, long, hidden],
            label: { $0.label }, message: { $0.message }, pictureSelections: [81: .item(short.id)])

        XCTAssertEqual(parts.count, 82)
        XCTAssertTrue(parts.prefix(80).allSatisfy { $0.itemID == nil })
        XCTAssertEqual(parts[80].text, "I need help")
        XCTAssertEqual(parts[80].itemID, long.id)
        XCTAssertEqual(parts[81].itemID, short.id)
    }

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

    func testARASAACPictogramCanReplaceAnUnknownWordWithoutChangingItsText() {
        let picture = Data([1, 2, 3, 4])
        let parts = VisualMessageConversion.convert("my own word", items: [],
            label: { $0.label }, message: { $0.message },
            pictureSelections: [1: .pictogram(picture, 12345)])

        XCTAssertEqual(parts.map(\.text), ["my", "own", "word"])
        XCTAssertNil(parts[1].itemID)
        XCTAssertEqual(parts[1].imageData, picture)
        XCTAssertEqual(parts[1].arasaacPictogramID, 12345)
        XCTAssertNil(parts[0].imageData)
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

    @MainActor
    func testARASAACPictogramInMessageSurvivesUndoRelaunchAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("open-voice.json")
        let picture = Data([1, 2, 3, 4])
        let store = CommunicationStore(storageURL: url)

        XCTAssertTrue(store.appendVisualMessage("unmatchedword",
            pictureSelections: [0: .pictogram(picture, 12345)]))
        XCTAssertEqual(store.pictureMessageTokens.first?.imageData, picture)
        XCTAssertEqual(store.pictureMessageTokens.first?.arasaacPictogramID, 12345)
        XCTAssertEqual(store.items.filter { $0.arasaacPictogramID == 12345 }.count, 0)

        store.clearMessage()
        store.undoClearMessage()
        XCTAssertEqual(store.pictureMessageTokens.first?.imageData, picture)

        let restored = CommunicationStore(storageURL: url)
        XCTAssertEqual(restored.pictureMessageTokens.first?.imageData, picture)
        XCTAssertEqual(restored.pictureMessageTokens.first?.arasaacPictogramID, 12345)

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.pictureMessageTokens.first?.imageData, picture)
        XCTAssertEqual(imported.pictureMessageTokens.first?.arasaacPictogramID, 12345)

        store.beginPrivateConversation()
        XCTAssertTrue(store.appendVisualMessage("privateword",
            pictureSelections: [0: .pictogram(Data([9, 8, 7]), 67890)]))
        let privateBackup = try store.backupData()
        store.endPrivateConversation()
        XCTAssertEqual(store.pictureMessageTokens.first?.imageData, picture)
        let privateImport = CommunicationStore(storageURL: directory.appendingPathComponent("private-import.json"))
        try privateImport.importBackup(privateBackup)
        XCTAssertEqual(privateImport.composedMessage, "unmatchedword")
        XCTAssertEqual(privateImport.pictureMessageTokens.first?.arasaacPictogramID, 12345)
    }
}
