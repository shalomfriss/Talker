import Foundation
import XCTest
@testable import OpenVoice

final class OpenBoardFormatTests: XCTestCase {
    func testSixteenBySixteenBoardPageSizeRoundTrips() throws {
        let layout = BoardGridLayout(columns: 16, rows: 16)
        let item = CommunicationItem(label: "Yes", symbol: "●", message: "Yes", category: "Choices")
        let data = try OpenBoardFormat.exportBoard(name: "Choices", items: [item],
                                                   language: "en", layout: layout)
        let board = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(board["ext_openvoice_page_columns"] as? Int, 16)
        XCTAssertEqual(board["ext_openvoice_page_rows"] as? Int, 16)
        XCTAssertEqual(try OpenBoardFormat.importData(data, fileExtension: "obf").layouts["Choices"], layout)
    }

    @MainActor
    func testEmptyGridCellsAndPageSizeRoundTripThroughBoardAndArchive() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let items = ["One", "Two", "Three"].map {
            CommunicationItem(label: $0, symbol: "●", message: $0, category: "Choices")
        }
        let layout = BoardGridLayout(columns: 2, rows: 2)
        let spaces: Set<Int> = [1, 3, 4]
        let boardData = try OpenBoardFormat.exportBoard(name: "Choices", items: items, language: "en",
                                                        layout: layout, emptyPositions: spaces)
        let board = try XCTUnwrap(JSONSerialization.jsonObject(with: boardData) as? [String: Any])
        let grid = try XCTUnwrap(board["grid"] as? [String: Any])
        let order = try XCTUnwrap(grid["order"] as? [[Any]])
        XCTAssertEqual(grid["columns"] as? Int, 2)
        XCTAssertEqual(grid["rows"] as? Int, 3)
        XCTAssertTrue(order[0][1] is NSNull)
        XCTAssertTrue(order[1][1] is NSNull)
        XCTAssertTrue(order[2][0] is NSNull)
        XCTAssertEqual(order[2][1] as? String, items[2].id.uuidString)
        XCTAssertEqual(board["ext_openvoice_page_columns"] as? Int, 2)
        XCTAssertEqual(board["ext_openvoice_page_rows"] as? Int, 2)

        let imported = try OpenBoardFormat.importData(boardData, fileExtension: "obf")
        XCTAssertEqual(imported.items.map(\.label), ["One", "Two", "Three"])
        XCTAssertEqual(imported.layouts["Choices"], layout)
        XCTAssertEqual(imported.emptyPositions["Choices"], [1, 3, 4])

        let archive = try OpenBoardFormat.exportArchive(profileName: "Test", categories: ["Choices"],
                                                         items: items, language: "en",
                                                         layouts: ["Choices": layout],
                                                         emptyPositions: ["Choices": spaces.sorted()])
        let fromArchive = try OpenBoardFormat.importData(archive, fileExtension: "obz")
        XCTAssertEqual(fromArchive.layouts["Choices"], layout)
        XCTAssertEqual(fromArchive.emptyPositions["Choices"], [1, 3, 4])

        let file = directory.appendingPathComponent("import.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.addBoard("Choices"))
        store.addOpenBoards(imported)
        let importedName = "Choices (imported 2)"
        XCTAssertEqual(store.gridLayout(for: importedName), layout)
        XCTAssertEqual(store.gridSlots(in: importedName).map { $0?.label },
                       ["One", nil, "Two", nil, nil, "Three"])
        XCTAssertEqual(CommunicationStore(storageURL: file).gridSlots(in: importedName).map { $0?.label },
                       ["One", nil, "Two", nil, nil, "Three"])
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restore.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.gridSlots(in: importedName).map { $0?.label },
                       ["One", nil, "Two", nil, nil, "Three"])
        let selectedFile = directory.appendingPathComponent("selected.json")
        let selected = CommunicationStore(storageURL: selectedFile)
        let importedNames = try selected.addBoards(fromBackup: store.backupData(),
                                                    selectedBoards: [importedName])
        let copiedName = try XCTUnwrap(importedNames.first)
        XCTAssertEqual(selected.gridLayout(for: copiedName), layout)
        XCTAssertEqual(selected.gridSlots(in: copiedName).map { $0?.label },
                       ["One", nil, "Two", nil, nil, "Three"])
        XCTAssertEqual(CommunicationStore(storageURL: selectedFile).gridSlots(in: copiedName).map { $0?.label },
                       ["One", nil, "Two", nil, nil, "Three"])
    }

    func testVideoButtonRoundTripsThroughBoardAndArchive() throws {
        let clip = Data([0, 1, 2, 3])
        let poster = Data([4, 5, 6])
        let item = CommunicationItem(label: "Watch slide", symbol: "▶️", message: "Watch slide",
                                     category: "Core", videoData: clip, videoPosterData: poster,
                                     isCustom: true, action: .playVideo)
        let board = try OpenBoardFormat.exportBoard(name: "Core", items: [item], language: "en")
        let importedBoard = try OpenBoardFormat.importData(board, fileExtension: "obf")
        XCTAssertEqual(importedBoard.items.first?.effectiveAction, .playVideo)
        XCTAssertEqual(importedBoard.items.first?.videoData, clip)
        XCTAssertEqual(importedBoard.items.first?.videoPosterData, poster)

        let archive = try OpenBoardFormat.exportArchive(profileName: "Test", categories: ["Core"],
                                                         items: [item], language: "en")
        let importedArchive = try OpenBoardFormat.importData(archive, fileExtension: "obz")
        XCTAssertEqual(importedArchive.items.first { $0.label == "Watch slide" }?.videoData, clip)

        var malformed = try XCTUnwrap(JSONSerialization.jsonObject(with: board) as? [String: Any])
        var buttons = try XCTUnwrap(malformed["buttons"] as? [[String: Any]])
        buttons[0].removeValue(forKey: "ext_openvoice_video_poster_data")
        malformed["buttons"] = buttons
        let rejected = try OpenBoardFormat.importData(JSONSerialization.data(withJSONObject: malformed),
                                                       fileExtension: "obf")
        XCTAssertTrue(rejected.items.isEmpty)
        XCTAssertEqual(rejected.missingMedia, 1)
    }

    func testButtonColorsNormalizeAndChooseReadableText() {
        XCTAssertEqual(ButtonColorValue(text: "#abc")?.hex, "#AABBCC")
        XCTAssertEqual(ButtonColorValue(text: "#1234")?.hex, "#11223344")
        XCTAssertEqual(ButtonColorValue(text: "rgb(12, 34, 56)")?.hex, "#0C2238")
        XCTAssertEqual(ButtonColorValue(text: "rgba(33, 66, 99, 0.5)")?.hex, "#21426380")
        XCTAssertNil(ButtonColorValue(text: "rgb(300, 0, 0)"))
        XCTAssertNil(ButtonColorValue(text: "#not-a-color"))
        XCTAssertEqual(ButtonColorValue(text: "#FFFFFF")?.prefersDarkText, true)
        XCTAssertEqual(ButtonColorValue(text: "#101030")?.prefersDarkText, false)
        XCTAssertEqual(ButtonColorValue(text: "#10103011")?.prefersDarkText, true)
    }

    func testButtonColorsRoundTripThroughStandardOpenBoardFields() throws {
        let item = CommunicationItem(label: "Wait", symbol: "✋", message: "Please wait",
                                     category: "Core", isCustom: true,
                                     backgroundColorHex: "#102A6B", borderColorHex: "#FFE082")
        let data = try OpenBoardFormat.exportBoard(name: "Core", items: [item], language: "en")
        var board = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var buttons = try XCTUnwrap(board["buttons"] as? [[String: Any]])
        XCTAssertEqual(buttons[0]["background_color"] as? String, "#102A6B")
        XCTAssertEqual(buttons[0]["border_color"] as? String, "#FFE082")
        let imported = try OpenBoardFormat.importData(data, fileExtension: "obf")
        XCTAssertEqual(imported.items.first?.backgroundColorHex, "#102A6B")
        XCTAssertEqual(imported.items.first?.borderColorHex, "#FFE082")

        buttons[0]["background_color"] = "rgb(12, 34, 56)"
        buttons[0]["border_color"] = "rgba(255, 0, 0, 0.5)"
        board["buttons"] = buttons
        let styled = try OpenBoardFormat.importData(JSONSerialization.data(withJSONObject: board),
                                                     fileExtension: "obf")
        XCTAssertEqual(styled.items.first?.backgroundColorHex, "#0C2238")
        XCTAssertEqual(styled.items.first?.borderColorHex, "#FF000080")
    }

    func testActionButtonsRoundTripThroughOpenBoardFormat() throws {
        let actions: [(String, ButtonAction)] = [
            ("Wait", .speakImmediately), ("Clock", .speakCurrentTime), ("Say", .speakMessage),
            ("Clear", .clearMessage), ("Stop", .stopSpeaking),
            ("Restore", .undoClearMessage), ("Delete", .deleteLastEntry),
            ("Back", .backBoard), ("Home", .homeBoard)
        ]
        let items = actions.map { label, action in
            CommunicationItem(label: label, symbol: "💬", message: label, category: "Core",
                              isCustom: true, action: action)
        }
        let data = try OpenBoardFormat.exportBoard(name: "Core", items: items, language: "en")
        let board = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let buttons = try XCTUnwrap(board["buttons"] as? [[String: Any]])
        XCTAssertEqual(buttons.first { $0["label"] as? String == "Say" }?["action"] as? String, ":speak")
        XCTAssertEqual(buttons.first { $0["label"] as? String == "Clear" }?["action"] as? String, ":clear")
        XCTAssertEqual(buttons.first { $0["label"] as? String == "Wait" }?["ext_openvoice_action"] as? String,
                       ButtonAction.speakImmediately.rawValue)
        XCTAssertEqual(buttons.first { $0["label"] as? String == "Clock" }?["ext_openvoice_action"] as? String,
                       ButtonAction.speakCurrentTime.rawValue)

        let imported = try OpenBoardFormat.importData(data, fileExtension: "obf")
        XCTAssertEqual(imported.skippedActions, 0)
        XCTAssertEqual(imported.items.map(\.effectiveAction), actions.map(\.1))

        var standardOnly = board
        standardOnly["buttons"] = buttons.map { button -> [String: Any] in
            var copy = button
            copy.removeValue(forKey: "ext_openvoice_action")
            return copy
        }
        let standardData = try JSONSerialization.data(withJSONObject: standardOnly)
        let standardImport = try OpenBoardFormat.importData(standardData, fileExtension: "obf")
        XCTAssertEqual(standardImport.items.first { $0.label == "Say" }?.effectiveAction, .speakMessage)
        XCTAssertEqual(standardImport.items.first { $0.label == "Clear" }?.effectiveAction, .clearMessage)
    }

    private func fixture(_ name: String, extension ext: String) throws -> Data {
        let bundle = Bundle(for: OpenBoardFormatTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: ext)
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func testOfficialSingleBoardImportsNumericGridIDs() throws {
        let imported = try OpenBoardFormat.importData(fixture("openboard-simple", extension: "obf"),
                                                       fileExtension: "obf")
        XCTAssertEqual(imported.categories, ["Simple Board"])
        XCTAssertEqual(imported.items.map(\.label), ["happy", "sad"])
        XCTAssertTrue(imported.items.allSatisfy { $0.category == "Simple Board" })
    }

    func testExternalGridOrderPreservesAnInternalEmptyCell() throws {
        let data = Data(#"{"format":"open-board-0.1","id":"external","name":"External","buttons":[{"id":"b","label":"Second"},{"id":"a","label":"First"}],"grid":{"rows":2,"columns":2,"order":[["a",null],["b",null]]}}"#.utf8)
        let imported = try OpenBoardFormat.importData(data, fileExtension: "obf")
        XCTAssertEqual(imported.items.map(\.label), ["First", "Second"])
        XCTAssertEqual(imported.layouts["External"], BoardGridLayout(columns: 2, rows: 2))
        XCTAssertEqual(imported.emptyPositions["External"], [1])
    }

    func testOfficialLinkedArchiveResolvesBoardPaths() throws {
        let imported = try OpenBoardFormat.importData(fixture("openboard-links", extension: "obz"),
                                                       fileExtension: "obz")
        XCTAssertEqual(imported.categories, ["Simple Board", "Simple Board 2", "Simple Board 3"])
        XCTAssertEqual(imported.items.first(where: { $0.label == "feelings" })?.destinationBoard,
                       "Simple Board 2")
        XCTAssertEqual(imported.items.first(where: { $0.label == "colors" })?.destinationBoard,
                       "Simple Board 3")
        XCTAssertEqual(imported.missingLinks, 0)
    }

    func testOfficialMediaArchiveLoadsPhotosAndAudio() throws {
        let imported = try OpenBoardFormat.importData(fixture("openboard-media", extension: "obz"),
                                                       fileExtension: "obz")
        let happy = try XCTUnwrap(imported.items.first(where: { $0.label == "happy" }))
        XCTAssertTrue((happy.imageData?.count ?? 0) > 100)
        XCTAssertTrue((happy.audioData?.count ?? 0) > 100)
        XCTAssertNotNil(happy.destinationBoard)
        XCTAssertEqual(imported.missingMedia, 0)
    }

    func testArchiveRoundTripsLinkedBoardsAndMedia() throws {
        let photo = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])
        let recording = Data([0x63, 0x61, 0x66, 0x66, 1, 2, 3])
        let items = [
            CommunicationItem(label: "Drinks", symbol: "🥤", message: "Drinks", category: "Core",
                              destinationBoard: "Drinks", linkBehavior: .visit),
            CommunicationItem(label: "Water", symbol: "💧", message: "I want water", category: "Drinks",
                              isFavorite: true, imageData: photo, audioData: recording)
        ]
        let archive = try OpenBoardFormat.exportArchive(profileName: "Alex", categories: ["Core", "Drinks"],
                                                         items: items, language: "en")
        let imported = try OpenBoardFormat.importData(archive, fileExtension: "obz")
        XCTAssertEqual(imported.items.first(where: { $0.label == "Drinks" && $0.category == "Core" })?.destinationBoard,
                       "Drinks")
        let water = try XCTUnwrap(imported.items.first(where: { $0.label == "Water" }))
        XCTAssertEqual(water.message, "I want water")
        XCTAssertTrue(water.isFavorite)
        XCTAssertEqual(water.imageData, photo)
        XCTAssertEqual(water.audioData, recording)
    }

    func testSingleBoardExportKeepsButtonsWhenTheirLinksAreUnavailable() throws {
        let link = CommunicationItem(label: "Drinks", symbol: "🥤", message: "Drinks", category: "Core",
                                     destinationBoard: "Drinks", linkBehavior: .visit)
        let board = try OpenBoardFormat.exportBoard(name: "Core", items: [link], language: "en")
        let imported = try OpenBoardFormat.importData(board, fileExtension: "obf")
        XCTAssertEqual(imported.items.map(\.label), ["Drinks"])
        XCTAssertNil(imported.items[0].destinationBoard)
    }

    func testLargeBoardAndEmptyBoardRemainImportable() throws {
        let words = (0..<401).map { index in
            CommunicationItem(label: "Word \(index)", symbol: "text.bubble",
                              message: "Word \(index)", category: "Large")
        }
        let large = try OpenBoardFormat.exportBoard(name: "Large", items: words, language: "en")
        XCTAssertEqual(try OpenBoardFormat.importData(large, fileExtension: "obf").items.count, 401)

        let empty = try OpenBoardFormat.exportBoard(name: "New board", items: [], language: "en")
        let imported = try OpenBoardFormat.importData(empty, fileExtension: "obf")
        XCTAssertEqual(imported.categories, ["New board"])
        XCTAssertTrue(imported.items.isEmpty)
    }

    @MainActor
    func testImportMergesIntoCurrentProfileWithoutReplacingExistingWords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        store.addItem(label: "My existing word", symbol: "✨", message: "Mine", category: "Core", imageData: nil)
        let originalCount = store.items.count
        let imported = try OpenBoardFormat.importData(fixture("openboard-simple", extension: "obf"),
                                                       fileExtension: "obf")
        store.addOpenBoards(imported)
        store.addOpenBoards(imported)
        XCTAssertEqual(store.items.count, originalCount + 4)
        XCTAssertTrue(store.items.contains { $0.label == "My existing word" && $0.category == "Core" })
        XCTAssertTrue(store.categories.contains("Simple Board"))
        XCTAssertTrue(store.categories.contains("Simple Board (imported 2)"))
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("source.json")).items.count,
                       originalCount + 4)
    }

    func testInvalidBoardDoesNotImport() throws {
        let invalid = Data("{\"format\":\"open-board-0.1\",\"id\":\"x\",\"name\":\"Bad\",\"buttons\":[],\"grid\":{\"rows\":2,\"columns\":2,\"order\":[[null]]}}".utf8)
        XCTAssertThrowsError(try OpenBoardFormat.importData(invalid, fileExtension: "obf"))
    }
}
