import XCTest
@testable import OpenVoice

final class PainCheckInTests: XCTestCase {
    func testPainMessageCanBeSpokenWithoutRequiringDetails() {
        XCTAssertEqual(PainMessageComposer.message(locations: [], sensation: nil,
                                                   intensity: nil, language: "en"), "I am in pain.")
        XCTAssertEqual(PainMessageComposer.message(locations: [], sensation: nil,
                                                   intensity: nil, language: "es"), "Tengo dolor.")
    }

    func testPainMessageIncludesMultipleAreasTypeAndOptionalStrength() {
        let areas: Set<PainLocation> = [.lowerBack, .head]
        XCTAssertEqual(PainMessageComposer.message(locations: areas, sensation: .sharp,
                                                   intensity: 4, language: "en"),
                       "I have pain in my head and my lower back. It feels sharp. Pain level 4 out of 5.")
        XCTAssertEqual(PainMessageComposer.message(locations: areas, sensation: .sharp,
                                                   intensity: 4, language: "es"),
                       "Tengo dolor en la cabeza y la parte baja de la espalda. Siento un dolor punzante. Intensidad 4 de 5.")
        XCTAssertEqual(PainMessageComposer.message(locations: [.chest], sensation: nil,
                                                   intensity: nil, language: "en"),
                       "I have pain in my chest.")
    }

    func testSpecificAreasReplaceBroadAreasAndSpeakInBothLanguages() {
        var areas = PainLocation.toggled(.leftArm, in: [])
        areas = PainLocation.toggled(.leftHand, in: areas)
        XCTAssertEqual(areas, [.leftHand])
        areas = PainLocation.toggled(.rightKnee, in: areas)
        XCTAssertEqual(PainMessageComposer.message(locations: areas, sensation: nil,
                                                   intensity: 8, language: "en", maximumIntensity: 10),
                       "I have pain in my left hand and my right knee. Pain level 8 out of 10.")
        XCTAssertEqual(PainMessageComposer.message(locations: areas, sensation: nil,
                                                   intensity: 8, language: "es", maximumIntensity: 10),
                       "Tengo dolor en la mano izquierda y la rodilla derecha. Intensidad 8 de 10.")
        areas = PainLocation.toggled(.leftArm, in: areas)
        XCTAssertEqual(areas, [.leftArm, .rightKnee])
        XCTAssertFalse(PainMessageComposer.message(locations: [], sensation: nil,
                                                   intensity: 11, language: "en", maximumIntensity: 10)
            .contains("Pain level"))
    }

    func testPainScaleSettingDefaultsAndRejectsUnsupportedValues() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(AppSettings.self, from: Data("{}".utf8)).painScaleMaximum, 5)
        XCTAssertEqual(try decoder.decode(AppSettings.self,
            from: Data(#"{"painScaleMaximum":7}"#.utf8)).painScaleMaximum, 5)
        XCTAssertEqual(try decoder.decode(AppSettings.self,
            from: Data(#"{"painScaleMaximum":10}"#.utf8)).painScaleMaximum, 10)
    }

    @MainActor
    func testTenPointPainScalePersistsWithProfileBackupAndLog() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("pain.json")
        let store = CommunicationStore(storageURL: file)
        store.settings.saveFeelingsLog = true
        store.settings.painScaleMaximum = 10
        XCTAssertFalse(store.savePainEntry(message: "Pain level 11 out of 10.", intensity: 11))
        XCTAssertTrue(store.savePainEntry(message: "Pain level 8 out of 10.", intensity: 8))
        XCTAssertEqual(store.feelingsLog.first?.scaleMaximum, 10)
        XCTAssertEqual(store.feelingsLog.first?.intensity, 8)
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.painScaleMaximum, 10)
        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other person"))
        XCTAssertEqual(store.settings.painScaleMaximum, 5)
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.settings.painScaleMaximum, 10)
        let backup = CommunicationStore(storageURL: directory.appendingPathComponent("backup.json"))
        try backup.importBackup(store.backupData())
        XCTAssertEqual(backup.settings.painScaleMaximum, 10)
        XCTAssertEqual(backup.feelingsLog.first?.scaleMaximum, 10)
    }

    @MainActor
    func testPainLogRequiresOptInAndKeepsLanguageAcrossBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        XCTAssertFalse(store.savePainEntry(message: "I am in pain.", intensity: 0))
        XCTAssertTrue(store.feelingsLog.isEmpty)
        store.settings.saveFeelingsLog = true
        store.settings.communicationLanguage = "es"
        XCTAssertTrue(store.savePainEntry(message: "Tengo dolor en la cabeza.", intensity: 0))
        let entry = try XCTUnwrap(store.feelingsLog.first)
        XCTAssertEqual(entry.feelingLabel, "Dolor")
        XCTAssertEqual(entry.language, "es")
        XCTAssertEqual(entry.intensity, 0)
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).feelingsLog.first, entry)

        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another person"))
        XCTAssertTrue(store.feelingsLog.isEmpty)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertEqual(store.feelingsLog.first, entry)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.feelingsLog.first, entry)
    }
}
