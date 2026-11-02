import XCTest
@testable import OpenVoice

final class RecentPictureWordsTests: XCTestCase {
    func testOldSettingsDoNotRecordRecentPictureWords() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{\"speechRate\":0.5}".utf8))
        XCTAssertFalse(old.recentPictureWordsEnabled)
        XCTAssertFalse(old.highlightRecentPictureWords)
        XCTAssertTrue(old.recentPictureWordIDs.isEmpty)
        XCTAssertFalse(old.highlightWordsForTimeOfDay)
        XCTAssertTrue(old.timeOfDayWordUses.isEmpty)
    }

    func testTimeOfDayLearningUsesFourPeriodsAndBoundsHistory() {
        XCTAssertEqual([4, 5, 11, 12, 16, 17, 21, 22, 23, 0].compactMap(TimeOfDayWordUse.bucket),
                       [3, 0, 0, 1, 1, 2, 2, 3, 3, 3])
        XCTAssertNil(TimeOfDayWordUse.bucket(for: 24))
        let id = UUID()
        var uses: [TimeOfDayWordUse] = []
        uses = TimeOfDayWordUse.recording(id, at: 8, in: uses)
        uses = TimeOfDayWordUse.recording(id, at: 8, in: uses)
        XCTAssertEqual(uses[0].count(at: 8), 2)
        XCTAssertEqual(uses[0].count(at: 14), 0)
        for _ in 0..<300 { uses = TimeOfDayWordUse.recording(UUID(), at: 8, in: uses) }
        XCTAssertEqual(uses.count, TimeOfDayWordUse.maximumWords)
    }

    @MainActor
    func testTimeOfDayHighlightsStayOnOriginalBoardAndWithProfileBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("time.json")
        let store = CommunicationStore(storageURL: file)
        let words = store.items.filter { $0.category == "Core" && $0.effectiveAction == .addToMessage }
        XCTAssertGreaterThanOrEqual(words.count, 3)
        let selected = Array(words.prefix(3))
        let originalOrder = store.items.filter { $0.category == "Core" }.map(\.id)
        store.settings.highlightWordsForTimeOfDay = true
        store.settings.timeOfDayWordUses = [
            TimeOfDayWordUse(itemID: selected[0].id, counts: [2, 0, 0, 0]),
            TimeOfDayWordUse(itemID: selected[1].id, counts: [3, 0, 0, 0]),
            TimeOfDayWordUse(itemID: selected[2].id, counts: [4, 0, 0, 0])
        ]
        XCTAssertEqual(store.timeOfDayHighlightIDs(for: "Core", hour: 8),
                       Set([selected[1].id, selected[2].id]))
        XCTAssertTrue(store.timeOfDayHighlightIDs(for: "Core", hour: 14).isEmpty)
        XCTAssertTrue(store.timeOfDayHighlightIDs(for: "Food", hour: 8).isEmpty)
        XCTAssertEqual(store.items.filter { $0.category == "Core" }.map(\.id), originalOrder)

        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another person"))
        XCTAssertFalse(store.settings.highlightWordsForTimeOfDay)
        XCTAssertTrue(store.settings.timeOfDayWordUses.isEmpty)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertEqual(store.timeOfDayHighlightIDs(for: "Core", hour: 8),
                       Set([selected[1].id, selected[2].id]))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restore.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.timeOfDayHighlightIDs(for: "Core", hour: 8),
                       Set([selected[1].id, selected[2].id]))
        store.clearTimeOfDayWordUses()
        XCTAssertTrue(store.timeOfDayHighlightIDs(for: "Core", hour: 8).isEmpty)
    }

    @MainActor
    func testRecentHighlightsTrackWithoutRecentBoardAndStayWithProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("highlights.json")
        let store = CommunicationStore(storageURL: file)
        let words = Array(store.items.prefix(5))
        store.settings.highlightRecentPictureWords = true
        words.prefix(4).forEach(store.select)
        XCTAssertFalse(store.settings.recentPictureWordsEnabled)
        XCTAssertTrue(store.recentPictureItems.isEmpty)
        XCTAssertEqual(store.recentPictureHighlightIDs, Set(words[1...3].map(\.id)))

        let firstProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another person"))
        XCTAssertFalse(store.settings.highlightRecentPictureWords)
        XCTAssertTrue(store.recentPictureHighlightIDs.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.recentPictureHighlightIDs, Set(words[1...3].map(\.id)))
        XCTAssertEqual(CommunicationStore(storageURL: file).recentPictureHighlightIDs,
                       Set(words[1...3].map(\.id)))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.recentPictureHighlightIDs, Set(words[1...3].map(\.id)))

        store.settings.highlightRecentPictureWords = false
        store.select(words[4])
        XCTAssertFalse(store.settings.recentPictureWordIDs.contains(words[4].id))
        store.clearRecentPictureWords()
        XCTAssertTrue(store.settings.recentPictureWordIDs.isEmpty)
    }

    @MainActor
    func testRecentBoardRecordsChosenWordsOnlyAndKeepsMostRecentTwelve() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("words.json"))
        let words = Array(store.items.prefix(13))
        store.select(words[0])
        XCTAssertTrue(store.settings.recentPictureWordIDs.isEmpty)

        store.settings.recentPictureWordsEnabled = true
        words.forEach(store.select)
        XCTAssertEqual(store.settings.recentPictureWordIDs, words.reversed().prefix(12).map(\.id))
        XCTAssertEqual(store.recentPictureItems.map(\.id), words.reversed().prefix(12).map(\.id))

        store.select(words[3])
        XCTAssertEqual(store.settings.recentPictureWordIDs.first, words[3].id)
        XCTAssertEqual(Set(store.settings.recentPictureWordIDs).count, 12)
        var control = words[4]
        control.action = .clearMessage
        store.select(control)
        XCTAssertEqual(store.settings.recentPictureWordIDs.first, words[3].id)

        var hidden = words[3]
        hidden.visibility = .hidden
        store.updateItem(hidden)
        XCTAssertFalse(store.recentPictureItems.contains(where: { $0.id == hidden.id }))
        XCTAssertTrue(store.settings.recentPictureWordIDs.contains(hidden.id))

        store.settings.recentPictureWordsEnabled = false
        XCTAssertTrue(store.recentPictureItems.isEmpty)
        XCTAssertFalse(store.settings.recentPictureWordIDs.isEmpty)
        store.clearRecentPictureWords()
        XCTAssertTrue(store.settings.recentPictureWordIDs.isEmpty)
    }

    @MainActor
    func testRecentWordsStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let firstProfile = store.activeProfileID
        let word = store.items.first!
        store.settings.recentPictureWordsEnabled = true
        store.select(word)
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertFalse(store.settings.recentPictureWordsEnabled)
        XCTAssertTrue(store.settings.recentPictureWordIDs.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.recentPictureItems.map(\.id), [word.id])
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
            .recentPictureItems.map(\.id), [word.id])

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try imported.importBackup(store.backupData())
        XCTAssertTrue(imported.settings.recentPictureWordsEnabled)
        XCTAssertEqual(imported.recentPictureItems.map(\.id), [word.id])
    }
}
