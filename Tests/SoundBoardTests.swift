import AVFoundation
import XCTest
@testable import OpenVoice

final class SoundBoardTests: XCTestCase {
    func testBuiltInCuesAreBundledAndPlayable() {
        XCTAssertEqual(BuiltInSound.allCases.count, 6)
        for sound in BuiltInSound.allCases {
            guard let url = sound.fileURL else {
                XCTFail("Missing \(sound.title)")
                continue
            }
            XCTAssertGreaterThan((try? Data(contentsOf: url).count) ?? 0, 0)
            XCTAssertNotNil(try? AVAudioPlayer(contentsOf: url))
        }
    }

    func testClipCleanupRejectsEmptyOversizedAndDuplicateEntries() {
        let valid = SoundBoardClip(name: "  My laugh  ", audioData: Data([1, 2, 3]))
        let duplicate = SoundBoardClip(id: valid.id, name: "Again", audioData: Data([4]))
        let empty = SoundBoardClip(name: " ", audioData: Data([1]))
        let oversized = SoundBoardClip(name: "Too long", audioData: Data(repeating: 1, count: SoundBoardClip.maximumAudioBytes + 1))
        XCTAssertEqual(SoundBoardClip.cleaned([valid, duplicate, empty, oversized]),
                       [SoundBoardClip(id: valid.id, name: "My laugh", audioData: valid.audioData)])
    }

    @MainActor
    func testPersonalSoundsSurviveRelaunchProfileSwitchAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("profile.json")
        let store = CommunicationStore(storageURL: file)
        let originalProfile = store.activeProfileID
        let clip = SoundBoardClip(name: "My sound", audioData: Data([1, 2, 3]))
        store.settings.soundBoardClips = [clip]
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.soundBoardClips, [clip])

        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertTrue(store.settings.soundBoardClips.isEmpty)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertEqual(store.settings.soundBoardClips, [clip])

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.soundBoardClips, [clip])

        let snapshot = try store.createLocalBackup(named: "Before deleting sound")
        store.settings.soundBoardClips = []
        try store.importBackup(store.localBackupData(id: snapshot.id))
        XCTAssertEqual(store.settings.soundBoardClips, [clip])
    }

    func testOlderSettingsLoadWithEmptySoundBoard() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSettings())) as? [String: Any])
        json.removeValue(forKey: "soundBoardClips")
        let settings = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(settings.soundBoardClips.isEmpty)
    }
}
