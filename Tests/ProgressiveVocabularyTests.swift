import XCTest
@testable import OpenVoice

final class ProgressiveVocabularyTests: XCTestCase {
    func testStagesRevealMoreStarterWordsWithoutChangingSlots() throws {
        let core = StarterVocabulary.items.filter { $0.category == "Core" }
        let start = core.map { ProgressiveVocabulary.displayed($0, stage: .start) }
        let grow = core.map { ProgressiveVocabulary.displayed($0, stage: .grow) }
        let all = core.map { ProgressiveVocabulary.displayed($0, stage: .all) }

        XCTAssertEqual(start.map(\.id), core.map(\.id))
        XCTAssertEqual(grow.map(\.id), core.map(\.id))
        XCTAssertEqual(all.map(\.id), core.map(\.id))
        XCTAssertEqual(start.count, grow.count)
        XCTAssertTrue(start.contains { $0.label == "I" && $0.boardVisibility == .shown })
        XCTAssertTrue(start.contains { $0.label == "there" && $0.boardVisibility == .hidden })
        XCTAssertTrue(grow.contains { $0.label == "there" && $0.boardVisibility == .hidden })
        XCTAssertTrue(all.contains { $0.label == "there" && $0.boardVisibility == .shown })
        XCTAssertGreaterThan(grow.filter { $0.boardVisibility == .shown }.count,
                             start.filter { $0.boardVisibility == .shown }.count)
        XCTAssertEqual(core.first { $0.label == "there" }?.boardVisibility, .shown)
    }

    func testPersonalFavoriteAndExploreAccessWhileManualHidingWins() throws {
        let later = try XCTUnwrap(StarterVocabulary.items.first { $0.category == "Core" && $0.label == "there" })
        var personal = later
        personal.isCustom = true
        XCTAssertTrue(ProgressiveVocabulary.isAvailable(personal, stage: .start))
        personal.isCustom = false
        personal.isFavorite = true
        XCTAssertTrue(ProgressiveVocabulary.isAvailable(personal, stage: .start))
        XCTAssertTrue(ProgressiveVocabulary.isAvailable(later, stage: .start, exploring: true))
        personal.visibility = .hidden
        XCTAssertFalse(ProgressiveVocabulary.isAvailable(personal, stage: .start, exploring: true))
        XCTAssertEqual(ProgressiveVocabulary.displayed(personal, stage: .all).boardVisibility, .hidden)
    }

    @MainActor
    func testStageDefaultsOffAndPersistsWithProfileAndBackup() throws {
        let legacy = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(legacy.progressiveVocabularyStage, .off)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        source.settings.progressiveVocabularyStage = .grow
        let firstID = source.activeProfileID
        XCTAssertTrue(source.addProfile("Other communicator"))
        XCTAssertEqual(source.settings.progressiveVocabularyStage, .off)
        XCTAssertTrue(source.switchProfile(to: firstID))
        XCTAssertEqual(source.settings.progressiveVocabularyStage, .grow)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.settings.progressiveVocabularyStage, .grow)
    }
}
