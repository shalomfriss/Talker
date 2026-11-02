import PDFKit
import UIKit
import XCTest
@testable import OpenVoice

final class StoryBackgroundTests: XCTestCase {
    func testOlderPageDefaultsToPlainAndPhotoRequiresBoundedData() throws {
        let oldPage = try JSONDecoder().decode(StoryPage.self,
            from: Data(#"{"text":"My day"}"#.utf8))
        XCTAssertEqual(oldPage.backgroundStyle, .plain)
        XCTAssertNil(oldPage.backgroundPhotoData)

        XCTAssertTrue(StoryPage(text: "A calm place", backgroundStyle: .sky).hasValidBackgroundMedia)
        XCTAssertFalse(StoryPage(text: "A calm place", backgroundStyle: .photo).hasValidBackgroundMedia)
        XCTAssertFalse(StoryPage(text: "A calm place", backgroundStyle: .photo,
                                 backgroundPhotoData: Data()).hasValidBackgroundMedia)
        XCTAssertFalse(StoryPage(text: "A calm place", backgroundStyle: .photo,
                                 backgroundPhotoData: Data(count: 5 * 1_048_576 + 1)).hasValidBackgroundMedia)
        XCTAssertThrowsError(try StoryTransfer.exportData(VisualStory(title: "Invalid", pages: [
            StoryPage(text: "No background image", backgroundStyle: .photo)
        ])))
    }

    @MainActor
    func testBackgroundSurvivesEditRelaunchProfilesBackupAndStoryFile() throws {
        let photo = backgroundPhoto()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("story.json")
        let store = CommunicationStore(storageURL: file)
        let storyID = try XCTUnwrap(store.addStory("Background story"))
        store.addStoryPage(storyID: storyID, text: "I can choose a calm place.",
                           symbol: "🌿", imageData: nil, backgroundStyle: .sky)
        var page = try XCTUnwrap(store.stories.first { $0.id == storyID }?.pages.first)
        XCTAssertEqual(page.backgroundStyle, .sky)
        page.backgroundStyle = .photo
        page.backgroundPhotoData = photo
        store.updateStoryPage(storyID: storyID, page: page)

        let saved = try XCTUnwrap(CommunicationStore(storageURL: file).stories
            .first { $0.id == storyID }?.pages.first)
        XCTAssertEqual(saved.backgroundStyle, .photo)
        XCTAssertEqual(saved.backgroundPhotoData, photo)

        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other storyteller"))
        XCTAssertFalse(store.stories.contains { $0.id == storyID })
        XCTAssertTrue(store.switchProfile(to: profileID))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.stories.first { $0.id == storyID }?.pages.first?.backgroundPhotoData, photo)

        let source = try XCTUnwrap(store.stories.first { $0.id == storyID })
        let imported = try StoryTransfer.importStory(StoryTransfer.exportData(source))
        XCTAssertEqual(imported.pages.first?.backgroundStyle, .photo)
        XCTAssertEqual(imported.pages.first?.backgroundPhotoData, photo)
    }

    func testBackgroundsRenderInPrintableStory() throws {
        let story = VisualStory(title: "My calm places", pages: [
            StoryPage(text: "The sky feels gentle today.", symbol: "☁️", backgroundStyle: .sky),
            StoryPage(text: "I can rest here.", symbol: "🌿", backgroundStyle: .photo,
                      backgroundPhotoData: backgroundPhoto())
        ])
        let pdf = PrintableStoryPDF.makeData(story: story, paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: pdf))
        XCTAssertEqual(document.pageCount, 2)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("The sky feels gentle") == true)
        XCTAssertTrue(document.page(at: 1)?.string?.contains("I can rest here") == true)
        let attachment = XCTAttachment(data: pdf, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "Custom story backgrounds"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func backgroundPhoto() -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 640)).image { context in
            UIColor(red: 0.22, green: 0.57, blue: 0.54, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 480, height: 640))
            UIColor(red: 0.98, green: 0.72, blue: 0.38, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 80, y: 90, width: 320, height: 320))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }
}
