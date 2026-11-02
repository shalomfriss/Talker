import AVFoundation
import XCTest
@testable import OpenVoice

final class SpeechHighlightTests: XCTestCase {
    @MainActor
    func testPictureMessageStartsFollowAlongWithoutChangingItsDraft() {
        let store = CommunicationStore(storageURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-highlight-\(UUID()).json"))
        let message = "Please give me a quiet moment to explain what I need."
        store.selectPhrase(CardPhrase(text: message))
        store.speakMessage()
        XCTAssertEqual(store.composedMessage, message)
        XCTAssertEqual(store.speechHighlight?.source, .picture)
        XCTAssertEqual(store.speechHighlight?.text, message)
        store.stopSpeaking()
        XCTAssertNil(store.speechHighlight)
    }

    @MainActor
    func testWordRangesFollowUtteranceSegmentsAndStopAtTheEnd() throws {
        let store = CommunicationStore(storageURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-highlight-\(UUID()).json"))
        let first = AVSpeechUtterance(string: "Hello 👋")
        let second = AVSpeechUtterance(string: "mundo")
        store.beginSpeechHighlight([first, second], source: .picture)
        XCTAssertEqual(store.speechHighlight?.text, "Hello 👋 mundo")

        store.updateSpeechHighlight(for: ObjectIdentifier(first), range: NSRange(location: 6, length: 2))
        let firstState = try XCTUnwrap(store.speechHighlight)
        XCTAssertEqual((firstState.text as NSString).substring(with: try XCTUnwrap(firstState.range)), "👋")
        XCTAssertEqual(firstState.currentUnit, "👋")
        store.updateSpeechHighlight(for: ObjectIdentifier(second), range: NSRange(location: 0, length: 5))
        let secondState = try XCTUnwrap(store.speechHighlight)
        XCTAssertEqual((secondState.text as NSString).substring(with: try XCTUnwrap(secondState.range)), "mundo")
        XCTAssertEqual(secondState.currentUnit, "mundo")

        store.finishSpeechHighlight(for: ObjectIdentifier(first))
        XCTAssertNotNil(store.speechHighlight)
        store.finishSpeechHighlight(for: ObjectIdentifier(second))
        XCTAssertNil(store.speechHighlight)
    }

    @MainActor
    func testInvalidAndStoppedCallbacksCannotHighlightAnotherMessage() {
        let store = CommunicationStore(storageURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-highlight-\(UUID()).json"))
        let first = AVSpeechUtterance(string: "First")
        store.beginSpeechHighlight([first], source: .typed)
        store.updateSpeechHighlight(for: ObjectIdentifier(first), range: NSRange(location: 4, length: 8))
        XCTAssertNil(store.speechHighlight?.range)
        store.stopSpeaking()
        XCTAssertNil(store.speechHighlight)

        let second = AVSpeechUtterance(string: "Second")
        store.beginSpeechHighlight([second], source: .typed)
        store.updateSpeechHighlight(for: ObjectIdentifier(first), range: NSRange(location: 0, length: 5))
        store.finishSpeechHighlight(for: ObjectIdentifier(first))
        XCTAssertEqual(store.speechHighlight?.text, "Second")
        XCTAssertNil(store.speechHighlight?.range)
    }

    @MainActor
    func testStoryReadingTracksTheCurrentPageWithoutChangingTheMessageDraft() throws {
        let store = CommunicationStore(storageURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("story-highlight-\(UUID()).json"))
        let storyID = try XCTUnwrap(store.addStory("My day"))
        store.addStoryPage(storyID: storyID, text: "I went to the park.", symbol: "🌳",
                           imageData: nil)
        store.addStoryPage(storyID: storyID, text: "Then I came home.", symbol: "🏠",
                           imageData: nil)
        let pages = try XCTUnwrap(store.stories.first { $0.id == storyID }?.pages)
        XCTAssertEqual(pages.count, 2)
        store.readStoryPage(storyID: storyID, pageID: pages[0].id)
        XCTAssertEqual(store.speechHighlight?.source,
                       .story(storyID: storyID, pageID: pages[0].id))
        XCTAssertEqual(store.speechHighlight?.text, pages[0].text)
        XCTAssertTrue(store.composedMessage.isEmpty)

        store.readStoryPage(storyID: storyID, pageID: pages[1].id)
        XCTAssertEqual(store.speechHighlight?.source,
                       .story(storyID: storyID, pageID: pages[1].id))
        XCTAssertEqual(store.speechHighlight?.text, pages[1].text)
        store.stopSpeaking()
        XCTAssertNil(store.speechHighlight)
    }
}
