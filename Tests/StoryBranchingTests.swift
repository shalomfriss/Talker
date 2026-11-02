import PDFKit
import XCTest
@testable import OpenVoice

final class StoryBranchingTests: XCTestCase {
    func testOlderPagesDecodeWithoutChoicesAndLabelsAreCleaned() throws {
        let page = try JSONDecoder().decode(StoryPage.self,
            from: Data(#"{"text":"I can choose."}"#.utf8))
        XCTAssertTrue(page.choices.isEmpty)

        let target = UUID()
        let first = StoryChoice(label: "  Go outside  ", targetPageID: target)
        let duplicate = StoryChoice(id: first.id, label: "Again", targetPageID: target)
        let invalid = StoryChoice(label: "Missing", targetPageID: UUID())
        XCTAssertEqual(StoryChoice.cleaned([first, duplicate, invalid], validTargets: [target]),
                       [StoryChoice(id: first.id, label: "Go outside", targetPageID: target)])
    }

    func testStoryTransferRemapsChoiceTargetsAndRejectsBrokenLinks() throws {
        let first = StoryPage(text: "What will I do?")
        let third = StoryPage(text: "I can visit the park.")
        var decision = first
        decision.choices = [StoryChoice(label: "Visit the park", targetPageID: third.id)]
        let story = VisualStory(title: "My choices", pages: [decision, StoryPage(text: "Stay home"), third])
        XCTAssertTrue(story.shareText.contains("Visit the park → page 3"))
        let document = try XCTUnwrap(PDFDocument(data: PrintableStoryPDF.makeData(story: story)))
        XCTAssertTrue(document.page(at: 0)?.string?.contains("Visit the park") == true)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("page 3") == true)
        let imported = try StoryTransfer.importStory(StoryTransfer.exportData(story))
        XCTAssertNotEqual(imported.id, story.id)
        XCTAssertNotEqual(imported.pages[2].id, story.pages[2].id)
        XCTAssertEqual(imported.pages[0].choices.first?.targetPageID, imported.pages[2].id)
        XCTAssertNotEqual(imported.pages[0].choices.first?.id, story.pages[0].choices.first?.id)

        decision.choices = [StoryChoice(label: "Missing", targetPageID: UUID())]
        XCTAssertThrowsError(try StoryTransfer.exportData(
            VisualStory(title: "Broken", pages: [decision, third])))
    }

    @MainActor
    func testChoicesSurviveRelaunchProfileAndBackupAndDeletedTargetsAreRemoved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("story.json")
        let store = CommunicationStore(storageURL: file)
        let storyID = try XCTUnwrap(store.addStory("My decision"))
        store.addStoryPage(storyID: storyID, text: "Where shall I go?", symbol: "🤔", imageData: nil)
        store.addStoryPage(storyID: storyID, text: "I can stay home.", symbol: "🏠", imageData: nil)
        store.addStoryPage(storyID: storyID, text: "I can go outside.", symbol: "🌳", imageData: nil)
        var pages = try XCTUnwrap(store.stories.first { $0.id == storyID }?.pages)
        pages[0].choices = [StoryChoice(label: "  Outside  ", targetPageID: pages[2].id),
                            StoryChoice(label: "Invalid", targetPageID: UUID())]
        store.updateStoryPage(storyID: storyID, page: pages[0])
        XCTAssertEqual(store.stories.first { $0.id == storyID }?.pages[0].choices.map(\.label), ["Outside"])
        let targetID = pages[2].id
        XCTAssertEqual(CommunicationStore(storageURL: file).stories.first { $0.id == storyID }?
            .pages[0].choices.first?.targetPageID, targetID)

        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another reader"))
        XCTAssertFalse(store.stories.contains { $0.id == storyID })
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.stories.first { $0.id == storyID }?.pages[0].choices.first?.targetPageID, targetID)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.stories.first { $0.id == storyID }?.pages[0].choices.first?.targetPageID,
                       targetID)

        store.deleteStoryPage(storyID: storyID, pageID: targetID)
        XCTAssertTrue(store.stories.first { $0.id == storyID }?.pages[0].choices.isEmpty == true)
    }
}
