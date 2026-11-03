import XCTest
import UIKit
@testable import OpenVoice

final class CommunicationNoteTests: XCTestCase {
    func testOldStoredDataWithoutNotesStartsEmpty() throws {
        let stored = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                phrases: StarterVocabulary.phrases, settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        object.removeValue(forKey: "notes")
        let restored = try JSONDecoder().decode(StoredData.self,
                                                from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(restored.notes.isEmpty)
    }

    @MainActor
    func testNotesStayWithProfileAndBackupAndCanBeEdited() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        XCTAssertFalse(store.saveNote(title: " ", topic: "Plans", text: "Meet at noon"))
        XCTAssertTrue(store.saveNote(title: "  Meeting  ", topic: "  Plans  ", text: "  Meet at noon  "))
        let note = try XCTUnwrap(store.notes.first)
        XCTAssertEqual(note.title, "Meeting")
        XCTAssertEqual(note.topic, "Plans")
        XCTAssertEqual(note.text, "Meet at noon")
        XCTAssertTrue(store.saveNote(id: note.id, title: "Meeting tomorrow", topic: "plans",
                                     text: "Meet at one"))
        XCTAssertEqual(store.notes.first?.id, note.id)
        XCTAssertEqual(store.notes.first?.topic, "Plans")
        XCTAssertEqual(store.notes.first?.text, "Meet at one")
        XCTAssertFalse(store.saveNote(id: UUID(), title: "Missing", topic: "", text: "No"))

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.notes.first?.text, "Meet at one")
        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.notes, store.notes)

        XCTAssertTrue(store.addProfile("Another voice"))
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertTrue(store.saveNote(title: "My note", topic: "", text: "Another profile"))
        XCTAssertEqual(store.notes.first?.topic, "General")
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.notes.map(\.title), ["Meeting tomorrow"])
        XCTAssertTrue(store.deleteNote(id: note.id))
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertFalse(store.deleteNote(id: note.id))
    }

    @MainActor
    func testUsingNoteTextKeepsPictureDraft() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let want = try XCTUnwrap(store.items.first { $0.label == "want" })
        store.select(want)
        store.typedMessage = "Hello"
        XCTAssertTrue(store.saveNote(title: "At the doctor", topic: "Health",
                                     text: "Please explain that again."))
        XCTAssertTrue(store.appendTypedPhrase(try XCTUnwrap(store.notes.first?.text)))
        XCTAssertEqual(store.composedMessage, "want")
        XCTAssertEqual(store.typedMessage, "Hello Please explain that again.")
    }

    @MainActor
    func testLifeNotebookLoadsLazilyAndStaysWithProfileAndBackup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).jpegData(
            withCompressionQuality: 0.8) { context in
                UIColor.systemTeal.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
            }
        let post = LifeNotebookPost(title: "Park visit", topic: "Family", text: "We saw ducks.",
                                    photoData: photo)
        try await store.saveLifeNotebookPost(post)
        XCTAssertEqual(store.lifeNotebookPosts.first?.title, "Park visit")
        XCTAssertEqual(store.lifeNotebookPosts.first?.photoData, photo)

        store.settings.highContrast.toggle()
        store.flushPersistence()
        let savedProfile = try JSONDecoder().decode(StoredData.self, from: Data(contentsOf: file))
        XCTAssertTrue(savedProfile.lifeNotebookPosts.isEmpty)

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertTrue(relaunched.lifeNotebookPosts.isEmpty)
        try await relaunched.loadLifeNotebook()
        XCTAssertEqual(relaunched.lifeNotebookPosts.first?.id, post.id)

        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.lifeNotebookPosts.first?.photoData, photo)

        XCTAssertTrue(store.addProfile("Other voice"))
        try await store.loadLifeNotebook()
        XCTAssertTrue(store.lifeNotebookPosts.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        try await store.loadLifeNotebook()
        XCTAssertEqual(store.lifeNotebookPosts.first?.title, "Park visit")

        try await store.deleteLifeNotebookPost(id: post.id)
        XCTAssertTrue(store.lifeNotebookPosts.isEmpty)
        XCTAssertTrue(try JSONDecoder().decode(StoredData.self, from: store.backupData())
            .lifeNotebookPosts.isEmpty)
    }

    @MainActor
    func testLifeNotebookRejectsOversizedPhotoAndOlderBackupStartsEmpty() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let oversized = LifeNotebookPost(title: "Too large", text: "Photo",
            photoData: Data(repeating: 1, count: 2 * 1_048_576 + 1))
        do {
            try await store.saveLifeNotebookPost(oversized)
            XCTFail("Oversized notebook photo should be rejected")
        } catch {
            XCTAssertTrue(store.lifeNotebookPosts.isEmpty)
        }

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: store.backupData()) as? [String: Any])
        legacy.removeValue(forKey: "lifeNotebookPosts")
        let decoded = try JSONDecoder().decode(StoredData.self,
            from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertTrue(decoded.lifeNotebookPosts.isEmpty)
    }

    @MainActor
    func testLifeNotebookKeepsBackdatedMomentsInTimelineOrderAfterBackup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        try await store.saveLifeNotebookPost(LifeNotebookPost(title: "Today", text: "Today happened."))
        var earlier = LifeNotebookPost(title: "Earlier", text: "This happened before.")
        earlier.occurredAt = Date(timeIntervalSince1970: 0)
        try await store.saveLifeNotebookPost(earlier)
        XCTAssertEqual(store.lifeNotebookPosts.map(\.title), ["Today", "Earlier"])

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.lifeNotebookPosts.map(\.title), ["Today", "Earlier"])
    }

    @MainActor
    func testLifeNotebookVideoSurvivesRelaunchAndBackup() async throws {
        let sourceURL = try XCTUnwrap(Bundle.main.url(forResource: "SceneSample", withExtension: "mov"))
        let prepared = try await SceneVideoProcessing.prepared(from: sourceURL,
            byteLimit: 8 * 1_048_576)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let post = LifeNotebookPost(title: "Playground", text: "I went down the slide.",
                                    photoData: prepared.poster, videoData: prepared.video)
        try await store.saveLifeNotebookPost(post)

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertTrue(relaunched.lifeNotebookPosts.isEmpty)
        try await relaunched.loadLifeNotebook()
        XCTAssertEqual(relaunched.lifeNotebookPosts.first?.videoData, prepared.video)
        XCTAssertEqual(relaunched.lifeNotebookPosts.first?.photoData, prepared.poster)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.lifeNotebookPosts.first?.videoData, prepared.video)
    }

    @MainActor
    func testLifeNotebookRejectsBrokenVideoAndReadsOlderPosts() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let noPoster = LifeNotebookPost(title: "Clip", text: "Watch this.", videoData: Data([1]))
        let oversized = LifeNotebookPost(title: "Clip", text: "Watch this.", photoData: Data([1]),
            videoData: Data(count: 8 * 1_048_576 + 1))
        for post in [noPoster, oversized] {
            do {
                try await store.saveLifeNotebookPost(post)
                XCTFail("Invalid notebook video should be rejected")
            } catch {
                XCTAssertTrue(store.lifeNotebookPosts.isEmpty)
            }
        }

        let oldPost = LifeNotebookPost(title: "Old photo", text: "A day out.", photoData: Data([1]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(oldPost))
            as? [String: Any])
        object.removeValue(forKey: "videoData")
        object.removeValue(forKey: "pictograms")
        object.removeValue(forKey: "replies")
        let decoded = try JSONDecoder().decode(LifeNotebookPost.self,
            from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.videoData)
        XCTAssertNil(decoded.pictograms)
        XCTAssertNil(decoded.replies)
    }

    @MainActor
    func testLifeNotebookPictureWordsSpeakAndSurviveBackup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).jpegData(
            withCompressionQuality: 0.8) { context in
                UIColor.systemOrange.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
            }
        let words = [LifeNotebookPictogram(label: "I", symbol: "🙋"),
                     LifeNotebookPictogram(label: "  playground  ", imageData: image,
                                           arasaacPictogramID: 123)]
        let post = LifeNotebookPost(title: "My day", pictograms: words)
        try await store.saveLifeNotebookPost(post)
        let saved = try XCTUnwrap(store.lifeNotebookPosts.first)
        XCTAssertEqual(saved.pictograms?.map(\.label), ["I", "playground"])
        XCTAssertEqual(saved.spokenText, "I playground")
        XCTAssertEqual(saved.sharedText, "My day\n\nI playground")

        store.settings.highContrast.toggle()
        store.flushPersistence()
        let profile = try JSONDecoder().decode(StoredData.self, from: Data(contentsOf: file))
        XCTAssertTrue(profile.lifeNotebookPosts.isEmpty)
        let relaunched = CommunicationStore(storageURL: file)
        try await relaunched.loadLifeNotebook()
        XCTAssertEqual(relaunched.lifeNotebookPosts.first?.pictograms?.last?.imageData, image)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.lifeNotebookPosts.first?.pictograms, saved.pictograms)
    }

    @MainActor
    func testLifeNotebookPictureWordLimitsRejectInvalidPosts() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let tooMany = LifeNotebookPost(title: "Too many", pictograms:
            (0..<9).map { LifeNotebookPictogram(label: "Word \($0)") })
        let tooLarge = LifeNotebookPost(title: "Too large", pictograms: [
            LifeNotebookPictogram(label: "Photo", imageData: Data(count: 512 * 1_024 + 1))])
        let missingImage = LifeNotebookPost(title: "Missing", pictograms: [
            LifeNotebookPictogram(label: "Pictogram", arasaacPictogramID: 123)])
        for post in [tooMany, tooLarge, missingImage] {
            do {
                try await store.saveLifeNotebookPost(post)
                XCTFail("Invalid picture word should be rejected")
            } catch {
                XCTAssertTrue(store.lifeNotebookPosts.isEmpty)
            }
        }
    }

    @MainActor
    func testLifeNotebookMomentFileMovesMediaWithoutOverwritingAnExistingPost() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let sourceURL = try XCTUnwrap(Bundle.main.url(forResource: "SceneSample", withExtension: "mov"))
        let video = try Data(contentsOf: sourceURL)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).jpegData(
            withCompressionQuality: 0.8) { context in
                UIColor.systemPurple.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
            }
        let word = LifeNotebookPictogram(label: "play", imageData: image,
                                         arasaacPictogramID: 123)
        let original = LifeNotebookPost(title: "At the park", text: "We played together.",
            photoData: image, videoData: video, pictograms: [word])
        try await store.saveLifeNotebookPost(original)

        let file = try await store.exportLifeNotebookPost(id: original.id)
        XCTAssertLessThan(file.count, LifeNotebookTransfer.maxImportBytes)
        let imported = try await store.importLifeNotebookPost(file)
        XCTAssertNotEqual(imported.id, original.id)
        XCTAssertNotEqual(imported.pictograms?.first?.id, word.id)
        XCTAssertEqual(imported.photoData, image)
        XCTAssertEqual(imported.videoData, video)
        XCTAssertEqual(imported.pictograms?.first?.imageData, image)
        XCTAssertEqual(imported.occurredAt, original.occurredAt)
        XCTAssertEqual(store.lifeNotebookPosts.count, 2)
        XCTAssertTrue(store.lifeNotebookPosts.contains { $0.id == original.id })

        let recipient = CommunicationStore(storageURL: directory.appendingPathComponent("recipient.json"))
        let received = try await recipient.importLifeNotebookPost(file)
        XCTAssertEqual(received.sharedText, original.sharedText)
        XCTAssertEqual(recipient.lifeNotebookPosts.first?.videoData, video)
    }

    @MainActor
    func testLifeNotebookMomentFileRejectsWrongFormatAndOversize() async throws {
        let oversized = Data(count: LifeNotebookTransfer.maxImportBytes + 1)
        XCTAssertThrowsError(try LifeNotebookTransfer.importPost(oversized))
        XCTAssertThrowsError(try LifeNotebookTransfer.importPost(Data("{}".utf8)))
        let invalid = LifeNotebookTransfer(format: "org.openvoice.life-notebook-post",
            version: 1, post: LifeNotebookPost(title: " ", text: "No title"))
        XCTAssertThrowsError(try LifeNotebookTransfer.importPost(JSONEncoder().encode(invalid)))
        let wrongVersion = LifeNotebookTransfer(format: "org.openvoice.life-notebook-post",
            version: 2, post: LifeNotebookPost(title: "Day", text: "Hello"))
        XCTAssertThrowsError(try LifeNotebookTransfer.importPost(JSONEncoder().encode(wrongVersion)))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertThrowsError(try LifeNotebookTransfer.exportData(
            LifeNotebookPost(title: " ", text: "Invalid")))
        do {
            _ = try await store.importLifeNotebookPost(oversized)
            XCTFail("Oversized moment import should be rejected")
        } catch {
            XCTAssertTrue(store.lifeNotebookPosts.isEmpty)
        }
    }

    @MainActor
    func testLifeNotebookConversationSurvivesRelaunchBackupAndMomentFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let post = LifeNotebookPost(title: "At the park", text: "We went outside.")
        try await store.saveLifeNotebookPost(post)
        let question = try await store.addLifeNotebookReply(postID: post.id,
            speaker: .partner, text: "  What did you see?  ")
        let answer = try await store.addLifeNotebookReply(postID: post.id,
            speaker: .communicator, text: "  Ducks.  ")
        XCTAssertEqual(question.text, "What did you see?")
        XCTAssertEqual(answer.text, "Ducks.")
        XCTAssertEqual(store.lifeNotebookPosts.first?.replies?.map(\.speaker),
                       [.partner, .communicator])
        XCTAssertEqual(store.lifeNotebookPosts.first?.sharedConversationText,
            "At the park\n\nWe went outside.\n\nPartner: What did you see?\nCommunicator: Ducks.")

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertTrue(relaunched.lifeNotebookPosts.isEmpty)
        try await relaunched.loadLifeNotebook()
        XCTAssertEqual(relaunched.lifeNotebookPosts.first?.replies?.map(\.text),
                       ["What did you see?", "Ducks."])

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.lifeNotebookPosts.first?.replies?.map(\.id),
                       [question.id, answer.id])

        let transfer = try await store.exportLifeNotebookPost(id: post.id)
        let received = try await restored.importLifeNotebookPost(transfer)
        XCTAssertEqual(received.replies?.map(\.text), ["What did you see?", "Ducks."])
        XCTAssertNotEqual(received.replies?.first?.id, question.id)
        XCTAssertEqual(restored.lifeNotebookPosts.count, 2)
    }

    @MainActor
    func testLifeNotebookReplyValidationAndDeletion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let post = LifeNotebookPost(title: "Day", text: "We played.")
        try await store.saveLifeNotebookPost(post)
        for text in ["   ", String(repeating: "a", count: 501)] {
            do {
                _ = try await store.addLifeNotebookReply(postID: post.id,
                    speaker: .communicator, text: text)
                XCTFail("Invalid reply should be rejected")
            } catch { XCTAssertTrue(store.lifeNotebookPosts.first?.replies?.isEmpty ?? true) }
        }
        let reply = try await store.addLifeNotebookReply(postID: post.id,
            speaker: .communicator, text: "Hello")
        try await store.deleteLifeNotebookReply(postID: post.id, replyID: reply.id)
        XCTAssertTrue(store.lifeNotebookPosts.first?.replies?.isEmpty ?? false)

        var full = post
        full.replies = (0..<40).map { LifeNotebookReply(speaker: .partner, text: "Turn \($0)") }
        try await store.saveLifeNotebookPost(full)
        do {
            _ = try await store.addLifeNotebookReply(postID: post.id,
                speaker: .communicator, text: "Another")
            XCTFail("Forty-one turns should be rejected")
        } catch { XCTAssertEqual(store.lifeNotebookPosts.first?.replies?.count, 40) }

        var duplicate = post
        let same = LifeNotebookReply(speaker: .partner, text: "Hello")
        duplicate.replies = [same, same]
        XCTAssertThrowsError(try LifeNotebookTransfer.exportData(duplicate))
    }
}
