import PDFKit
import UIKit
import XCTest
@testable import OpenVoice

final class StoryPhotoGridTests: XCTestCase {
    func testOlderPageHasNoExtraPhotosAndFourPhotoLimitIsValidated() throws {
        let page = try JSONDecoder().decode(StoryPage.self, from: Data(#"{"text":"My day"}"#.utf8))
        XCTAssertTrue(page.additionalImageData.isEmpty)
        XCTAssertTrue(page.photos.isEmpty)

        let image = Data([1, 2, 3])
        let valid = StoryPage(text: "Four places", imageData: image,
                              additionalImageData: [image, image, image])
        XCTAssertEqual(valid.photos.count, 4)
        XCTAssertTrue(valid.hasValidPhotoMedia)
        XCTAssertFalse(StoryPage(text: "Too many", imageData: image,
                                 additionalImageData: [image, image, image, image]).hasValidPhotoMedia)
        XCTAssertFalse(StoryPage(text: "No primary", additionalImageData: [image]).hasValidPhotoMedia)
        XCTAssertFalse(StoryPage(text: "Video and photos", imageData: image,
                                 additionalImageData: [image], videoData: Data([1])).hasValidPhotoMedia)
        XCTAssertThrowsError(try StoryTransfer.exportData(
            VisualStory(title: "Invalid", pages: [StoryPage(text: "Too many", imageData: image,
                additionalImageData: [image, image, image, image])])))
    }

    @MainActor
    func testPhotoGridSurvivesEditRelaunchProfilesBackupAndStoryFile() throws {
        let first = photo(.systemOrange)
        let second = photo(.systemBlue)
        let third = photo(.systemGreen)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("story.json")
        let store = CommunicationStore(storageURL: file)
        let storyID = try XCTUnwrap(store.addStory("My places"))
        store.addStoryPage(storyID: storyID, text: "I can visit places.", symbol: "🗺️",
                           imageData: first, additionalImageData: [second, third])
        var page = try XCTUnwrap(store.stories.first { $0.id == storyID }?.pages.first)
        XCTAssertEqual(page.photos.count, 3)
        XCTAssertEqual(CommunicationStore(storageURL: file).stories.first { $0.id == storyID }?
            .pages.first?.additionalImageData, [second, third])

        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another storyteller"))
        XCTAssertFalse(store.stories.contains { $0.id == storyID })
        XCTAssertTrue(store.switchProfile(to: profileID))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.stories.first { $0.id == storyID }?.pages.first?.photos.count, 3)

        let sourceStory = try XCTUnwrap(store.stories.first { $0.id == storyID })
        let imported = try StoryTransfer.importStory(StoryTransfer.exportData(sourceStory))
        XCTAssertEqual(imported.pages.first?.photos, [first, second, third])

        let pdf = PrintableStoryPDF.makeData(story: sourceStory, paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: pdf))
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("I can visit places") == true)
        let attachment = XCTAttachment(data: pdf, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "Three-photo story page"
        attachment.lifetime = .keepAlways
        add(attachment)

        page.additionalImageData.removeFirst()
        store.updateStoryPage(storyID: storyID, page: page)
        XCTAssertEqual(store.stories.first { $0.id == storyID }?.pages.first?.photos,
                       [first, third])
    }

    private func photo(_ color: UIColor) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 240)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }
}
