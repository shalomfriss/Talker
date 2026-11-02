import PDFKit
import XCTest
@testable import OpenVoice

final class SpeechCueTests: XCTestCase {
    func testPrintableSpeechCuesContainLettersNumbersResponsesAndPersonalTopics() throws {
        let topics = SpeechTopic.starter + (1...11).map { SpeechTopic(text: "Personal topic \($0)") }
        let data = PrintableSpeechCuePDF.makeData(profileName: "Taylor",
                                                  letters: LetterOrder.commonFirst.letters(language: "es"), language: "es",
                                                  topics: topics, paperSize: .a4)
        try data.write(to: FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenVoiceSpeechCueSpanishSample.pdf"), options: .atomic)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 3)
        let letters = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(letters.bounds(for: .mediaBox).size, CGSize(width: 595, height: 842))
        let letterText = try XCTUnwrap(letters.string)
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        for text in ["Taylor", "Letras y números", "E", "Ñ", "0", "9", "SÍ", "OTRA COSA"] {
            XCTAssertTrue(letterText.contains(text), "Missing \(text) from letter board")
        }
        let firstTopics = try XCTUnwrap(document.page(at: 1)?.string)
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        let lastTopics = try XCTUnwrap(document.page(at: 2)?.string)
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        XCTAssertTrue(firstTopics.contains("People"))
        XCTAssertTrue(firstTopics.contains("Personal topic 6"))
        XCTAssertTrue(lastTopics.contains("Personal topic 7"))
        XCTAssertTrue(lastTopics.contains("Personal topic 11"))
    }

    func testPrintableSpeechCuesRenderAUsLetterReviewSample() throws {
        let data = PrintableSpeechCuePDF.makeData(profileName: "My Voice",
                                                  letters: LetterOrder.alphabetical.letters(language: "en"), language: "en",
                                                  topics: SpeechTopic.starter, paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 2)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("Letters and numbers") == true)
        XCTAssertTrue(document.page(at: 1)?.string?.contains("Conversation topics") == true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OpenVoiceSpeechCueSample.pdf")
        try data.write(to: url, options: .atomic)
    }

    func testPrintableSpeechCuesUseCustomLetterSequence() throws {
        var settings = AppSettings()
        settings.setCustomLetters(["Z", "A"], language: "en")
        let data = PrintableSpeechCuePDF.makeData(
            profileName: "Taylor", letters: settings.orderedLetters(language: "en"),
            language: "en", topics: [], paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: data))
        let text = try XCTUnwrap(document.page(at: 0)?.string)
        let z = try XCTUnwrap(text.range(of: "Z"))
        let a = try XCTUnwrap(text.range(of: "A", range: z.upperBound..<text.endIndex))
        XCTAssertLessThan(z.lowerBound, a.lowerBound)
    }

    func testOlderProfileGetsStarterSpeechTopics() throws {
        let profile = StoredData(items: StarterVocabulary.items,
                                 routines: StarterVocabulary.routines,
                                 phrases: StarterVocabulary.phrases,
                                 settings: AppSettings())
        let encoded = try JSONEncoder().encode(profile)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "speechTopics")
        let oldData = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(StoredData.self, from: oldData)
        XCTAssertEqual(restored.speechTopics.map(\.text), SpeechTopic.starter.map(\.text))
    }

    @MainActor
    func testTopicsCanBeEditedAndStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        XCTAssertTrue(source.addSpeechTopic(" Books "))
        XCTAssertFalse(source.addSpeechTopic("books"))
        let topic = try XCTUnwrap(source.speechTopics.first { $0.text == "Books" })
        XCTAssertFalse(source.renameSpeechTopic(id: topic.id, to: "People"))
        XCTAssertTrue(source.renameSpeechTopic(id: topic.id, to: "My books"))
        let oldIndex = try XCTUnwrap(source.speechTopics.firstIndex { $0.id == topic.id })
        source.moveSpeechTopics(from: IndexSet(integer: oldIndex), to: 0)
        XCTAssertEqual(source.speechTopics.first?.id, topic.id)
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).speechTopics.first?.text, "My books")

        let firstProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second communicator"))
        XCTAssertFalse(source.speechTopics.contains { $0.id == topic.id })
        XCTAssertTrue(source.switchProfile(to: firstProfile))
        XCTAssertEqual(source.speechTopics.first?.id, topic.id)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.speechTopics.first?.text, "My books")
        source.deleteSpeechTopic(id: topic.id)
        XCTAssertFalse(source.speechTopics.contains { $0.id == topic.id })
    }

    func testPartnerSpellingMovesThroughRowsAndLettersWithoutTouchingTheAlphabet() {
        var session = PartnerSpellingSession(language: "en")
        XCTAssertEqual(session.rows.flatMap { $0 }, Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init))
        XCTAssertEqual(session.prompt, "Is your letter in A, B, C, D?")
        session.next()
        XCTAssertEqual(session.prompt, "Is your letter in E, F, G, H?")
        session.choose()
        XCTAssertEqual(session.phase, .letter)
        XCTAssertEqual(session.prompt, "Is it E?")
        session.next()
        session.choose()
        XCTAssertEqual(session.message, "F")
        XCTAssertEqual(session.phase, .row)
        session.addSpace()
        XCTAssertEqual(session.message, "F ")
        session.addSpace()
        XCTAssertEqual(session.message, "F ")
        session.deleteLast()
        XCTAssertEqual(session.message, "F")
        session.startAgain()
        XCTAssertEqual(session.message, "")
        XCTAssertEqual(session.prompt, "Is your letter in A, B, C, D?")
    }

    func testPartnerSpellingIncludesEnyeAndAllowsChangingRows() {
        var session = PartnerSpellingSession(language: "es")
        XCTAssertEqual(session.rows.flatMap { $0 }.count, 27)
        XCTAssertTrue(session.rows.flatMap { $0 }.contains("Ñ"))
        XCTAssertEqual(session.prompt, "¿Tu letra está en A, B, C, D?")
        session.next()
        session.next()
        session.choose()
        XCTAssertEqual(session.phase, .letter)
        for _ in 0..<6 { session.next() }
        XCTAssertEqual(session.currentLetter, "Ñ")
        session.choose()
        XCTAssertEqual(session.message, "Ñ")
        session.next()
        session.choose()
        session.backToRows()
        XCTAssertEqual(session.message, "Ñ")
        XCTAssertEqual(session.phase, .row)
    }

    func testPartnerSpellingScansNumbersAndActionsWithYesNo() {
        var session = PartnerSpellingSession(language: "en")
        for _ in 0..<5 { session.next() }
        XCTAssertEqual(session.prompt, "Is your number between 0 and 4?")
        session.choose()
        for _ in 0..<3 { session.next() }
        XCTAssertEqual(session.prompt, "Is it 3?")
        session.choose()
        XCTAssertEqual(session.message, "3")

        for _ in 0..<7 { session.next() }
        XCTAssertEqual(session.prompt, "Do you need an action?")
        session.choose()
        XCTAssertEqual(session.prompt, "Is it Space?")
        session.choose()
        XCTAssertEqual(session.message, "3 ")

        for _ in 0..<7 { session.next() }
        session.choose()
        session.next()
        XCTAssertEqual(session.prompt, "Is it Delete?")
        session.choose()
        XCTAssertEqual(session.message, "3")

        for _ in 0..<7 { session.next() }
        session.choose()
        session.next()
        session.next()
        XCTAssertEqual(session.choose(), "Please wait.")
        XCTAssertEqual(session.message, "3")

        for _ in 0..<7 { session.next() }
        session.choose()
        for _ in 0..<3 { session.next() }
        XCTAssertEqual(session.choose(), "Please guess.")
        XCTAssertEqual(session.message, "3")
    }

    func testPartnerSpellingActionsUseSpanishPrompts() {
        var session = PartnerSpellingSession(language: "es")
        for _ in 0..<7 { session.next() }
        XCTAssertEqual(session.prompt, "¿Necesitas una acción?")
        session.choose()
        session.next()
        session.next()
        XCTAssertEqual(session.prompt, "¿Es Espera?")
        XCTAssertEqual(session.choose(), "Espera, por favor.")
    }
}
