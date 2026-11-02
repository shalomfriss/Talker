import XCTest
@testable import OpenVoice

final class CommunicationStoreTests: XCTestCase {
    @MainActor
    func testMovingIntoEmptyGridPositionPreservesSpacingAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("spaces.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.addBoard("Space test"))
        for label in ["One", "Two", "Three"] {
            store.addItem(label: label, symbol: "●", message: label, category: "Space test", imageData: nil)
        }
        let original = store.items.filter { $0.category == "Space test" }
        XCTAssertFalse(store.moveItem(original[0].id, in: "Space test", toEmptyGridPosition: 1))
        XCTAssertFalse(store.moveItem(UUID(), in: "Space test", toEmptyGridPosition: 5))
        XCTAssertFalse(store.moveItem(original[0].id, in: "Space test", toEmptyGridPosition: 10_000))
        XCTAssertTrue(store.moveItem(original[0].id, in: "Space test", toEmptyGridPosition: 5))
        XCTAssertEqual(store.gridSlots(in: "Space test").map { $0?.label },
                       [nil, "Two", "Three", nil, nil, "One"])
        XCTAssertTrue(store.moveItem(original[1].id, in: "Space test", toEmptyGridPosition: 0))
        XCTAssertEqual(store.gridSlots(in: "Space test").map { $0?.label },
                       ["Two", nil, "Three", nil, nil, "One"])
        XCTAssertTrue(store.renameBoard("Space test", to: "New space test"))
        XCTAssertNil(store.settings.boardEmptySlots["Space test"])
        XCTAssertEqual(store.gridSlots(in: "New space test")[5]?.id, original[0].id)
        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.gridSlots(in: "New space test")[5]?.id, original[0].id)
        XCTAssertEqual(CommunicationStore(storageURL: file).gridSlots(in: "New space test")[5]?.id,
                       original[0].id)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restore.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.gridSlots(in: "New space test")[5]?.id, original[0].id)
        XCTAssertTrue(restored.moveItem(original[0].id, in: "New space test", toEmptyGridPosition: 1))
        XCTAssertEqual(restored.gridSlots(in: "New space test").count, 3)
        XCTAssertTrue(restored.emptyGridPositions(in: "New space test").isEmpty)
    }

    @MainActor
    func testSwappingBoardSlotsPreservesButtonsAndPersists() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("swap.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.addBoard("Swap test"))
        XCTAssertTrue(store.addBoard("Other test"))
        for label in ["One", "Two", "Three"] {
            store.addItem(label: label, symbol: "●", message: label, category: "Swap test", imageData: nil)
        }
        store.addItem(label: "Other", symbol: "●", message: "Other", category: "Other test", imageData: nil)
        let original = store.items.filter { $0.category == "Swap test" }
        let otherID = try XCTUnwrap(store.items.first { $0.category == "Other test" }?.id)
        var hidden = original[1]
        hidden.visibility = .hidden
        store.updateItem(hidden)

        XCTAssertFalse(store.swapItems(original[0].id, with: original[0].id, in: "Swap test"))
        XCTAssertFalse(store.swapItems(original[0].id, with: otherID, in: "Swap test"))
        XCTAssertFalse(store.swapItems(original[0].id, with: original[2].id, in: "Missing"))
        XCTAssertTrue(store.swapItems(original[0].id, with: original[2].id, in: "Swap test"))
        let swapped = store.items.filter { $0.category == "Swap test" }
        XCTAssertEqual(swapped.map(\.id), [original[2].id, original[1].id, original[0].id])
        XCTAssertEqual(swapped.map(\.message), ["Three", "Two", "One"])
        XCTAssertEqual(swapped[1].boardVisibility, .hidden)
        XCTAssertEqual(store.items.first { $0.category == "Other test" }?.id, otherID)

        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another profile"))
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.items.filter { $0.category == "Swap test" }.map(\.id), swapped.map(\.id))
        XCTAssertEqual(CommunicationStore(storageURL: file).items.filter { $0.category == "Swap test" }.map(\.id),
                       swapped.map(\.id))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.filter { $0.category == "Swap test" }.map(\.id), swapped.map(\.id))
    }

    @MainActor
    func testAlphabetizingSelectedBoardButtonsUsesVisibleLanguageAndPreservesOtherSlots() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("alphabetize.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.addBoard("Sort test"))
        XCTAssertTrue(store.addBoard("Other test"))
        for label in ["Zebra", "Keep", "apple", "APPLE", "Banana"] {
            store.addItem(label: label, symbol: "●", message: label, category: "Sort test", imageData: nil)
        }
        store.addItem(label: "Other", symbol: "●", message: "Other", category: "Other test", imageData: nil)
        let original = store.items.filter { $0.category == "Sort test" }
        let otherID = try XCTUnwrap(store.items.first { $0.category == "Other test" }?.id)
        let selected = Set([original[0].id, original[2].id, original[3].id, original[4].id])
        var hidden = original[3]
        hidden.visibility = .hidden
        store.updateItem(hidden)

        XCTAssertFalse(store.alphabetizeItems(in: "Missing", selectedIDs: selected))
        XCTAssertFalse(store.alphabetizeItems(in: "Sort test", selectedIDs: [original[0].id]))
        XCTAssertFalse(store.alphabetizeItems(in: "Sort test", selectedIDs: [original[0].id, otherID]))
        XCTAssertFalse(store.alphabetizeItems(in: "Sort test", selectedIDs: [original[0].id, UUID()]))
        XCTAssertTrue(store.alphabetizeItems(in: "Sort test", selectedIDs: selected))
        let english = store.items.filter { $0.category == "Sort test" }
        XCTAssertEqual(english.map(\.id),
                       [original[2].id, original[1].id, original[3].id, original[4].id, original[0].id])
        XCTAssertEqual(english[2].boardVisibility, .hidden)
        XCTAssertFalse(store.alphabetizeItems(in: "Sort test", selectedIDs: selected))
        XCTAssertEqual(store.items.first { $0.category == "Other test" }?.id, otherID)

        for (item, spanish) in [(original[0], "árbol"), (original[2], "zapato"),
                                (original[3], "Zapato"), (original[4], "barco")] {
            store.updateSpanishTranslation(for: item.id, label: spanish, message: spanish)
        }
        store.settings.communicationLanguage = "es"
        XCTAssertTrue(store.alphabetizeItems(in: "Sort test", selectedIDs: selected))
        let spanishIDs = [original[0].id, original[1].id, original[4].id, original[2].id, original[3].id]
        XCTAssertEqual(store.items.filter { $0.category == "Sort test" }.map(\.id), spanishIDs)
        XCTAssertEqual(store.items.first { $0.id == original[3].id }?.boardVisibility, .hidden)

        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another profile"))
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.items.filter { $0.category == "Sort test" }.map(\.id), spanishIDs)
        XCTAssertEqual(CommunicationStore(storageURL: file).items.filter { $0.category == "Sort test" }.map(\.id),
                       spanishIDs)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.filter { $0.category == "Sort test" }.map(\.id), spanishIDs)
    }

    @MainActor
    func testVideoButtonPersistsWithoutChangingPictureMessage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("video-button.json")
        let store = CommunicationStore(storageURL: file)
        let clip = Data([1, 2, 3, 4])
        let poster = Data([5, 6, 7])
        store.addItem(label: "Watch slide", symbol: "▶️", message: "Watch slide",
                      category: "Core", imageData: nil, videoData: clip,
                      videoPosterData: poster, action: .playVideo)
        let button = try XCTUnwrap(store.items.first { $0.label == "Watch slide" })
        XCTAssertEqual(button.effectiveAction, .playVideo)
        XCTAssertEqual(button.videoData, clip)
        XCTAssertEqual(CommunicationStore(storageURL: file).items.first { $0.id == button.id }?.videoPosterData,
                       poster)
        let before = store.composedMessage
        store.select(button)
        XCTAssertEqual(store.composedMessage, before)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.first { $0.id == button.id }?.videoData, clip)

        var changed = button
        changed.action = .addToMessage
        store.updateItem(changed)
        XCTAssertNil(store.items.first { $0.id == button.id }?.videoData)
        XCTAssertNil(store.items.first { $0.id == button.id }?.videoPosterData)
    }

    @MainActor
    func testVideoButtonRequiresClipAndPoster() {
        let store = CommunicationStore(storageURL:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let before = store.items.count
        store.addItem(label: "Broken video", symbol: "▶️", message: "Broken video",
                      category: "Core", imageData: nil, videoData: Data([1]), action: .playVideo)
        XCTAssertEqual(store.items.count, before)
    }

    func testOlderButtonWithoutVideoFieldsStillDecodes() throws {
        let original = CommunicationItem(label: "Go", symbol: "➡️", message: "Go", category: "Core")
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original))
                                  as? [String: Any])
        value.removeValue(forKey: "videoData")
        value.removeValue(forKey: "videoPosterData")
        let decoded = try JSONDecoder().decode(CommunicationItem.self,
            from: JSONSerialization.data(withJSONObject: value))
        XCTAssertNil(decoded.videoData)
        XCTAssertNil(decoded.videoPosterData)
        XCTAssertEqual(decoded.label, "Go")
    }

    func testStarterWordsHaveCleanLabelsAndQuickAccessWords() {
        XCTAssertTrue(StarterVocabulary.items.count > 100)
        XCTAssertTrue(StarterVocabulary.items.allSatisfy {
            $0.label == $0.label.trimmingCharacters(in: .whitespacesAndNewlines)
        })
        for word in ["yes", "no", "help", "break"] {
            XCTAssertTrue(StarterVocabulary.items.contains { $0.label == word }, "Missing \(word)")
        }
    }

    func testOldSettingsWithoutVoiceSelectionStillLoad() throws {
        let previousVersion = Data("{\"speechRate\":0.5,\"speakOnTap\":true,\"largeTiles\":false,\"highContrast\":false,\"confirmSelection\":false}".utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: previousVersion)
        XCTAssertTrue(settings.speakOnTap)
        XCTAssertFalse(settings.autoClearAfterSpeaking)
        XCTAssertFalse(settings.saveFeelingsLog)
        XCTAssertEqual(settings.voiceIdentifier, "")
        XCTAssertEqual(settings.tileSize, .standard)
        XCTAssertFalse(settings.scanEnabled)
        XCTAssertEqual(settings.scanMode, .automatic)
        XCTAssertEqual(settings.scanPattern, .sequential)
        XCTAssertFalse(settings.scanSpokenCues)
        XCTAssertEqual(settings.scanCueMode, .off)
        XCTAssertEqual(settings.scanCueVoiceIdentifier, "")
        XCTAssertEqual(settings.scanInterval, 1.5)
        XCTAssertEqual(settings.dimmedButtonOpacity, 0.35)
        XCTAssertTrue(settings.dimmedButtonsActive)
        XCTAssertEqual(settings.wordHoldDuration, 0)
        XCTAssertEqual(settings.repeatFilterInterval, 0)
        XCTAssertEqual(settings.communicationLanguage, "en")
        XCTAssertEqual(settings.letterOrder, .alphabetical)
        XCTAssertFalse(settings.showBoardSuggestions)
        XCTAssertFalse(settings.choiceBoardEditingLocked)
        XCTAssertFalse(settings.boardOnlyModeActive)
        XCTAssertFalse(settings.historyPaused)
        XCTAssertEqual(settings.attentionMessage, "Excuse me. I have something to say.")
        XCTAssertFalse(settings.attentionHaptics)
        XCTAssertTrue(settings.focusWordIDs.isEmpty)
        let fastScan = try JSONDecoder().decode(AppSettings.self,
            from: Data("{\"scanEnabled\":true,\"scanInterval\":0.1}".utf8))
        XCTAssertTrue(fastScan.scanEnabled)
        XCTAssertEqual(fastScan.scanInterval, 0.7)
        let unknownMode = try JSONDecoder().decode(AppSettings.self,
            from: Data("{\"scanMode\":\"unsupported\"}".utf8))
        XCTAssertEqual(unknownMode.scanMode, .automatic)
        let unknownPattern = try JSONDecoder().decode(AppSettings.self,
            from: Data("{\"scanPattern\":\"unsupported\"}".utf8))
        XCTAssertEqual(unknownPattern.scanPattern, .sequential)
        let previousSpokenCue = try JSONDecoder().decode(AppSettings.self,
            from: Data("{\"scanSpokenCues\":true}".utf8))
        XCTAssertEqual(previousSpokenCue.scanCueMode, .spoken)
        let unknownCue = try JSONDecoder().decode(AppSettings.self,
            from: Data("{\"scanCueMode\":\"unsupported\"}".utf8))
        XCTAssertEqual(unknownCue.scanCueMode, .off)

        let larger = Data("{\"largeTiles\":true}".utf8)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: larger).tileSize, .large)
        var compact = AppSettings()
        compact.tileSize = .compact
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(compact)).tileSize, .compact)
        compact.wordHoldDuration = 1.0
        compact.repeatFilterInterval = 0.8
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(compact))
        XCTAssertEqual(restored.wordHoldDuration, 1.0)
        XCTAssertEqual(restored.repeatFilterInterval, 0.8)
    }

    @MainActor
    func testStepScanningModePersistsWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("step-scan.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        store.settings.scanEnabled = true
        store.settings.scanMode = .step
        store.settings.scanPattern = .rowColumn
        store.settings.scanCueMode = .woodblock
        store.settings.scanCueVoiceIdentifier = "test-voice"
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.scanMode, .step)
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.scanPattern, .rowColumn)
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.scanCueMode, .woodblock)
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.scanCueVoiceIdentifier, "test-voice")

        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertEqual(store.settings.scanMode, .automatic)
        XCTAssertEqual(store.settings.scanPattern, .sequential)
        XCTAssertEqual(store.settings.scanCueMode, .off)
        XCTAssertEqual(store.settings.scanCueVoiceIdentifier, "")
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.settings.scanMode, .step)
        XCTAssertEqual(store.settings.scanPattern, .rowColumn)
        XCTAssertEqual(store.settings.scanCueMode, .woodblock)
        XCTAssertEqual(store.settings.scanCueVoiceIdentifier, "test-voice")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertTrue(restored.settings.scanEnabled)
        XCTAssertEqual(restored.settings.scanMode, .step)
        XCTAssertEqual(restored.settings.scanPattern, .rowColumn)
        XCTAssertEqual(restored.settings.scanCueMode, .woodblock)
        XCTAssertEqual(restored.settings.scanCueVoiceIdentifier, "test-voice")
    }

    @MainActor
    func testButtonVisibilityAndDimmingStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("visibility.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        var word = try XCTUnwrap(store.items.first { $0.label == "want" })
        let oldItem = try JSONDecoder().decode(CommunicationItem.self,
            from: JSONEncoder().encode(word))
        XCTAssertEqual(oldItem.boardVisibility, .shown)
        word.visibility = .dimmed
        store.updateItem(word)
        store.settings.dimmedButtonOpacity = 0.5
        store.settings.dimmedButtonsActive = false

        let loaded = CommunicationStore(storageURL: file)
        XCTAssertEqual(loaded.items.first { $0.id == word.id }?.boardVisibility, .dimmed)
        XCTAssertEqual(loaded.settings.dimmedButtonOpacity, 0.5)
        XCTAssertFalse(loaded.settings.dimmedButtonsActive)
        XCTAssertFalse(word.isBoardSelectable(dimmedButtonsActive: false))
        XCTAssertTrue(word.isBoardSelectable(dimmedButtonsActive: true))

        XCTAssertTrue(store.addProfile("Another communicator"))
        XCTAssertEqual(store.items.first { $0.label == "want" }?.boardVisibility, .shown)
        XCTAssertTrue(store.settings.dimmedButtonsActive)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.items.first { $0.id == word.id }?.boardVisibility, .dimmed)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.first { $0.id == word.id }?.boardVisibility, .dimmed)
        XCTAssertFalse(restored.settings.dimmedButtonsActive)
    }

    @MainActor
    func testBoardButtonOrderPreservesOtherBoardsAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("order.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        let originalCore = store.items.filter { $0.category == "Core" }.map(\.id)
        let otherItems = store.items.filter { $0.category != "Core" }.map(\.id)
        XCTAssertGreaterThan(originalCore.count, 3)

        var hidden = try XCTUnwrap(store.items.first { $0.id == originalCore[1] })
        hidden.visibility = .hidden
        store.updateItem(hidden)
        XCTAssertTrue(store.moveItems(in: "Core", fromOffsets: IndexSet(integer: 1), toOffset: 0))
        let reordered = store.items.filter { $0.category == "Core" }.map(\.id)
        XCTAssertEqual(reordered.prefix(3), [originalCore[1], originalCore[0], originalCore[2]])
        XCTAssertEqual(store.items.filter { $0.category != "Core" }.map(\.id), otherItems)
        XCTAssertEqual(store.items.first { $0.id == hidden.id }?.boardVisibility, .hidden)
        XCTAssertTrue(store.moveItem(hidden.id, in: "Core", by: 1))
        XCTAssertEqual(store.items.filter { $0.category == "Core" }.map(\.id), originalCore)
        XCTAssertTrue(store.moveItem(hidden.id, in: "Core", by: -1))
        XCTAssertFalse(store.moveItems(in: "Core", fromOffsets: IndexSet(integer: 0), toOffset: 0))
        XCTAssertFalse(store.moveItems(in: "Core", fromOffsets: IndexSet(integer: 0), toOffset: -1))
        XCTAssertEqual(CommunicationStore(storageURL: file).items.filter { $0.category == "Core" }.map(\.id), reordered)

        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertEqual(store.items.filter { $0.category == "Core" }.map(\.id), originalCore)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.items.filter { $0.category == "Core" }.map(\.id), reordered)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.filter { $0.category == "Core" }.map(\.id), reordered)
    }

    @MainActor
    func testActionButtonsSpeakAndControlPictureMessageWithoutAddingTheirLabels() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("actions.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        let yes = try XCTUnwrap(store.items.first { $0.label == "yes" })
        let no = try XCTUnwrap(store.items.first { $0.label == "no" })
        XCTAssertEqual(yes.effectiveAction, .addToMessage)
        store.settings.saveHistory = true
        store.settings.autoClearAfterSpeaking = true

        store.addItem(label: "Wait", symbol: "✋", message: "I need a moment.", category: "Core",
                      imageData: nil, action: .speakImmediately)
        store.addItem(label: "Say it", symbol: "🔊", message: "", category: "Core",
                      imageData: nil, action: .speakMessage)
        store.addItem(label: "Clear board", symbol: "🧹", message: "", category: "Core",
                      imageData: nil, action: .clearMessage)
        store.addItem(label: "Delete entry", symbol: "⌫", message: "", category: "Core",
                      imageData: nil, action: .deleteLastEntry)
        store.addItem(label: "Stop voice", symbol: "🛑", message: "", category: "Core",
                      imageData: nil, action: .stopSpeaking)
        let wait = try XCTUnwrap(store.items.first { $0.label == "Wait" })
        let say = try XCTUnwrap(store.items.first { $0.label == "Say it" })
        let clear = try XCTUnwrap(store.items.first { $0.label == "Clear board" })
        let delete = try XCTUnwrap(store.items.first { $0.label == "Delete entry" })
        let stop = try XCTUnwrap(store.items.first { $0.label == "Stop voice" })

        store.select(yes)
        store.select(wait)
        store.stopSpeaking()
        XCTAssertEqual(store.composedMessage, "yes")
        XCTAssertEqual(store.history.first?.text, "I need a moment.")
        store.select(stop)
        XCTAssertEqual(store.composedMessage, "yes")
        store.select(say)
        store.stopSpeaking()
        XCTAssertEqual(store.composedMessage, "yes")
        store.select(no)
        XCTAssertEqual(store.composedMessage, "no")
        store.select(yes)
        store.select(delete)
        XCTAssertEqual(store.composedMessage, "no")
        store.select(clear)
        XCTAssertEqual(store.composedMessage, "")

        let loaded = CommunicationStore(storageURL: file)
        XCTAssertEqual(loaded.items.first { $0.id == wait.id }?.effectiveAction, .speakImmediately)
        XCTAssertEqual(loaded.items.first { $0.id == clear.id }?.effectiveAction, .clearMessage)
        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.items.first { $0.id == say.id }?.effectiveAction, .speakMessage)
        XCTAssertEqual(restored.items.first { $0.id == stop.id }?.effectiveAction, .stopSpeaking)

        XCTAssertTrue(store.addProfile("Another person"))
        XCTAssertFalse(store.items.contains { $0.id == wait.id })
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.items.first { $0.id == wait.id }?.effectiveAction, .speakImmediately)
    }

    @MainActor
    func testUndoClearRestoresDraftAcrossReloadAndExpiresAfterNewWord() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("undo-clear.json")
        let store = CommunicationStore(storageURL: file)
        store.settings.speakOnTap = false
        let yes = try XCTUnwrap(store.items.first { $0.label == "yes" })
        let no = try XCTUnwrap(store.items.first { $0.label == "no" })
        store.addItem(label: "Restore", symbol: "↩️", message: "", category: "Core",
                      imageData: nil, action: .undoClearMessage)
        let restore = try XCTUnwrap(store.items.first { $0.label == "Restore" })

        store.select(yes)
        store.settings.communicationLanguage = "es"
        store.select(no)
        XCTAssertEqual(store.messagePartLanguages, ["en", "es"])
        store.clearMessage()
        XCTAssertTrue(store.canUndoClearMessage)

        let reloaded = CommunicationStore(storageURL: file)
        XCTAssertTrue(reloaded.canUndoClearMessage)
        reloaded.select(try XCTUnwrap(reloaded.items.first { $0.id == restore.id }))
        XCTAssertEqual(reloaded.composedMessage, "yes no")
        XCTAssertEqual(reloaded.messagePartLanguages, ["en", "es"])
        XCTAssertEqual(reloaded.messagePartBases, ["yes", "no"])
        XCTAssertFalse(reloaded.canUndoClearMessage)

        reloaded.clearMessage()
        XCTAssertTrue(reloaded.addConversation("Second draft"))
        XCTAssertFalse(reloaded.canUndoClearMessage)
        XCTAssertTrue(reloaded.switchConversation(to: store.activeConversationID))
        XCTAssertTrue(reloaded.canUndoClearMessage)
        reloaded.select(yes)
        XCTAssertFalse(reloaded.canUndoClearMessage)
        reloaded.select(try XCTUnwrap(reloaded.items.first { $0.id == restore.id }))
        XCTAssertEqual(reloaded.composedMessage, "sí")
    }

    @MainActor
    func testPictureMessageKeepsButtonPicturesAcrossReloadAndUndoClear() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("picture-message.json")
        let store = CommunicationStore(storageURL: file)
        store.settings.speakOnTap = false
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        store.addItem(label: "My cup", symbol: "🥤", message: "my cup", category: "Core",
                      imageData: imageData)
        let cup = try XCTUnwrap(store.items.first { $0.label == "My cup" })
        store.select(cup)
        XCTAssertEqual(store.pictureMessageTokens, [
            PictureMessageToken(text: "my cup", symbol: "🥤", imageData: imageData)
        ])

        let reloaded = CommunicationStore(storageURL: file)
        XCTAssertEqual(reloaded.messagePartItemIDs, [cup.id])
        XCTAssertEqual(reloaded.pictureMessageTokens.first?.imageData, imageData)
        reloaded.clearMessage()
        XCTAssertTrue(reloaded.pictureMessageTokens.isEmpty)
        reloaded.undoClearMessage()
        XCTAssertEqual(reloaded.pictureMessageTokens.first?.symbol, "🥤")
        XCTAssertEqual(reloaded.pictureMessageTokens.first?.imageData, imageData)

        let oldDraft = ConversationDraft(name: "Old", messageParts: ["hello"],
                                         messagePartLanguages: ["en"])
        let legacy = try JSONDecoder().decode(ConversationDraft.self, from: JSONEncoder().encode(oldDraft))
        XCTAssertNil(legacy.messagePartItemIDs)
    }

    @MainActor
    func testComposedTextCanReplaceExistingButtonSpeechWithoutChangingItsPicture() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("store-on-button.json")
        let store = CommunicationStore(storageURL: file)
        store.settings.speakOnTap = false
        store.addItem(label: "Personal", symbol: "⭐️", message: "Old words", category: "Core",
                      imageData: nil, audioData: Data([1, 2, 3]),
                      phraseOptions: [CardPhrase(text: "Old choice")])
        let personal = try XCTUnwrap(store.items.first { $0.label == "Personal" })
        XCTAssertTrue(store.storeMessageOnButton("  Please wait for me  ", itemID: personal.id, language: "en"))
        let changed = try XCTUnwrap(store.items.first { $0.id == personal.id })
        XCTAssertEqual(changed.label, "Personal")
        XCTAssertEqual(changed.symbol, "⭐️")
        XCTAssertEqual(changed.message, "Please wait for me")
        XCTAssertNil(changed.audioData)
        XCTAssertTrue((changed.phraseOptions ?? []).isEmpty)
        store.select(changed)
        XCTAssertEqual(store.composedMessage, "Please wait for me")

        XCTAssertTrue(store.storeMessageOnButton("Espere por favor", itemID: personal.id, language: "es"))
        XCTAssertEqual(store.items.first { $0.id == personal.id }?.message, "Please wait for me")
        XCTAssertEqual(store.translation(for: changed, language: "es")?.message, "Espere por favor")
        XCTAssertFalse(store.storeMessageOnButton(" ", itemID: personal.id, language: "en"))
        XCTAssertFalse(store.storeMessageOnButton("Unsupported", itemID: personal.id, language: "fr"))

        store.addItem(label: "Folder", symbol: "📂", message: "Folder", category: "Core",
                      imageData: nil, destinationBoard: "Needs", action: .openBoard)
        let folder = try XCTUnwrap(store.items.first { $0.label == "Folder" })
        XCTAssertFalse(store.storeMessageOnButton("No change", itemID: folder.id, language: "en"))
        let reloaded = CommunicationStore(storageURL: file)
        XCTAssertEqual(reloaded.items.first { $0.id == personal.id }?.message, "Please wait for me")
        XCTAssertEqual(reloaded.translation(for: changed, language: "es")?.message, "Espere por favor")
    }

    @MainActor
    func testPersonalButtonColorsPersistWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("button-colors.json")
        let store = CommunicationStore(storageURL: file)
        store.addItem(label: "Color cue", symbol: "🎨", message: "Color cue", category: "Core",
                      imageData: nil, backgroundColorHex: "#abc", borderColorHex: "rgba(33, 66, 99, 0.5)")
        let item = try XCTUnwrap(store.items.first { $0.label == "Color cue" })
        XCTAssertEqual(item.backgroundColorHex, "#AABBCC")
        XCTAssertEqual(item.borderColorHex, "#21426380")

        let reloaded = CommunicationStore(storageURL: file)
        XCTAssertEqual(reloaded.items.first { $0.id == item.id }?.backgroundColorHex, "#AABBCC")
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.first { $0.id == item.id }?.borderColorHex, "#21426380")

        var changed = item
        changed.backgroundColorHex = "invalid"
        store.updateItem(changed)
        XCTAssertNil(store.items.first { $0.id == item.id }?.backgroundColorHex)
        XCTAssertEqual(store.items.first { $0.id == item.id }?.borderColorHex, "#21426380")
    }

    @MainActor
    func testBoardHintsSettingStaysWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        store.settings.showBoardSuggestions = true
        XCTAssertTrue(store.addProfile("Another person"))
        XCTAssertFalse(store.settings.showBoardSuggestions)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertTrue(store.settings.showBoardSuggestions)
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.showBoardSuggestions)
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertTrue(imported.settings.showBoardSuggestions)
    }

    @MainActor
    func testLetterOrdersIncludeEveryLetterAndPersistPerProfile() throws {
        let english = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init))
        let spanish = Set("ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".map(String.init))
        for order in LetterOrder.allCases {
            let englishKeys = order.letters(language: "en")
            let spanishKeys = order.letters(language: "es")
            XCTAssertEqual(englishKeys.count, 26)
            XCTAssertEqual(Set(englishKeys), english)
            XCTAssertEqual(spanishKeys.count, 27)
            XCTAssertEqual(Set(spanishKeys), spanish)
        }
        XCTAssertEqual(LetterOrder.commonFirst.letters(language: "en").prefix(6), ["E", "T", "A", "O", "I", "N"])
        XCTAssertEqual(LetterOrder.commonFirst.letters(language: "es").prefix(6), ["E", "A", "O", "L", "S", "N"])

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        store.settings.letterOrder = .commonFirst
        store.settings.groupedKeyboardKeys = true
        store.settings.groupedPictureBoard = true
        XCTAssertTrue(store.addProfile("Another communicator"))
        XCTAssertEqual(store.settings.letterOrder, .alphabetical)
        XCTAssertFalse(store.settings.groupedKeyboardKeys)
        XCTAssertFalse(store.settings.groupedPictureBoard)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.settings.letterOrder, .commonFirst)
        XCTAssertTrue(store.settings.groupedKeyboardKeys)
        XCTAssertTrue(store.settings.groupedPictureBoard)
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.letterOrder, .commonFirst)
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.groupedKeyboardKeys)
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.groupedPictureBoard)

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.settings.letterOrder, .commonFirst)
        XCTAssertTrue(imported.settings.groupedKeyboardKeys)
        XCTAssertTrue(imported.settings.groupedPictureBoard)
    }

    @MainActor
    func testQwertyRowsIncludeSpanishNAndSurviveBackup() throws {
        let rows = LetterOrder.qwerty.qwertyRows(language: "en")
        XCTAssertEqual(rows.map { $0.joined() }, ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"])
        XCTAssertEqual(LetterOrder.qwerty.qwertyRows(language: "es")[1].last, "Ñ")
        XCTAssertEqual(LetterOrder.qwerty.letters(language: "en").first, "Q")
        XCTAssertEqual(LetterOrder.qwerty.letters(language: "es").count, 27)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("qwerty.json")
        let store = CommunicationStore(storageURL: file)
        let original = store.activeProfileID
        store.settings.letterOrder = .qwerty
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertEqual(store.settings.letterOrder, .alphabetical)
        XCTAssertTrue(store.switchProfile(to: original))
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.letterOrder, .qwerty)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.letterOrder, .qwerty)
    }

    @MainActor
    func testCustomLetterOrdersAreCompleteLanguageSpecificAndProfileScoped() throws {
        var settings = AppSettings()
        settings.setCustomLetters(["Z", "Z", "?", "A"], language: "en")
        XCTAssertEqual(settings.orderedLetters(language: "en").prefix(4), ["Z", "A", "B", "C"])
        XCTAssertEqual(Set(settings.orderedLetters(language: "en")).count, 26)
        XCTAssertEqual(settings.orderedLetters(language: "es").count, 27)
        settings.setCustomLetters(["Ñ", "E"], language: "es")
        XCTAssertEqual(settings.orderedLetters(language: "es").prefix(2), ["Ñ", "E"])
        XCTAssertEqual(settings.orderedLetters(language: "en").prefix(2), ["Z", "A"])

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let original = store.activeProfileID
        store.settings = settings
        XCTAssertTrue(store.addProfile("Another communicator"))
        XCTAssertEqual(store.settings.letterOrder, .alphabetical)
        XCTAssertEqual(store.settings.orderedLetters(language: "en").first, "A")
        XCTAssertTrue(store.switchProfile(to: original))
        XCTAssertEqual(store.settings.orderedLetters(language: "en").first, "Z")
        XCTAssertEqual(store.settings.orderedLetters(language: "es").first, "Ñ")

        let reopened = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertEqual(reopened.settings.letterOrder, .custom)
        XCTAssertEqual(reopened.settings.orderedLetters(language: "es").first, "Ñ")
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.settings.orderedLetters(language: "en").first, "Z")
        XCTAssertEqual(imported.settings.orderedLetters(language: "es").first, "Ñ")
    }

    func testOlderBackupWithoutHistoryOrStoriesStillLoads() throws {
        let current = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                 phrases: StarterVocabulary.phrases, settings: AppSettings())
        let encoded = try JSONEncoder().encode(current)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "history")
        object.removeValue(forKey: "feelingsLog")
        object.removeValue(forKey: "stories")
        object.removeValue(forKey: "categories")
        object.removeValue(forKey: "passport")
        object.removeValue(forKey: "choiceBoards")
        object.removeValue(forKey: "sceneBoards")
        object.removeValue(forKey: "weeklyPlan")
        object.removeValue(forKey: "wordTranslations")
        let olderData = try JSONSerialization.data(withJSONObject: object)
        let restored = try JSONDecoder().decode(StoredData.self, from: olderData)
        XCTAssertEqual(restored.items.count, StarterVocabulary.items.count)
        XCTAssertTrue(restored.history.isEmpty)
        XCTAssertTrue(restored.feelingsLog.isEmpty)
        XCTAssertTrue(restored.stories.isEmpty)
        XCTAssertTrue(restored.passport.isEmpty)
        XCTAssertEqual(restored.categories, StarterVocabulary.categories)
        XCTAssertEqual(restored.choiceBoards.count, 2)
        XCTAssertTrue(restored.sceneBoards.isEmpty)
        XCTAssertTrue(restored.weeklyPlan.days.allSatisfy { $0.activities.isEmpty })
        XCTAssertNotNil(restored.wordTranslations[StarterVocabulary.items[0].id.uuidString]?["es"])
    }

    @MainActor
    func testPassportStaysWithProfileAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        var passport = CommunicationPassport()
        passport.name = "Alex"
        passport.communicationMethods = "I use this board and gestures."
        passport.helpfulSupport = "Please wait for me to finish."
        store.updatePassport(passport)

        XCTAssertTrue(store.addProfile("Other person"))
        XCTAssertTrue(store.passport.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.passport, passport)
        XCTAssertEqual(CommunicationStore(storageURL: file).passport, passport)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.passport, passport)
        XCTAssertTrue(restored.passport.shareText.contains("Please wait for me to finish."))
    }

    @MainActor
    func testPersonalBoardSurvivesRenameAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(store.addBoard("Pets"))
        XCTAssertFalse(store.addBoard("pets"))
        store.addItem(label: "My cat", symbol: "🐈", message: "I want my cat", category: "Pets", imageData: nil)
        XCTAssertFalse(store.deleteBoard("Pets"))
        XCTAssertTrue(store.renameBoard("Pets", to: "Animals"))
        XCTAssertEqual(store.items.first(where: { $0.label == "My cat" })?.category, "Animals")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(store.backupData())
        XCTAssertTrue(restored.categories.contains("Animals"))
        XCTAssertEqual(restored.items.first(where: { $0.label == "My cat" })?.category, "Animals")
    }

    @MainActor
    func testBoardButtonSizesInheritDefaultAndPersistAcrossProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        store.settings.tileSize = .compact
        XCTAssertEqual(store.tileSize(for: "Core"), .compact)
        XCTAssertEqual(store.tileSize(for: "Favorites"), .compact)
        XCTAssertTrue(store.addBoard("Pets"))
        store.setTileSize(.large, for: "Pets")
        XCTAssertEqual(store.tileSize(for: "Pets"), .large)
        XCTAssertTrue(store.renameBoard("Pets", to: "Animals"))
        XCTAssertNil(store.settings.boardTileSizes["Pets"])
        XCTAssertEqual(store.tileSize(for: "Animals"), .large)
        store.settings.tileSize = .standard
        XCTAssertEqual(store.tileSize(for: "Core"), .standard)
        XCTAssertEqual(store.tileSize(for: "Animals"), .large)

        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertEqual(store.tileSize(for: "Core"), .standard)
        XCTAssertFalse(store.categories.contains("Animals"))
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.tileSize(for: "Animals"), .large)

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.tileSize(for: "Animals"), .large)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.tileSize(for: "Animals"), .large)
        restored.setTileSize(nil, for: "Animals")
        XCTAssertEqual(restored.tileSize(for: "Animals"), .standard)
        restored.setTileSize(.large, for: "Animals")
        XCTAssertTrue(restored.deleteBoard("Animals"))
        XCTAssertNil(restored.settings.boardTileSizes["Animals"])
    }

    @MainActor
    func testFixedBoardGridsInheritRenameAndSurviveProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        XCTAssertNil(store.gridLayout(for: "Core"))
        store.setDefaultGridLayout(BoardGridLayout(columns: 3, rows: 4))
        XCTAssertEqual(store.gridLayout(for: "Core")?.pageCapacity, 12)
        XCTAssertNil(store.gridLayout(for: "Favorites"))
        XCTAssertTrue(store.addBoard("Pets"))
        store.setGridLayout(BoardGridLayout(columns: 2, rows: 2), for: "Pets")
        XCTAssertEqual(store.gridLayout(for: "Pets"), BoardGridLayout(columns: 2, rows: 2))
        XCTAssertTrue(store.renameBoard("Pets", to: "Animals"))
        XCTAssertNil(store.settings.boardGridLayouts["Pets"])
        XCTAssertEqual(store.gridLayout(for: "Animals"), BoardGridLayout(columns: 2, rows: 2))
        store.setDefaultGridLayout(BoardGridLayout(columns: 4, rows: 3))
        XCTAssertEqual(store.gridLayout(for: "Core"), BoardGridLayout(columns: 4, rows: 3))
        XCTAssertEqual(store.gridLayout(for: "Animals"), BoardGridLayout(columns: 2, rows: 2))

        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertNil(store.gridLayout(for: "Core"))
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.gridLayout(for: "Animals"), BoardGridLayout(columns: 2, rows: 2))
        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.gridLayout(for: "Core"), BoardGridLayout(columns: 4, rows: 3))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.gridLayout(for: "Animals"), BoardGridLayout(columns: 2, rows: 2))
        restored.setGridLayout(nil, for: "Animals")
        XCTAssertEqual(restored.gridLayout(for: "Animals"), BoardGridLayout(columns: 4, rows: 3))
        restored.setGridLayout(BoardGridLayout(columns: 2, rows: 2), for: "Animals")
        XCTAssertTrue(restored.deleteBoard("Animals"))
        XCTAssertNil(restored.settings.boardGridLayouts["Animals"])
    }

    func testFixedGridDimensionsClampWhenDecoded() throws {
        let layout = try JSONDecoder().decode(BoardGridLayout.self,
                                              from: Data(#"{"columns":99,"rows":0}"#.utf8))
        XCTAssertEqual(layout, BoardGridLayout(columns: 16, rows: 1))
        XCTAssertEqual(layout.pageCapacity, 16)
    }

    func testFixedGridPagesCoverEveryButtonPositionOnce() {
        let layout = BoardGridLayout(columns: 3, rows: 4)
        let positions = Array(0..<37)
        XCTAssertEqual(layout.pageCount(for: positions.count), 4)
        let pages = (0..<layout.pageCount(for: positions.count)).map {
            Array(positions[layout.range(for: $0, itemCount: positions.count)])
        }
        XCTAssertEqual(pages.map(\.count), [12, 12, 12, 1])
        XCTAssertEqual(pages.flatMap { $0 }, positions)
        XCTAssertEqual(layout.pageCount(for: 0), 1)
        XCTAssertEqual(layout.range(for: 0, itemCount: 0), 0..<0)
        XCTAssertEqual(layout.range(for: 99, itemCount: 37), 36..<37)
    }

    func testLargeFixedGridPagesPreserveAllPositions() {
        for layout in [BoardGridLayout(columns: 12, rows: 12),
                       BoardGridLayout(columns: 16, rows: 16)] {
            let count = layout.pageCapacity + 1
            XCTAssertEqual(layout.pageCount(for: count), 2)
            XCTAssertEqual(layout.range(for: 0, itemCount: count), 0..<layout.pageCapacity)
            XCTAssertEqual(layout.range(for: 1, itemCount: count), layout.pageCapacity..<count)
            XCTAssertEqual(layout.range(for: 99, itemCount: count), layout.pageCapacity..<count)
        }
    }

    @MainActor
    func testLinkedBoardRenamesAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(store.addBoard("Pets"))
        store.addItem(label: "My pets", symbol: "🐾", message: "My pets", category: "Core",
                      imageData: nil, destinationBoard: "Pets", linkBehavior: .visit)
        let link = try XCTUnwrap(store.items.first(where: { $0.label == "My pets" }))
        store.select(link)
        XCTAssertTrue(store.messageParts.isEmpty)
        XCTAssertFalse(store.deleteBoard("Pets"))
        XCTAssertTrue(store.renameBoard("Pets", to: "Animals"))
        XCTAssertEqual(store.items.first(where: { $0.label == "My pets" })?.destinationBoard, "Animals")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.first(where: { $0.label == "My pets" })?.destinationBoard, "Animals")
        XCTAssertEqual(restored.items.first(where: { $0.label == "My pets" })?.linkBehavior, .visit)
        XCTAssertFalse(restored.deleteBoard("Animals"))
        restored.deleteItem(try XCTUnwrap(restored.items.first(where: { $0.label == "My pets" })))
        XCTAssertTrue(restored.deleteBoard("Animals"))
    }

    @MainActor
    func testProfilesKeepVocabularyAndDraftsSeparateAcrossLaunches() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("data.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        store.addItem(label: "Alice's cat", symbol: "🐈", message: "Alice's cat", category: "People", imageData: nil)
        store.select(try XCTUnwrap(store.items.first(where: { $0.label == "Alice's cat" })))
        store.typedMessage = "Private draft"

        XCTAssertTrue(store.addProfile("Sam"))
        let secondID = store.activeProfileID
        XCTAssertNotEqual(firstID, secondID)
        XCTAssertFalse(store.items.contains { $0.label == "Alice's cat" })
        XCTAssertTrue(store.messageParts.isEmpty)
        XCTAssertTrue(store.typedMessage.isEmpty)
        XCTAssertTrue(store.addBoard("Sam's interests"))
        store.addItem(label: "Trains", symbol: "🚂", message: "I like trains", category: "Sam's interests", imageData: nil)

        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertTrue(store.items.contains { $0.label == "Alice's cat" })
        XCTAssertFalse(store.items.contains { $0.label == "Trains" })
        XCTAssertFalse(store.categories.contains("Sam's interests"))

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.activeProfileID, firstID)
        XCTAssertEqual(relaunched.profiles.count, 2)
        XCTAssertTrue(relaunched.switchProfile(to: secondID))
        XCTAssertTrue(relaunched.items.contains { $0.label == "Trains" })
        XCTAssertTrue(relaunched.categories.contains("Sam's interests"))
    }

    @MainActor
    func testExistingVocabularyBecomesFirstProfileWithoutLosingData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("legacy.json")
        var oldData = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                 phrases: StarterVocabulary.phrases, settings: AppSettings())
        oldData.items.append(.init(label: "Legacy word", symbol: "✨", message: "Legacy word",
                                   category: "Core", isCustom: true))
        try JSONEncoder().encode(oldData).write(to: file)

        let store = CommunicationStore(storageURL: file)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertTrue(store.items.contains { $0.label == "Legacy word" })
        XCTAssertTrue(store.addProfile("Second voice"))
        XCTAssertFalse(store.items.contains { $0.label == "Legacy word" })
        XCTAssertTrue(store.switchProfile(to: store.profiles[0].id))
        XCTAssertTrue(store.items.contains { $0.label == "Legacy word" })
    }

    @MainActor
    func testEmptyProfileDirectoryIsRepaired() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("data.json")
        let index = file.deletingPathExtension().appendingPathExtension("profiles.json")
        try JSONEncoder().encode(ProfileDirectory(profiles: [], activeProfileID: UUID()))
            .write(to: index)

        let store = CommunicationStore(storageURL: file)
        XCTAssertEqual(store.profiles.count, 1)
        let repaired = try JSONDecoder().decode(ProfileDirectory.self, from: Data(contentsOf: index))
        XCTAssertEqual(repaired.profiles, store.profiles)
        XCTAssertEqual(repaired.activeProfileID, store.activeProfileID)
    }

    @MainActor
    func testBackupAndDeletionApplyToSelectedProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let firstID = store.activeProfileID
        store.addItem(label: "First word", symbol: "1️⃣", message: "First word", category: "Core", imageData: nil)
        XCTAssertTrue(store.addProfile("Second"))
        let secondID = store.activeProfileID
        store.addItem(label: "Second word", symbol: "2️⃣", message: "Second word", category: "Core", imageData: nil)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertTrue(restored.items.contains { $0.label == "Second word" })
        XCTAssertFalse(restored.items.contains { $0.label == "First word" })

        XCTAssertTrue(store.deleteProfile(id: secondID))
        XCTAssertEqual(store.activeProfileID, firstID)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertTrue(store.items.contains { $0.label == "First word" })
        XCTAssertFalse(store.deleteProfile(id: firstID))
    }

    @MainActor
    func testRecordedVoiceSurvivesBackupAndReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let recording = Data([0, 1, 2, 3, 4])
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        source.addItem(label: "Hello", symbol: "👋", message: "Hello there", category: "Core",
                       imageData: nil, audioData: recording)
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
            .items.first(where: { $0.label == "Hello" })?.audioData, recording)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.items.first(where: { $0.label == "Hello" })?.audioData, recording)
    }

    @MainActor
    func testMessageHistoryRequiresOptInAndCanBeCleared() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("data.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CommunicationStore(storageURL: file)
        store.speak("A private message", saveToHistory: true)
        XCTAssertTrue(store.history.isEmpty)

        store.settings.saveHistory = true
        store.speak("Please wait", saveToHistory: true)
        XCTAssertEqual(CommunicationStore(storageURL: file).history.map(\.text), ["Please wait"])

        store.clearHistory()
        XCTAssertTrue(CommunicationStore(storageURL: file).history.isEmpty)
    }

    @MainActor
    func testHistoryPauseStopsNewEntriesAndStaysWithProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("history-pause.json")
        let store = CommunicationStore(storageURL: file)
        let originalProfile = store.activeProfileID
        store.settings.saveHistory = true
        store.speak("First message", saveToHistory: true)
        XCTAssertEqual(store.history.map(\.text), ["First message"])

        store.settings.historyPaused = true
        store.speak("Typed while paused", saveToHistory: true)
        let yes = try XCTUnwrap(store.items.first { $0.label == "yes" })
        store.select(yes)
        store.speakMessage()
        XCTAssertEqual(store.history.map(\.text), ["First message"])
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.historyPaused)

        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertFalse(store.settings.historyPaused)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertTrue(store.settings.historyPaused)
        store.settings.historyPaused = false
        store.speak("Recording resumed", saveToHistory: true)
        XCTAssertEqual(store.history.map(\.text).prefix(2), ["Recording resumed", "First message"])

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        store.settings.historyPaused = true
        try imported.importBackup(store.backupData())
        XCTAssertTrue(imported.settings.historyPaused)
        XCTAssertEqual(imported.history.map(\.text).prefix(2), ["Recording resumed", "First message"])
    }

    @MainActor
    func testVisualStoriesPersistInBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let id = try XCTUnwrap(store.addStory("A new place"))
        store.addStoryPage(storyID: id, text: "I can ask what happens next.", symbol: "❓", imageData: nil)
        let backup = try store.backupData()

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.stories.first?.title, "A new place")
        XCTAssertEqual(restored.stories.first?.pages.first?.text, "I can ask what happens next.")
    }

    @MainActor
    func testRoutineCanBeReordered() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("data.json"))
        let first = store.routines[0].id
        store.moveRoutineSteps(from: IndexSet(integer: 0), to: store.routines.count)
        XCTAssertEqual(store.routines.last?.id, first)
    }

    @MainActor
    func testCustomCommunicationPersistsAcrossLaunches() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = directory.appendingPathComponent("data.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = CommunicationStore(storageURL: file)
        first.addItem(label: "My dog", symbol: "🐶", message: "I want to see my dog",
                      category: "People", imageData: nil)
        first.addPhrase("Please wait for me")
        first.addRoutineStep("Feed the dog")

        let backup = try first.backupData()

        let second = CommunicationStore(storageURL: file)
        XCTAssertTrue(second.items.contains { $0.label == "My dog" && $0.message == "I want to see my dog" })
        XCTAssertTrue(second.phrases.contains { $0.text == "Please wait for me" })
        XCTAssertTrue(second.routines.contains { $0.title == "Feed the dog" })

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(backup)
        XCTAssertTrue(imported.items.contains { $0.label == "My dog" })
    }

    @MainActor
    func testChoiceBoardsStayWithProfileAndSurviveBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        XCTAssertEqual(store.choiceBoards.count, 2)

        let photo = Data([1, 2, 3, 4])
        let board = ChoiceBoard(title: "Choose lunch", options: [
            ChoiceOption(label: "Soup", imageData: photo),
            ChoiceOption(label: "Rice")
        ])
        XCTAssertTrue(store.saveChoiceBoard(board))
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertFalse(store.choiceBoards.contains { $0.id == board.id })
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.choiceBoards.first(where: { $0.id == board.id })?.options[0].imageData, photo)
        XCTAssertEqual(CommunicationStore(storageURL: file).choiceBoards.first(where: { $0.id == board.id }), board)

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.choiceBoards.first(where: { $0.id == board.id }), board)
        imported.deleteChoiceBoard(id: board.id)
        XCTAssertFalse(imported.choiceBoards.contains { $0.id == board.id })
    }

    @MainActor
    func testChoiceBoardRequiresDistinctValidChoices() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("data.json"))
        let soup = ChoiceOption(label: "Soup")
        XCTAssertFalse(store.saveChoiceBoard(ChoiceBoard(title: "Only one", options: [soup])))
        XCTAssertFalse(store.saveChoiceBoard(ChoiceBoard(title: "Repeated", options: [soup, soup])))
        XCTAssertTrue(store.saveChoiceBoard(ChoiceBoard(title: "Lunch", options: [soup, ChoiceOption(label: "Rice")])))
        XCTAssertFalse(store.saveChoiceBoard(ChoiceBoard(title: "lunch", options: [ChoiceOption(label: "Tea"), ChoiceOption(label: "Milk")])))
    }

    func testChoiceOptionTracksWordEditsAndKeepsDeletedWordCopy() {
        var word = CommunicationItem(label: "Soup", symbol: "🥣", message: "Soup", category: "Food")
        let choice = ChoiceOption(item: word)
        word.label = "Tomato soup"
        word.message = "I would like tomato soup"
        XCTAssertEqual(choice.resolved(using: [word]).label, "Tomato soup")
        XCTAssertEqual(choice.resolved(using: [word]).message, "I would like tomato soup")
        XCTAssertEqual(choice.resolved(using: []).label, "Soup")
    }

    @MainActor
    func testChoiceBoardEditingLockBlocksChangesAndStaysWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("locked.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfileID = store.activeProfileID
        let board = ChoiceBoard(title: "Lunch", options: [ChoiceOption(label: "Soup"), ChoiceOption(label: "Rice")])
        XCTAssertTrue(store.saveChoiceBoard(board))

        store.settings.choiceBoardEditingLocked = true
        XCTAssertFalse(store.saveChoiceBoard(ChoiceBoard(title: "Dinner", options: board.options)))
        store.deleteChoiceBoard(id: board.id)
        XCTAssertTrue(store.choiceBoards.contains { $0.id == board.id })

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertTrue(restored.settings.choiceBoardEditingLocked)
        restored.deleteChoiceBoard(id: board.id)
        XCTAssertTrue(restored.choiceBoards.contains { $0.id == board.id })

        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertFalse(store.settings.choiceBoardEditingLocked)
        XCTAssertTrue(store.switchProfile(to: firstProfileID))
        XCTAssertTrue(store.settings.choiceBoardEditingLocked)
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.choiceBoardEditingLocked)
        store.settings.choiceBoardEditingLocked = false
        store.deleteChoiceBoard(id: board.id)
        XCTAssertFalse(store.choiceBoards.contains { $0.id == board.id })
    }

    func testQuickChoicesAcceptDistinctOptionsAndReusePersonalPictures() {
        let pictured = CommunicationItem(label: "Water", symbol: "💧", message: "I want water", category: "Drinks", imageData: Data([1, 2, 3]))
        let draft = QuickChoiceDraft(question: " What would you like? ", choices: " Water, Juice\nMilk ")
        XCTAssertTrue(draft.isValid)
        let board = draft.board(using: [pictured])
        XCTAssertEqual(board?.title, "What would you like?")
        XCTAssertEqual(board?.options.map(\.label), ["Water", "Juice", "Milk"])
        XCTAssertEqual(board?.options.first?.imageData, pictured.imageData)
        XCTAssertEqual(board?.options.first?.message, "I want water")
        XCTAssertEqual(board?.options[1].symbol, "💬")
    }

    func testQuickChoicesRejectDuplicatesAndOutOfRangeCounts() {
        XCTAssertFalse(QuickChoiceDraft(question: "", choices: "Water").isValid)
        XCTAssertFalse(QuickChoiceDraft(question: "", choices: "Water, water").isValid)
        XCTAssertFalse(QuickChoiceDraft(question: "", choices: "Café, cafe").isValid)
        XCTAssertFalse(QuickChoiceDraft(question: "", choices: "1,2,3,4,5,6,7,8,9").isValid)
        XCTAssertEqual(QuickChoiceDraft(question: "", choices: "Soup, Rice").board(using: [])?.title, "Make a choice")
    }

    @MainActor
    func testCommunicationSelectionAndSliderAdjustmentCoalesceFullProfileWrites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("performance.json")
        let store = CommunicationStore(storageURL: file)
        store.settings.recentPictureWordsEnabled = true
        store.settings.highlightWordsForTimeOfDay = true
        let water = try XCTUnwrap(store.items.first { $0.label == "water" })
        let beforeSelection = store.persistenceWriteCount
        store.select(water)
        XCTAssertEqual(store.persistenceWriteCount, beforeSelection + 1)
        XCTAssertEqual(CommunicationStore(storageURL: file).messageParts.last, water.message)

        let beforeAdjustment = store.persistenceWriteCount
        store.beginSettingsAdjustment()
        store.settings.speechVolume = 0.75
        store.settings.speechVolume = 0.55
        XCTAssertEqual(store.persistenceWriteCount, beforeAdjustment)
        store.endSettingsAdjustment()
        XCTAssertEqual(store.persistenceWriteCount, beforeAdjustment + 1)
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.speechVolume, 0.55)
    }
}
