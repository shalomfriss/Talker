import XCTest
@testable import OpenVoice

final class SavedPhraseFolderTests: XCTestCase {
    func testOlderSavedPhraseDecodesWithoutFolder() throws {
        let id = UUID()
        let data = Data("{\"id\":\"\(id.uuidString)\",\"text\":\"Please wait for me.\"}".utf8)
        let phrase = try JSONDecoder().decode(SavedPhrase.self, from: data)
        XCTAssertNil(phrase.folder)
        XCTAssertNil(phrase.folderLink)
    }

    @MainActor
    func testPhraseFolderLinksFollowRenameTransferAndRemoval() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        XCTAssertTrue(source.addPhrase("Water", folder: "Food"))
        XCTAssertTrue(source.addPhrase("Hello"))
        XCTAssertFalse(source.addPhrase("Broken link", folderLink: .named("Missing")))
        XCTAssertTrue(source.addPhrase("Open food", folderLink: .named("food")))
        let card = try XCTUnwrap(source.phrases.first { $0.text == "Open food" })
        XCTAssertEqual(card.folderLink, .named("Food"))
        XCTAssertTrue(source.updatePhraseFolderLink(card, to: .quick))
        XCTAssertEqual(source.phrases.first { $0.id == card.id }?.folderLink, .quick)
        XCTAssertTrue(source.updatePhraseFolderLink(card, to: .named("Food")))
        XCTAssertTrue(source.renamePhraseFolder("Food", to: "Meals"))
        XCTAssertEqual(source.phrases.first { $0.id == card.id }?.folderLink, .named("Meals"))
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).phrases.first { $0.id == card.id }?.folderLink,
                       .named("Meals"))

        let data = try PhraseCollectionTransfer.exportData(source.phrases, named: "Links")
        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        XCTAssertEqual(target.importPhraseCollection(try PhraseCollectionTransfer.importData(data),
                                                     mode: .addMissing).added, 3)
        XCTAssertEqual(target.phrases.first { $0.text == "Open food" }?.folderLink, .named("Meals"))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.phrases.first { $0.id == card.id }?.folderLink, .named("Meals"))

        let water = try XCTUnwrap(source.phrases.first { $0.text == "Water" })
        source.deletePhrase(water)
        XCTAssertNil(source.phrases.first { $0.id == card.id }?.folderLink)
    }

    @MainActor
    func testFoldersStayWithProfileAndBackupAndCanBeCleared() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        source.addPhrase("I need quiet time.", folder: "  Needs  ")
        source.addPhrase("I need a drink.", folder: "needs")
        let quiet = try XCTUnwrap(source.phrases.first { $0.text == "I need quiet time." })
        let drink = try XCTUnwrap(source.phrases.first { $0.text == "I need a drink." })
        XCTAssertEqual(source.phrases.first { $0.id == quiet.id }?.folder, "Needs")
        XCTAssertEqual(source.phrases.first { $0.id == drink.id }?.folder, "Needs")

        let firstProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second communicator"))
        XCTAssertFalse(source.phrases.contains { $0.id == quiet.id })
        XCTAssertTrue(source.switchProfile(to: firstProfile))
        XCTAssertEqual(source.phrases.first { $0.id == quiet.id }?.folder, "Needs")
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).phrases.first { $0.id == quiet.id }?.folder,
                       "Needs")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.phrases.first { $0.text == quiet.text }?.folder, "Needs")

        source.movePhrase(quiet, to: "  ")
        XCTAssertNil(source.phrases.first { $0.id == quiet.id }?.folder)
    }

    @MainActor
    func testRenamingFolderMovesEveryPhraseAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        source.addPhrase("I need quiet time.", folder: "Needs")
        source.addPhrase("I need a drink.", folder: "Needs")
        source.addPhrase("I would like to go outside.", folder: "Places")
        XCTAssertFalse(source.renamePhraseFolder("Needs", to: "  "))
        XCTAssertTrue(source.renamePhraseFolder("Needs", to: "  My needs  "))
        XCTAssertEqual(source.phrases.filter { $0.folder == "My needs" }.count, 2)
        XCTAssertFalse(source.phrases.contains { $0.folder == "Needs" })

        XCTAssertTrue(source.renamePhraseFolder("My needs", to: "places"))
        XCTAssertEqual(source.phrases.filter { $0.folder == "Places" }.count, 3)
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).phrases.filter { $0.folder == "Places" }.count, 3)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.phrases.filter { $0.folder == "Places" }.count, 3)
    }

    @MainActor
    func testPhraseCardGridsStayWithFolderProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        source.addPhrase("I need a drink.", folder: "Needs")
        source.setPhraseCardGridLayout(BoardGridLayout(columns: 16, rows: 16), for: "folder:Needs")
        source.setPhraseCardGridLayout(BoardGridLayout(columns: 2, rows: 3), for: "quick")
        let drink = try XCTUnwrap(source.phrases.first { $0.folder == "Needs" })
        XCTAssertTrue(source.movePhraseCard(drink, to: 20, in: "folder:Needs"))
        XCTAssertEqual(source.settings.phraseCardGridLayouts["folder:Needs"]?.pageCapacity, 256)
        XCTAssertEqual(source.settings.phraseCardEmptySlots["folder:Needs"], Array(0..<20))
        XCTAssertNil(source.settings.phraseCardGridLayouts["all"])

        let firstProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second communicator"))
        XCTAssertTrue(source.settings.phraseCardGridLayouts.isEmpty)
        XCTAssertTrue(source.settings.phraseCardEmptySlots.isEmpty)
        XCTAssertTrue(source.switchProfile(to: firstProfile))
        XCTAssertEqual(source.settings.phraseCardGridLayouts["folder:Needs"]?.pageCapacity, 256)
        XCTAssertEqual(source.settings.phraseCardEmptySlots["folder:Needs"], Array(0..<20))
        XCTAssertTrue(source.renamePhraseFolder("Needs", to: "My needs"))
        XCTAssertNil(source.settings.phraseCardGridLayouts["folder:Needs"])
        XCTAssertNil(source.settings.phraseCardEmptySlots["folder:Needs"])
        XCTAssertEqual(source.settings.phraseCardGridLayouts["folder:My needs"],
                       BoardGridLayout(columns: 16, rows: 16))
        XCTAssertEqual(source.settings.phraseCardEmptySlots["folder:My needs"], Array(0..<20))
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL)
            .settings.phraseCardGridLayouts["folder:My needs"]?.pageCapacity, 256)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.settings.phraseCardGridLayouts["folder:My needs"]?.pageCapacity, 256)
        XCTAssertEqual(restored.settings.phraseCardEmptySlots["folder:My needs"], Array(0..<20))
        XCTAssertEqual(restored.settings.phraseCardGridLayouts["quick"],
                       BoardGridLayout(columns: 2, rows: 3))
    }

    func testOlderSettingsDecodeWithoutPhraseCardGrid() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(old.phraseCardGridLayouts.isEmpty)
        XCTAssertTrue(old.phraseCardEmptySlots.isEmpty)
        let oversized = try JSONDecoder().decode(AppSettings.self, from: Data(
            #"{"phraseCardGridLayouts":{"all":{"columns":99,"rows":99}},"phraseCardEmptySlots":{"all":[1,1,-1,10000]}}"#.utf8))
        XCTAssertEqual(oversized.phraseCardGridLayouts["all"],
                       BoardGridLayout(columns: 16, rows: 16))
        XCTAssertEqual(oversized.phraseCardEmptySlots["all"], [1])
    }

    @MainActor
    func testPhraseCardsMoveToEmptyCellsAndSwapWithinTheirFolder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        for text in ["First", "Second", "Third"] { source.addPhrase(text, folder: "Needs") }
        source.setPhraseCardGridLayout(BoardGridLayout(columns: 2, rows: 2), for: "folder:Needs")
        let second = try XCTUnwrap(source.phrases.first { $0.text == "Second" && $0.folder == "Needs" })
        let first = try XCTUnwrap(source.phrases.first { $0.text == "First" && $0.folder == "Needs" })
        XCTAssertFalse(source.movePhraseCard(second, to: 10_000, in: "folder:Needs"))
        XCTAssertFalse(source.movePhraseCard(second, to: 1, in: "quick"))
        XCTAssertTrue(source.movePhraseCard(second, to: 5, in: "folder:Needs"))
        func slots() -> [String?] {
            PhraseCardSlotLayout.slots(for: source.phrases.filter { $0.folder == "Needs" },
                emptyPositions: Set(source.settings.phraseCardEmptySlots["folder:Needs"] ?? []))
                .map { $0?.text }
        }
        XCTAssertEqual(slots(), ["First", nil, "Third", nil, nil, "Second"])
        XCTAssertTrue(source.movePhraseCard(first, to: 2, in: "folder:Needs"))
        XCTAssertEqual(slots(), ["Third", nil, "First", nil, nil, "Second"])
        XCTAssertTrue(source.movePhraseCard(second, to: 1, in: "folder:Needs"))
        XCTAssertEqual(slots(), ["Third", "Second", "First"])
        XCTAssertEqual(source.settings.phraseCardEmptySlots["folder:Needs"], [])
    }
}
