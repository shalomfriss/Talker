import XCTest
@testable import OpenVoice

final class PhraseTemplateTests: XCTestCase {
    func testNamedBlanksRenderInOrderAndRepeatedNamesShareAValue() {
        let template = "Please put {item} in {place}. I need {item}."
        XCTAssertEqual(PhraseTemplate.fields(in: template), ["item", "place"])
        XCTAssertNil(PhraseTemplate.render(template, values: ["item": "book"]))
        XCTAssertEqual(PhraseTemplate.render(template, values: ["item": " book ", "place": " bag "]),
                       "Please put book in bag. I need book.")
        XCTAssertEqual(PhraseTemplate.fields(in: "I like { } and {{nested}}."), [])
    }

    @MainActor
    func testTemplateCanJoinMessageAndSurviveReloadAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        source.addPhrase("I would like {drink}.", folder: "Requests")
        let phrase = try XCTUnwrap(source.phrases.first { $0.text == "I would like {drink}." })
        let completed = try XCTUnwrap(PhraseTemplate.render(phrase.text, values: ["drink": "water"]))
        source.appendCompletedPhrase(completed)
        XCTAssertEqual(source.composedMessage, "I would like water.")
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).phrases.first { $0.id == phrase.id }?.text,
                       "I would like {drink}.")
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).composedMessage, completed)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.phrases.first { $0.id == phrase.id }?.folder, "Requests")
        XCTAssertEqual(restored.composedMessage, completed)
    }

    @MainActor
    func testEditingPhraseRemovesRecordingWhenTextChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        source.addPhrase("I want water.", folder: "Requests")
        let phrase = try XCTUnwrap(source.phrases.first { $0.text == "I want water." })
        source.updatePhraseRecording(phrase, audioData: Data([1, 2, 3]))
        XCTAssertTrue(source.updatePhraseText(phrase, to: "I want {drink}."))
        let updated = try XCTUnwrap(source.phrases.first { $0.id == phrase.id })
        XCTAssertNil(updated.audioData)
        XCTAssertEqual(updated.folder, "Requests")
        XCTAssertFalse(source.updatePhraseText(updated, to: "I need a break."))
        XCTAssertEqual(source.phrases.first { $0.id == phrase.id }?.text, "I want {drink}.")
    }
}
