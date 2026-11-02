import XCTest
@testable import OpenVoice

final class VocabularyLibraryTests: XCTestCase {
    func testCatalogHasDistinctBilingualPagesAndWords() {
        XCTAssertGreaterThanOrEqual(VocabularyLibrary.pages.count, 8)
        XCTAssertEqual(Set(VocabularyLibrary.pages.map(\.id)).count, VocabularyLibrary.pages.count)
        XCTAssertEqual(Set(VocabularyLibrary.pages.map { $0.title.lowercased() }).count,
                       VocabularyLibrary.pages.count)
        for page in VocabularyLibrary.pages {
            XCTAssertFalse(page.title.isEmpty)
            XCTAssertFalse(page.icon.isEmpty)
            XCTAssertGreaterThanOrEqual(page.words.count, 10)
            XCTAssertEqual(Set(page.words.map { $0.label.lowercased() }).count, page.words.count)
            XCTAssertFalse(StarterVocabulary.categories.contains(page.title))
            for word in page.words {
                XCTAssertFalse(word.label.isEmpty)
                XCTAssertFalse(word.symbol.isEmpty)
                XCTAssertFalse(word.spanishLabel.isEmpty)
            }
        }
    }

    @MainActor
    func testAddingPageCreatesBilingualBoardAndSurvivesProfilesAndBackups() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: url)
        let page = try XCTUnwrap(VocabularyLibrary.page(id: "school"))
        XCTAssertEqual(source.missingLibraryWordCount(for: page), page.words.count)
        let result = try XCTUnwrap(source.addLibraryPage(id: page.id))
        XCTAssertTrue(result.createdBoard)
        XCTAssertEqual(result.boardName, page.title)
        XCTAssertEqual(result.addedCount, page.words.count)
        XCTAssertEqual(source.boardIcon(for: page.title), page.icon)
        XCTAssertEqual(source.items.filter { $0.category == page.title }.count, page.words.count)
        let word = try XCTUnwrap(source.items.first { $0.category == page.title && $0.label == "I need help" })
        XCTAssertTrue(word.isCustom)
        XCTAssertEqual(source.translation(for: word)?.label, "Necesito ayuda")
        XCTAssertEqual(source.translation(for: word)?.message, "Necesito ayuda")
        XCTAssertEqual(source.missingLibraryWordCount(for: page), 0)

        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertFalse(source.categories.contains(page.title))
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.items.filter { $0.category == page.title }.count, page.words.count)
        XCTAssertTrue(CommunicationStore(storageURL: url).categories.contains(page.title))

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.translation(for: try XCTUnwrap(restored.items.first { $0.label == "I need help" }))?.label,
                       "Necesito ayuda")
        let selected = CommunicationStore(storageURL: directory.appendingPathComponent("selected.json"))
        let importedNames = try selected.addBoards(fromBackup: source.backupData(), selectedBoards: [page.title])
        let importedName = try XCTUnwrap(importedNames.first)
        XCTAssertEqual(selected.items.filter { $0.category == importedName }.count, page.words.count)
        XCTAssertEqual(selected.boardIcon(for: importedName), page.icon)
    }

    @MainActor
    func testAddingToExistingBoardPreservesPersonalWordsAndSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        XCTAssertTrue(store.addBoard("At school"))
        store.addItem(label: "I need help", symbol: "⭐️", message: "Please help with this task.",
                      category: "At school", imageData: nil,
                      spanishLabel: "Ayuda original", spanishMessage: "Ayuda original")
        XCTAssertTrue(store.setBoardIcon("🧩", for: "At school"))
        XCTAssertTrue(store.setBoardVisible(false, for: "At school"))
        let page = try XCTUnwrap(VocabularyLibrary.page(id: "school"))
        XCTAssertEqual(store.missingLibraryWordCount(for: page), page.words.count - 1)
        let result = try XCTUnwrap(store.addLibraryPage(id: page.id))
        XCTAssertFalse(result.createdBoard)
        XCTAssertEqual(result.addedCount, page.words.count - 1)
        XCTAssertEqual(store.items.filter { $0.category == "At school" }.count, page.words.count)
        XCTAssertEqual(store.boardIcon(for: "At school"), "🧩")
        XCTAssertFalse(store.visibleBoards.contains("At school"))
        let original = try XCTUnwrap(store.items.first { $0.category == "At school" && $0.label == "I need help" })
        XCTAssertEqual(original.symbol, "⭐️")
        XCTAssertEqual(original.message, "Please help with this task.")
        XCTAssertEqual(store.translation(for: original)?.label, "Ayuda original")
        XCTAssertEqual(store.addLibraryPage(id: page.id)?.addedCount, 0)
        XCTAssertEqual(store.items.filter { $0.category == "At school" }.count, page.words.count)
    }

    @MainActor
    func testUnknownPageCannotBeAdded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let previous = store.categories
        XCTAssertNil(store.addLibraryPage(id: "not-in-the-library"))
        XCTAssertEqual(store.categories, previous)
    }

    @MainActor
    func testTemplatesCreateSeparatePersistentProfilesWithAllPages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let store = CommunicationStore(storageURL: url)
        let firstProfile = store.activeProfileID
        store.addItem(label: "My personal word", symbol: "⭐️", message: "My personal word",
                      category: "Core", imageData: nil)
        let template = try XCTUnwrap(VocabularyLibrary.template(id: "school-day"))
        let result = try XCTUnwrap(store.createProfileFromLibraryTemplate(id: template.id,
                                                                          named: "  School setup  "))
        XCTAssertEqual(result.profileName, "School setup")
        XCTAssertEqual(result.pageCount, template.pageIDs.count)
        XCTAssertEqual(result.buttonCount, template.pageIDs.compactMap { VocabularyLibrary.page(id: $0) }
            .reduce(0) { $0 + $1.words.count })
        XCTAssertNotEqual(store.activeProfileID, firstProfile)
        XCTAssertFalse(store.items.contains { $0.label == "My personal word" })
        for pageID in template.pageIDs {
            let page = try XCTUnwrap(VocabularyLibrary.page(id: pageID))
            XCTAssertTrue(store.categories.contains(page.title))
            XCTAssertEqual(store.items.filter { $0.category == page.title }.count, page.words.count)
            XCTAssertEqual(store.missingLibraryWordCount(for: page), 0)
        }
        let schoolWord = try XCTUnwrap(store.items.first { $0.category == "At school" && $0.label == "I need help" })
        XCTAssertEqual(store.translation(for: schoolWord)?.label, "Necesito ayuda")

        let profileCount = store.profiles.count
        XCTAssertNil(store.createProfileFromLibraryTemplate(id: template.id, named: "school SETUP"))
        XCTAssertEqual(store.profiles.count, profileCount)
        let reloaded = CommunicationStore(storageURL: url)
        XCTAssertEqual(reloaded.activeProfileName, "School setup")
        XCTAssertTrue(reloaded.categories.contains("At school"))
        XCTAssertTrue(reloaded.switchProfile(to: firstProfile))
        XCTAssertTrue(reloaded.items.contains { $0.label == "My personal word" })
        XCTAssertFalse(reloaded.categories.contains("At school"))
    }

    @MainActor
    func testUnknownTemplateDoesNotCreateProfile() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let originalID = store.activeProfileID
        let originalCount = store.profiles.count
        XCTAssertNil(store.createProfileFromLibraryTemplate(id: "unknown", named: "New profile"))
        XCTAssertEqual(store.activeProfileID, originalID)
        XCTAssertEqual(store.profiles.count, originalCount)
        for template in VocabularyLibrary.templates {
            XCTAssertEqual(Set(template.pageIDs).count, template.pageIDs.count)
            XCTAssertTrue(template.pageIDs.allSatisfy { VocabularyLibrary.page(id: $0) != nil })
        }
    }

    @MainActor
    func testApplyingTemplateKeepsPersonalBoardsAndCreatesRestorableBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let store = CommunicationStore(storageURL: url)
        XCTAssertTrue(store.addBoard("My places"))
        store.addItem(label: "My quiet place", symbol: "🏡", message: "My quiet place",
                      category: "My places", imageData: nil)
        XCTAssertTrue(store.setBoardIcon("🌿", for: "My places"))
        let result = try store.applyLibraryTemplate(id: "school-day", mode: .keepPersonalBoards)
        XCTAssertEqual(result.pageCount, 4)
        XCTAssertEqual(result.buttonCount, 48)
        XCTAssertEqual(result.removedBoardCount, 0)
        XCTAssertEqual(Array(store.categories.prefix(5)),
                       ["Core", "At school", "Conversation", "Meals", "Safety"])
        XCTAssertTrue(store.categories.contains("My places"))
        XCTAssertTrue(store.items.contains { $0.label == "My quiet place" })
        XCTAssertEqual(store.boardIcon(for: "My places"), "🌿")
        XCTAssertEqual(try store.localBackups().first?.id, result.backupID)
        XCTAssertTrue(result.backupName.hasPrefix("Before School day"))
        let oldData = try store.localBackupData(id: result.backupID)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(oldData)
        XCTAssertTrue(restored.categories.contains("My places"))
        XCTAssertFalse(restored.categories.contains("At school"))
        XCTAssertTrue(CommunicationStore(storageURL: url).categories.contains("At school"))
    }

    @MainActor
    func testReplacingPersonalBoardsRemovesTheirLinksAndCanBeUndoneFromBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        XCTAssertTrue(store.addBoard("Old page"))
        store.addItem(label: "Old word", symbol: "⭐️", message: "Old word",
                      category: "Old page", imageData: nil, spanishLabel: "Palabra vieja")
        store.addItem(label: "Open old page", symbol: "📂", message: "Open old page",
                      category: "Core", imageData: nil, destinationBoard: "Old page")
        store.addItem(label: "Keep in Core", symbol: "💙", message: "Keep in Core",
                      category: "Core", imageData: nil)
        XCTAssertTrue(store.addPhrase("A saved phrase"))
        XCTAssertTrue(store.setBoardIcon("🧩", for: "Old page"))
        let result = try store.applyLibraryTemplate(id: "health-and-support", mode: .replacePersonalBoards)
        XCTAssertEqual(result.removedBoardCount, 1)
        XCTAssertEqual(result.pageCount, 4)
        XCTAssertEqual(result.buttonCount, 48)
        XCTAssertFalse(store.categories.contains("Old page"))
        XCTAssertFalse(store.items.contains { $0.label == "Old word" || $0.label == "Open old page" })
        XCTAssertTrue(store.items.contains { $0.label == "Keep in Core" })
        XCTAssertTrue(store.phrases.contains { $0.text == "A saved phrase" })
        XCTAssertEqual(Array(store.categories.prefix(5)),
                       ["Core", "Health visit", "Personal care", "Getting around", "Safety"])
        XCTAssertTrue(store.settings.boardIcons["Old page"] == nil)
        try store.importBackup(store.localBackupData(id: result.backupID))
        XCTAssertTrue(store.categories.contains("Old page"))
        XCTAssertTrue(store.items.contains { $0.destinationBoard == "Old page" })
        XCTAssertFalse(store.categories.contains("Health visit"))
    }

    @MainActor
    func testInvalidInPlaceTemplateDoesNotCreateBackupOrChangeBoards() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let originalBoards = store.categories
        XCTAssertThrowsError(try store.applyLibraryTemplate(id: "missing", mode: .replacePersonalBoards))
        XCTAssertEqual(store.categories, originalBoards)
        XCTAssertTrue(try store.localBackups().isEmpty)
    }

    @MainActor
    func testExpandedContextPagesAndSelfAdvocacyTemplateStayEditableAndPortable() throws {
        let newPageIDs = ["at-home", "shopping", "friends-family", "hobbies-play",
                          "sensory-needs", "technology", "rights-choices"]
        for id in newPageIDs {
            let page = try XCTUnwrap(VocabularyLibrary.page(id: id))
            XCTAssertEqual(page.words.count, 12)
            XCTAssertEqual(Set(page.words.map(\.spanishLabel)).count, 12)
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let originalProfile = store.activeProfileID
        store.addItem(label: "Personal word", symbol: "⭐️", message: "Personal word",
                      category: "Core", imageData: nil)
        let template = try XCTUnwrap(VocabularyLibrary.template(id: "self-advocacy"))
        let result = try XCTUnwrap(store.createProfileFromLibraryTemplate(id: template.id,
                                                                          named: "My choices"))
        XCTAssertEqual(result.pageCount, 4)
        XCTAssertEqual(result.buttonCount, 48)
        let consent = try XCTUnwrap(store.items.first {
            $0.category == "Rights and choices" && $0.label == "I do not consent"
        })
        XCTAssertEqual(store.translation(for: consent)?.label, "No doy mi consentimiento")
        let repeatAdd = try XCTUnwrap(store.addLibraryPage(id: "rights-choices"))
        XCTAssertEqual(repeatAdd.addedCount, 0)
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertTrue(imported.categories.contains("Rights and choices"))
        XCTAssertEqual(imported.translation(for: consent)?.label, "No doy mi consentimiento")
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertTrue(store.items.contains { $0.label == "Personal word" })
        XCTAssertFalse(store.categories.contains("Rights and choices"))
    }
}
