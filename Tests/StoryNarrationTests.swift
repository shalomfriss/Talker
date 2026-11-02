import XCTest
@testable import OpenVoice

final class StoryNarrationTests: XCTestCase {
    func testOlderStoryPageDecodesWithoutNarration() throws {
        let id = UUID()
        let data = Data("{\"id\":\"\(id.uuidString)\",\"text\":\"I went to the park.\",\"symbol\":\"🌳\"}".utf8)
        let page = try JSONDecoder().decode(StoryPage.self, from: data)
        XCTAssertEqual(page.id, id)
        XCTAssertEqual(page.text, "I went to the park.")
        XCTAssertNil(page.audioData)
        XCTAssertNil(page.videoData)
        XCTAssertNil(page.videoPosterData)
    }

    @MainActor
    func testVideoPagePersistsAcrossEditProfileAndBackup() async throws {
        let clipURL = try XCTUnwrap(Bundle.main.url(forResource: "SceneSample", withExtension: "mov"))
        let prepared = try await SceneVideoProcessing.prepared(
            from: clipURL, byteLimit: SceneVideoProcessing.maxHotspotBytes)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("story.json")
        let store = CommunicationStore(storageURL: file)
        let storyID = try XCTUnwrap(store.addStory("My video story"))
        store.addStoryPage(storyID: storyID, text: "I can watch the bus arrive.", symbol: "🚌",
                           imageData: nil, videoData: prepared.video,
                           videoPosterData: prepared.poster)
        var page = try XCTUnwrap(store.stories.first { $0.id == storyID }?.pages.first)
        XCTAssertTrue(page.hasValidVideoMedia)
        XCTAssertEqual(CommunicationStore(storageURL: file).stories.first { $0.id == storyID }?
            .pages.first?.videoData, prepared.video)
        page.text = "The bus arrived."
        store.updateStoryPage(storyID: storyID, page: page)
        XCTAssertEqual(store.stories.first { $0.id == storyID }?.pages.first?.videoPosterData,
                       prepared.poster)

        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other storyteller"))
        XCTAssertFalse(store.stories.contains { $0.id == storyID })
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.stories.first { $0.id == storyID }?.pages.first?.videoData,
                       prepared.video)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.stories.first { $0.title == "My video story" }?.pages.first?.videoData,
                       prepared.video)
    }

    @MainActor
    func testVideoPageRequiresPoster() throws {
        let store = CommunicationStore(storageURL:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let storyID = try XCTUnwrap(store.addStory("Invalid video"))
        store.addStoryPage(storyID: storyID, text: "Watch", symbol: "▶️", imageData: nil,
                           videoData: Data([1]))
        XCTAssertTrue(store.stories.first { $0.id == storyID }?.pages.isEmpty == true)
    }

    @MainActor
    func testNarrationStaysWithStoryProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        let storyID = try XCTUnwrap(source.addStory("My day"))
        let narration = Data([1, 2, 3, 4, 5])
        source.addStoryPage(storyID: storyID, text: "I went to the park.", symbol: "🌳",
                            imageData: nil, audioData: narration)
        let page = try XCTUnwrap(source.stories.first { $0.id == storyID }?.pages.first)
        XCTAssertEqual(page.audioData, narration)
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).stories.first { $0.id == storyID }?.pages.first?.audioData,
                       narration)

        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Another storyteller"))
        XCTAssertFalse(source.stories.contains { $0.id == storyID })
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.stories.first { $0.id == storyID }?.pages.first?.audioData, narration)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.stories.first { $0.title == "My day" }?.pages.first?.audioData, narration)

        var edited = page
        edited.audioData = nil
        source.updateStoryPage(storyID: storyID, page: edited)
        XCTAssertNil(source.stories.first { $0.id == storyID }?.pages.first?.audioData)
    }

    @MainActor
    func testOneTapReadingSettingStaysWithItsProfileAndBackup() throws {
        XCTAssertFalse(try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8)).storyOneTapReading)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("story.json")
        let store = CommunicationStore(storageURL: file)
        store.settings.storyOneTapReading = true
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.storyOneTapReading)
        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Second reader"))
        XCTAssertFalse(store.settings.storyOneTapReading)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertTrue(store.settings.storyOneTapReading)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertTrue(restored.settings.storyOneTapReading)
    }

    @MainActor
    func testTwoSwitchReadingSettingIsPortableAndExcludesOneTap() throws {
        let defaults = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertFalse(defaults.storyTwoSwitchReading)
        var settings = AppSettings()
        settings.storyOneTapReading = true
        settings.storyTwoSwitchReading = true
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertTrue(decoded.storyTwoSwitchReading)
        XCTAssertFalse(decoded.storyOneTapReading)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("switch-story.json")
        let store = CommunicationStore(storageURL: file)
        store.settings.storyTwoSwitchReading = true
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.storyTwoSwitchReading)
        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other reader"))
        XCTAssertFalse(store.settings.storyTwoSwitchReading)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertTrue(restored.settings.storyTwoSwitchReading)
    }

    @MainActor
    func testSlideshowPauseDefaultsAndPersistsPerProfileAndBackup() throws {
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
            .storySlideshowPause, 1)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self,
            from: Data("{\"storySlideshowPause\":20}".utf8)).storySlideshowPause, 5)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("slideshow.json")
        let store = CommunicationStore(storageURL: file)
        store.settings.storySlideshowPause = 3
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.storySlideshowPause, 3)
        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Second reader"))
        XCTAssertEqual(store.settings.storySlideshowPause, 1)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertEqual(store.settings.storySlideshowPause, 3)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.storySlideshowPause, 3)
    }

    @MainActor
    func testRecordedStoryPlaybackCompletesAndStopCancels() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let store = CommunicationStore(storageURL: file)
        let storyID = try XCTUnwrap(store.addStory("Recorded slideshow"))
        let narration = try XCTUnwrap(ScanCueSound.wavData(for: .blip))
        store.addStoryPage(storyID: storyID, text: "First", symbol: "📖",
                           imageData: nil, audioData: narration)
        let pageID = try XCTUnwrap(store.stories.first { $0.id == storyID }?.pages.first?.id)
        let playbackID = try XCTUnwrap(store.readStoryPage(storyID: storyID, pageID: pageID))
        for _ in 0..<50 where store.completedStoryPlaybackID != playbackID {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(store.completedStoryPlaybackID, playbackID)
        let nextID = try XCTUnwrap(store.readStoryPage(storyID: storyID, pageID: pageID))
        XCTAssertEqual(store.activeStoryPlaybackID, nextID)
        store.stopSpeaking()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(store.activeStoryPlaybackID)
        XCTAssertNil(store.completedStoryPlaybackID)
    }

    @MainActor
    func testStoryFilePreservesPagesAndMediaAndImportsCopies() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("story-transfer.json")
        let store = CommunicationStore(storageURL: file)
        let videoURL = try XCTUnwrap(Bundle.main.url(forResource: "SceneSample", withExtension: "mov"))
        let video = try Data(contentsOf: videoURL)
        let narration = try XCTUnwrap(ScanCueSound.wavData(for: .blip))
        let source = VisualStory(title: "A visit", pages: [
            StoryPage(text: "I went to the park.", symbol: "🌳",
                      imageData: Data([1, 2, 3]), audioData: narration),
            StoryPage(text: "Then I watched the bus.", symbol: "🚌",
                      videoData: video, videoPosterData: Data([4, 5]))
        ])
        let exported = try StoryTransfer.exportData(source)
        let first = try store.importStory(exported)
        let second = try store.importStory(exported)
        XCTAssertEqual(first.title, "A visit")
        XCTAssertEqual(second.title, "A visit (imported 2)")
        XCTAssertNotEqual(first.id, source.id)
        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(first.pages.map(\.text), source.pages.map(\.text))
        XCTAssertNotEqual(first.pages[0].id, source.pages[0].id)
        XCTAssertNotEqual(second.pages[0].id, first.pages[0].id)
        XCTAssertEqual(first.pages[0].imageData, source.pages[0].imageData)
        XCTAssertEqual(first.pages[0].audioData, narration)
        XCTAssertEqual(first.pages[1].videoData, video)
        XCTAssertEqual(first.pages[1].videoPosterData, source.pages[1].videoPosterData)
        XCTAssertEqual(CommunicationStore(storageURL: file).stories.count, 2)

        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other reader"))
        XCTAssertTrue(store.stories.isEmpty)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertEqual(store.stories.count, 2)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.stories[0].pages[1].videoData, video)
    }

    @MainActor
    func testStoryFileRejectsInvalidFormatAndMediaWithoutChangingLibrary() throws {
        let store = CommunicationStore(storageURL:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let page = StoryPage(text: "My story", imageData: Data([1]))
        let source = VisualStory(title: "My day", pages: [page])
        let validData = try StoryTransfer.exportData(source)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: validData) as? [String: Any])
        object["format"] = "other.story"
        XCTAssertThrowsError(try store.importStory(JSONSerialization.data(withJSONObject: object)))
        object["format"] = "org.openvoice.visual-story"
        object["version"] = 2
        XCTAssertThrowsError(try store.importStory(JSONSerialization.data(withJSONObject: object)))

        let duplicate = VisualStory(title: "Duplicate", pages: [page, page])
        XCTAssertThrowsError(try StoryTransfer.exportData(duplicate))
        let brokenVideo = VisualStory(title: "Broken video", pages: [
            StoryPage(text: "Watch", videoData: Data([1]))
        ])
        XCTAssertThrowsError(try StoryTransfer.exportData(brokenVideo))
        let largePhoto = VisualStory(title: "Large photo", pages: [
            StoryPage(text: "See", imageData: Data(repeating: 1, count: 5 * 1_048_576 + 1))
        ])
        XCTAssertThrowsError(try StoryTransfer.exportData(largePhoto))
        XCTAssertTrue(store.stories.isEmpty)
    }
}
