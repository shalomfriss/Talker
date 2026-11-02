import XCTest
@testable import OpenVoice

final class GrammarColorCodingTests: XCTestCase {
    func testStarterWordsUseDistinctFitzgeraldCategoriesAndCustomWordsAreExplicit() throws {
        let words = StarterVocabulary.items
        func word(_ label: String, on board: String) throws -> CommunicationItem {
            try XCTUnwrap(words.first { $0.label == label && $0.category == board })
        }
        XCTAssertEqual(GrammarColorCoding.category(for: try word("I", on: "Core")), .people)
        XCTAssertEqual(GrammarColorCoding.category(for: try word("want", on: "Core")), .verbs)
        XCTAssertEqual(GrammarColorCoding.category(for: try word("don't", on: "Core")), .littleWords)
        XCTAssertEqual(GrammarColorCoding.category(for: try word("happy", on: "Feelings")), .describing)
        XCTAssertEqual(GrammarColorCoding.category(for: try word("pizza", on: "Food")), .things)
        XCTAssertEqual(GrammarColorCoding.category(for: try word("school", on: "Places")), .places)

        var personal = try word("pizza", on: "Food")
        personal.isCustom = true
        XCTAssertNil(GrammarColorCoding.category(for: personal))
        personal.grammarCategory = .verbs
        XCTAssertEqual(GrammarColorCoding.category(for: personal), .verbs)
    }

    func testSchemeUsesCategoryColorsWhilePersonalColorsRemainSeparate() throws {
        let word = try XCTUnwrap(StarterVocabulary.items.first { $0.label == "want" && $0.category == "Core" })
        let board = GrammarColorCoding.colors(for: word, scheme: .board)
        XCTAssertNil(board.background)
        XCTAssertNil(board.border)
        let border = GrammarColorCoding.colors(for: word, scheme: .fitzgeraldBorder)
        XCTAssertNil(border.background)
        XCTAssertEqual(border.border, GrammarCategory.verbs.borderHex)
        let fill = GrammarColorCoding.colors(for: word, scheme: .fitzgeraldFill)
        XCTAssertEqual(fill.background, GrammarCategory.verbs.fillHex)
        XCTAssertEqual(fill.border, GrammarCategory.verbs.borderHex)
        XCTAssertTrue(try XCTUnwrap(ButtonColorValue(text: fill.background!)).prefersDarkText)
    }

    @MainActor
    func testSchemeAndWordCategoryStayWithProfileAndBackup() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(old.grammarColorScheme, .board)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        store.settings.grammarColorScheme = .fitzgeraldFill
        store.addItem(label: "engineer", symbol: "🧑‍💻", message: "engineer", category: "People",
                      imageData: nil, grammarCategory: .people)
        let firstID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertEqual(store.settings.grammarColorScheme, .board)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.settings.grammarColorScheme, .fitzgeraldFill)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.grammarColorScheme, .fitzgeraldFill)
        XCTAssertEqual(restored.items.first { $0.label == "engineer" }?.grammarCategory, .people)
    }
}
