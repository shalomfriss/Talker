import XCTest
import UIKit

final class NavigationUITests: XCTestCase {
    @MainActor
    func testStoryBackgroundsRenderAndEditorChangesStyle() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-story-background")
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        let story = app.staticTexts["Background story test"]
        for _ in 0..<12 where !story.isHittable { app.swipeUp() }
        XCTAssertTrue(story.isHittable)
        story.tap()
        XCTAssertTrue(app.staticTexts["A gentle sky helps me feel calm."].exists)
        let sky = XCTAttachment(screenshot: app.screenshot())
        sky.name = "Sky background story page"
        sky.lifetime = .keepAlways
        add(sky)

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["This is my quiet place."].exists)
        let photo = XCTAttachment(screenshot: app.screenshot())
        photo.name = "Photo background story page"
        photo.lifetime = .keepAlways
        add(photo)

        app.buttons["Edit page"].tap()
        XCTAssertTrue(app.staticTexts["What should this page say?"].exists)
        if app.windows.firstMatch.frame.width > 700 { return }
        let picker = app.descendants(matching: .any)["story-background-style"]
        for _ in 0..<8 where !picker.isHittable { app.swipeUp() }
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        app.buttons["Soft mint"].tap()
        app.buttons["Save"].tap()
        app.buttons["Edit page"].tap()
        let savedPicker = app.descendants(matching: .any)["story-background-style"]
        for _ in 0..<8 where !savedPicker.isHittable { app.swipeUp() }
        XCTAssertTrue(savedPicker.label.contains("Soft mint"))
    }

    @MainActor
    func testStoryPhotoPickerAddsThirdPhotoWhenLibraryHasPhoto() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-story-photo-grid")
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        let story = app.staticTexts["Photo grid story test"]
        for _ in 0..<12 where !story.isHittable { app.swipeUp() }
        XCTAssertTrue(story.isHittable)
        story.tap()
        app.buttons["Edit page"].tap()
        let addMore = app.buttons["story-add-more-photos"]
        for _ in 0..<8 where !addMore.isHittable { app.swipeUp() }
        XCTAssertTrue(addMore.isHittable)
        addMore.tap()
        let firstPhoto = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        guard firstPhoto.waitForExistence(timeout: 20) else {
            throw XCTSkip("This simulator has no photo available in the picker.")
        }
        firstPhoto.tap()
        if app.buttons["Add"].exists { app.buttons["Add"].tap() }
        let added = app.buttons["story-remove-photo-3"]
        for _ in 0..<8 where !added.isHittable { app.swipeUp() }
        XCTAssertTrue(added.waitForExistence(timeout: 20))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["story-photo-grid"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Three photos after picker selection"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStoryPhotoGridRendersAndExtraPhotoCanBeRemoved() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-story-photo-grid")
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        let story = app.staticTexts["Photo grid story test"]
        for _ in 0..<12 where !story.isHittable { app.swipeUp() }
        XCTAssertTrue(story.isHittable)
        story.tap()
        let grid = app.descendants(matching: .any)["story-photo-grid"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Two-photo story page"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Edit page"].tap()
        let addMore = app.buttons["story-add-more-photos"]
        for _ in 0..<8 where !addMore.isHittable { app.swipeUp() }
        XCTAssertTrue(addMore.isHittable)
        let remove = app.buttons["story-remove-photo-2"]
        for _ in 0..<4 where !remove.isHittable { app.swipeUp() }
        XCTAssertTrue(remove.isHittable)
        remove.tap()
        app.buttons["Save"].tap()
        XCTAssertFalse(grid.exists)
        XCTAssertTrue(app.staticTexts["I can show two places."].exists)
    }

    @MainActor
    func testStoryChoiceJumpsToPageAndPreviousReturnsToDecision() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.buttons["Add story"].tap()
        let title = "Choice story \(UUID().uuidString.prefix(6))"
        let titleField = app.alerts.textFields["Story title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        app.alerts.buttons["Create"].tap()
        let storyRow = app.staticTexts[title]
        for _ in 0..<12 where !storyRow.isHittable { app.swipeUp() }
        XCTAssertTrue(storyRow.isHittable)
        storyRow.tap()
        app.buttons["Add first page"].tap()

        let pageText = app.textViews["Page text"]
        XCTAssertTrue(pageText.waitForExistence(timeout: 5))
        pageText.tap()
        pageText.typeText("Where should I go?")
        app.buttons["Save"].tap()
        app.buttons["Add page"].tap()
        pageText.tap()
        pageText.typeText("I can stay home.")
        app.buttons["Save"].tap()
        app.buttons["Add page"].tap()
        pageText.tap()
        pageText.typeText("I can go outside.")
        app.buttons["Save"].tap()

        app.buttons["Edit page"].tap()
        let addChoice = app.buttons["story-add-choice"]
        for _ in 0..<8 where !addChoice.isHittable { app.swipeUp() }
        XCTAssertTrue(addChoice.isHittable)
        addChoice.tap()
        let label = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "story-choice-label-")).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText("Go outside")
        let target = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "story-choice-target-")).firstMatch
        for _ in 0..<4 where !target.isHittable { app.swipeUp() }
        XCTAssertTrue(target.isHittable)
        target.tap()
        app.buttons["I can go outside."].tap()
        app.buttons["Save"].tap()

        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "story-choice-")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Branching story decision"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        choice.tap()
        XCTAssertTrue(app.staticTexts["3 of 3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["I can go outside."].exists)
        app.buttons["Previous"].tap()
        XCTAssertTrue(app.staticTexts["1 of 3"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSoundBoardPlaysReadyCueAndOpensPersonalSoundEditor() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        let pictures = app.buttons["Pictures"]
        if pictures.exists { pictures.tap() }
        app.buttons["Customize"].tap()
        app.buttons["open-sound-board"].tap()
        XCTAssertTrue(app.navigationBars["Sound board"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sound-board-hello"].exists)
        app.buttons["sound-board-hello"].tap()
        app.buttons["sound-board-attention"].tap()
        app.buttons["sound-board-stop"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Sound board on device"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["sound-board-add"].tap()
        XCTAssertTrue(app.textFields["sound-board-name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sound-board-save"].isEnabled)
        app.buttons["Cancel"].tap()
        app.navigationBars["Sound board"].buttons["Done"].tap()
    }

    @MainActor
    func testPictureGridPredictionTileCompletesTypedWord() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        let pictures = app.buttons["Pictures"]
        if pictures.exists { pictures.tap() }
        app.buttons["Customize"].tap()
        app.buttons["add-spelling-board"].tap()
        let draft = app.staticTexts["grid-typed-message"]
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        let clear = app.buttons["grid-clear-typed"]
        if clear.isEnabled { clear.tap() }
        let firstPrediction = app.buttons["board-key-Suggestion 1"]
        XCTAssertTrue(firstPrediction.exists)
        XCTAssertFalse(firstPrediction.isEnabled)
        app.buttons["grid-keyboard-full"].tap()
        let editor = app.textViews["Type a message"]
        editor.tap()
        editor.typeText("wa")
        app.buttons["Pictures"].tap()
        XCTAssertEqual(draft.label, "Typed message: wa")
        XCTAssertTrue(firstPrediction.isEnabled)
        let suggestedWord = firstPrediction.label
        XCTAssertTrue(suggestedWord.lowercased().hasPrefix("wa"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Prediction tiles on spelling board"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        firstPrediction.tap()
        XCTAssertEqual(draft.label, "Typed message: \(suggestedWord) ")
    }

    @MainActor
    func testQwertyBoardTypesOnPictureGrid() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        let pictures = app.buttons["Pictures"]
        if pictures.exists { pictures.tap() }
        app.buttons["Customize"].tap()
        app.buttons["add-qwerty-board"].tap()
        let draft = app.staticTexts["grid-typed-message"]
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        let clear = app.buttons["grid-clear-typed"]
        if clear.isEnabled { clear.tap() }
        app.buttons["board-key-Q"].tap()
        app.buttons["board-key-W"].tap()
        XCTAssertEqual(draft.label, "Typed message: Qw")
        app.buttons["board-key-Space"].tap()
        app.buttons["board-key-A"].tap()
        XCTAssertEqual(draft.label, "Typed message: Qw a")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "QWERTY order on picture grid"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSpellingBoardTypesOnPictureGridAndSharesTypedDraft() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        let pictures = app.buttons["Pictures"]
        if pictures.exists { pictures.tap() }
        app.buttons["Customize"].tap()
        app.buttons["add-spelling-board"].tap()
        let draft = app.staticTexts["grid-typed-message"]
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        let clear = app.buttons["grid-clear-typed"]
        if clear.isEnabled { clear.tap() }
        app.buttons["board-key-A"].tap()
        app.buttons["board-key-B"].tap()
        XCTAssertEqual(draft.label, "Typed message: Ab")
        app.buttons["board-key-Space"].tap()
        app.buttons["board-key-B"].tap()
        XCTAssertEqual(draft.label, "Typed message: Ab b")
        app.buttons["board-key-Delete"].tap()
        XCTAssertEqual(draft.label, "Typed message: Ab ")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Spelling on picture grid"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["grid-keyboard-full"].tap()
        XCTAssertEqual(app.textViews["Type a message"].value as? String, "Ab ")
        app.buttons["Pictures"].tap()
        XCTAssertEqual(draft.label, "Typed message: Ab ")
        app.buttons["board-key-Left"].tap()
        XCTAssertEqual(draft.value as? String, "Cursor 2 of 3")
        app.buttons["board-key-C"].tap()
        XCTAssertEqual(draft.label, "Typed message: Abc ")
        app.buttons["board-key-Delete"].tap()
        XCTAssertEqual(draft.label, "Typed message: Ab ")
        XCTAssertEqual(draft.value as? String, "Cursor 2 of 3")
        app.buttons["board-key-Right"].tap()
        XCTAssertEqual(draft.value as? String, "Cursor 3 of 3")
        app.buttons["board-key-Left"].tap()
        let cursorScreenshot = XCTAttachment(screenshot: app.screenshot())
        cursorScreenshot.name = "Cursor inside spelling draft"
        cursorScreenshot.lifetime = .keepAlways
        add(cursorScreenshot)
        app.buttons["grid-keyboard-full"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        let wordKeys = app.switches["alphabet-word-keys-toggle"]
        if wordKeys.value as? String == "1" { wordKeys.tap() }
        let grouped = app.switches["alphabet-grouped-keys"]
        if grouped.value as? String == "1" { grouped.tap() }
        let tenKey = app.switches["alphabet-ten-key-toggle"]
        if tenKey.value as? String == "1" { tenKey.tap() }
        app.buttons["alphabet-key-X"].tap()
        app.navigationBars["Alphabet keyboard"].buttons["Done"].tap()
        XCTAssertEqual(app.textViews["Type a message"].value as? String, "AbX ")
        app.buttons["Pictures"].tap()
        XCTAssertEqual(draft.label, "Typed message: AbX ")
    }

    @MainActor
    func testBedsideCardsSpeakAndCanBePersonalized() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-open-bedside"].tap()
        XCTAssertTrue(app.navigationBars["Bedside communication"].waitForExistence(timeout: 5))
        app.buttons["I need help now."].tap()
        XCTAssertEqual(app.staticTexts["bedside-last-message"].label, "I need help now.")
        XCTAssertTrue(app.buttons["bedside-say-again"].isEnabled)

        app.buttons["bedside-edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit bedside cards"].waitForExistence(timeout: 5))
        app.buttons["bedside-add-card"].tap()
        let unique = String(UUID().uuidString.prefix(6))
        let customMessage = "Please give me a moment \(unique)."
        let label = app.textFields["bedside-card-label"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText("My card \(unique)")
        let message = app.descendants(matching: .any)["bedside-card-message"].firstMatch
        message.tap()
        message.typeText(customMessage)
        app.buttons["bedside-card-save"].tap()
        app.navigationBars["Edit bedside cards"].buttons["Done"].tap()
        app.swipeUp()
        let card = app.buttons[customMessage]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertEqual(app.staticTexts["bedside-last-message"].label, customMessage)
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertEqual(app.staticTexts["bedside-sticky-message"].label, customMessage)
            XCTAssertTrue(app.buttons["bedside-sticky-replay"].isHittable)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Personalized bedside communication"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["bedside-pain-scale"].tap()
        XCTAssertTrue(app.navigationBars["Pain check-in"].waitForExistence(timeout: 5))
        app.navigationBars["Pain check-in"].buttons["Done"].tap()
        app.navigationBars["Bedside communication"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["phrases-open-bedside"].exists)
    }

    @MainActor
    func testUrgentBarSpeaksPersonalBedsideCardAcrossTabs() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-urgent-bar"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-urgent-bar-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        let speak = app.buttons["urgent-bar-speak"]
        XCTAssertTrue(speak.waitForExistence(timeout: 5))
        XCTAssertTrue(speak.label.contains("Please ask my helper."))
        speak.tap()
        for tab in ["Phrases", "Routine", "Stories", "Settings"] {
            app.buttons[tab].firstMatch.tap()
            XCTAssertTrue(speak.exists, "Urgent bar missing on \(tab)")
        }
        app.buttons["urgent-bar-more"].tap()
        XCTAssertTrue(app.navigationBars["Bedside communication"].waitForExistence(timeout: 5))
        app.buttons["Please ask my helper."].tap()
        XCTAssertEqual(app.staticTexts["bedside-last-message"].label, "Please ask my helper.")
        app.navigationBars["Bedside communication"].buttons["Done"].tap()
        XCTAssertTrue(speak.exists)
        app.buttons["Phrases"].firstMatch.tap()
        let recent = app.buttons["Recent messages"]
        for _ in 0..<16 where !recent.isHittable { app.swipeUp() }
        XCTAssertTrue(recent.isHittable)
        recent.tap()
        XCTAssertTrue(app.staticTexts["Please ask my helper."].waitForExistence(timeout: 5))
        XCTAssertTrue(speak.exists, "Urgent bar missing while viewing recent messages")
    }

    @MainActor
    func testUrgentBarRemainsAvailableInBoardOnlyMode() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-urgent-bar-board-only"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-urgent-bar-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        XCTAssertTrue(app.buttons["urgent-bar-speak"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Settings"].exists)
        app.buttons["urgent-bar-more"].tap()
        XCTAssertTrue(app.navigationBars["Bedside communication"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Please ask my helper."].exists)
        XCTAssertFalse(app.buttons["bedside-edit"].exists)
    }

    @MainActor
    func testUrgentBarSettingCanHideAndRestoreTheBar() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-urgent-bar"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-urgent-bar-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["Settings"].firstMatch.tap()
        let setting = app.switches["show-urgent-bar-setting"]
        for _ in 0..<20 where !setting.isHittable { app.swipeUp() }
        XCTAssertTrue(setting.isHittable)
        XCTAssertTrue(app.buttons["urgent-bar-speak"].exists)
        setting.switches.firstMatch.tap()
        XCTAssertEqual(setting.value as? String, "0")
        let bar = app.buttons["urgent-bar-speak"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: bar
        )], timeout: 5), .completed)
        setting.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["urgent-bar-speak"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBedsideStepScanReachesCardsReplayPainAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-bedside-scan"]
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-open-bedside"].tap()

        let target = app.staticTexts["bedside-scan-target"]
        let next = app.buttons["bedside-scan-next"]
        let select = app.buttons["bedside-scan-select"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Help now")
        next.tap()
        XCTAssertEqual(target.label, "Call staff")
        select.tap()
        XCTAssertEqual(app.staticTexts["bedside-last-message"].label,
                       "Please call a member of my care team.")
        XCTAssertEqual(target.label, "Say again")
        XCTAssertTrue(app.buttons["bedside-say-again"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Bedside step scanning"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        next.tap()
        XCTAssertEqual(target.label, "Stop")
        next.tap()
        XCTAssertEqual(target.label, "Pain scale")
        select.tap()
        XCTAssertTrue(app.navigationBars["Pain check-in"].waitForExistence(timeout: 5))
        app.navigationBars["Pain check-in"].buttons["Done"].tap()
        next.tap()
        XCTAssertEqual(target.label, "Edit")
        next.tap()
        XCTAssertEqual(target.label, "Done")
        select.tap()
        XCTAssertTrue(app.buttons["phrases-open-bedside"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBedsideAutoScanCanPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-bedside-scan-auto"]
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-open-bedside"].tap()

        let target = app.staticTexts["bedside-scan-target"]
        let pause = app.buttons["bedside-scan-pause"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        pause.tap()
        let held = target.label
        Thread.sleep(forTimeInterval: 3.5)
        XCTAssertEqual(target.label, held)
        pause.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", held), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 6), .completed)
    }

    @MainActor
    func testReadAloudLibraryReopensSavedTextAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-open-read-aloud"].tap()
        let editor = app.textViews["read-aloud-text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Please read this page again tomorrow.")
        app.buttons["read-aloud-save"].tap()
        let saveAlert = app.alerts["Save reading"]
        XCTAssertTrue(saveAlert.waitForExistence(timeout: 5))
        saveAlert.buttons["Save"].tap()
        app.navigationBars["Read aloud"].buttons["Done"].tap()
        app.terminate()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-open-read-aloud"].tap()
        app.buttons["read-aloud-library"].tap()
        XCTAssertTrue(app.navigationBars["Saved readings"].waitForExistence(timeout: 5))
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-reading-")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertEqual(app.textViews["read-aloud-text"].value as? String,
                       "Please read this page again tomorrow.")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Reopened saved reading"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["read-aloud-library"].tap()
        let savedRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-reading-"))
        let originalCount = savedRows.count
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "delete-saved-reading-")).firstMatch.tap()
        let deleteAlert = app.alerts["Delete saved reading?"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5))
        deleteAlert.buttons["Delete"].tap()
        XCTAssertEqual(savedRows.count, originalCount - 1)
    }

    @MainActor
    func testFullScreenTypingEditsTheSameDraftAndShowsPartnerMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        app.buttons["More"].tap()
        app.buttons["open-expanded-typing"].tap()
        XCTAssertTrue(app.navigationBars["Full-screen typing"].waitForExistence(timeout: 5))
        let editor = app.textViews["expanded-typed-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Please give me time to explain what I need.")
        let entered = editor.value as? String
        XCTAssertTrue((entered ?? "").contains("what I need"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Full-screen typing"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["expanded-show-message"].tap()
        XCTAssertTrue(app.navigationBars["Your message"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["large-message"].firstMatch.label.contains("what I need"))
        app.navigationBars["Your message"].buttons["Done"].tap()
        app.navigationBars["Full-screen typing"].buttons["Done"].tap()
        let parentEditor = app.textViews["Type a message"]
        XCTAssertTrue(parentEditor.waitForExistence(timeout: 5))
        XCTAssertEqual(parentEditor.value as? String, entered)
    }

    @MainActor
    func testReadAloudTextCanPauseResumeAndKeepThePage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-open-read-aloud"].tap()
        XCTAssertTrue(app.navigationBars["Read aloud"].waitForExistence(timeout: 5))
        let editor = app.textViews["read-aloud-text"]
        let page = String(repeating: "Please give me a moment to understand this page. ", count: 10)
        editor.tap()
        editor.typeText(page)
        let entered = editor.value as? String
        XCTAssertFalse(entered?.isEmpty ?? true)
        app.buttons["read-aloud-speak"].tap()
        let pause = app.buttons["pause-message-speech"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        XCTAssertTrue(pause.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["read-aloud-follow-along"].firstMatch.exists)
        pause.tap()
        let resume = app.buttons["resume-message-speech"].firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Read aloud paused"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        resume.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        app.buttons["stop-message-speech"].firstMatch.tap()
        XCTAssertFalse(resume.exists)
        XCTAssertEqual(editor.value as? String, entered)
        app.navigationBars["Read aloud"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Quick phrases"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTypedMessageCanPauseResumeAndStopInLargeDisplay() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        let message = String(repeating: "Please give me time to finish this thought. ", count: 12)
        editor.tap()
        editor.typeText(message)
        let typedBeforeSpeech = editor.value as? String
        XCTAssertFalse(typedBeforeSpeech?.isEmpty ?? true)
        app.buttons["Speak text"].firstMatch.tap()
        let pause = app.buttons["pause-message-speech"].firstMatch
        let resume = app.buttons["resume-message-speech"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        XCTAssertTrue(pause.isHittable)
        pause.tap()
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, typedBeforeSpeech)

        app.buttons["More"].tap()
        app.buttons["Show large message"].tap()
        XCTAssertTrue(app.navigationBars["Your message"].waitForExistence(timeout: 5))
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Paused message in large display"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        resume.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        app.buttons["stop-message-speech"].firstMatch.tap()
        XCTAssertFalse(resume.exists)
        XCTAssertTrue(app.buttons["Speak message"].exists)
        app.navigationBars["Your message"].buttons["Done"].tap()
        XCTAssertEqual(editor.value as? String, typedBeforeSpeech)
    }

    @MainActor
    func testNoteFromPhrasesOpensTypedDraft() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-open-notes"].tap()
        XCTAssertTrue(app.navigationBars["Notes"].waitForExistence(timeout: 5))
        app.buttons["new-note"].tap()
        let title = "Trip \(UUID().uuidString.prefix(6))"
        let titleField = app.textFields["note-title"]
        titleField.tap()
        titleField.typeText(title)
        let body = app.textViews["note-text"]
        body.tap()
        body.typeText("Call me when you arrive.")
        app.buttons["save-note"].tap()
        let search = app.searchFields["Search notes"]
        search.tap()
        search.typeText(title)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        let use = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "use-note-")).firstMatch
        use.tap()
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue((editor.value as? String ?? "").contains("Call me when you arrive."))
    }

    @MainActor
    func testNotesCanBeSpokenAndUsedWithoutChangingPictureDraft() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clearPicture = app.buttons["Clear message"]
        if clearPicture.isEnabled { clearPicture.tap() }
        app.buttons["Core"].firstMatch.tap()
        app.buttons["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))

        app.buttons["open-notes"].tap()
        XCTAssertTrue(app.navigationBars["Notes"].waitForExistence(timeout: 5))
        app.buttons["new-note"].tap()
        XCTAssertTrue(app.navigationBars["New note"].waitForExistence(timeout: 5))
        let noteTitle = "At the doctor \(UUID().uuidString.prefix(6))"
        let title = app.textFields["note-title"]
        title.tap()
        title.typeText(noteTitle)
        let topic = app.textFields["note-topic"]
        topic.tap()
        topic.typeText("Health")
        let body = app.textViews["note-text"]
        body.tap()
        body.typeText("Please explain that again.")
        app.buttons["save-note"].tap()
        XCTAssertTrue(app.staticTexts[noteTitle].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Health"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Communication notes"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let speak = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "speak-note-")).firstMatch
        speak.tap()
        let use = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "use-note-")).firstMatch
        use.tap()
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue((editor.value as? String ?? "").contains("Please explain that again."))
        app.buttons["Pictures"].tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["open-notes"].tap()
        XCTAssertTrue(app.staticTexts[noteTitle].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCommunicationRepairSpeaksWithoutChangingPictureOrTypedDrafts() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clearPicture = app.buttons["Clear message"]
        if clearPicture.isEnabled { clearPicture.tap() }
        app.buttons["Core"].firstMatch.tap()
        app.buttons["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))

        app.buttons["picture-message-more"].tap()
        app.buttons["message-communication-repair"].tap()
        XCTAssertTrue(app.navigationBars["Communication repair"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["communication-repair-phrase-3"].exists)
        let pictureScreenshot = XCTAttachment(screenshot: app.screenshot())
        pictureScreenshot.name = "Communication repair phrases on iPhone or iPad"
        pictureScreenshot.lifetime = .keepAlways
        add(pictureScreenshot)
        app.buttons["communication-repair-phrase-3"].tap()
        app.navigationBars["Communication repair"].buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))
        let directPictureRepair = app.buttons["picture-communication-repair"]
        if directPictureRepair.exists {
            directPictureRepair.tap()
            XCTAssertTrue(app.navigationBars["Communication repair"].waitForExistence(timeout: 5))
            app.navigationBars["Communication repair"].buttons["Done"].tap()
            XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))
        }

        app.buttons["board-language"].tap()
        app.buttons["Español"].tap()
        app.buttons["Keyboard"].tap()
        let clearTyped = app.buttons["Clear"]
        if clearTyped.isEnabled { clearTyped.tap() }
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Hola")
        let repair = app.buttons["open-communication-repair"]
        XCTAssertTrue(repair.isHittable)
        repair.tap()
        XCTAssertTrue(app.navigationBars["Communication repair"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Speak Eso no es lo que quise decir"].exists)
        app.buttons["communication-repair-phrase-1"].tap()
        app.navigationBars["Communication repair"].buttons["Done"].tap()
        XCTAssertEqual(editor.value as? String, "Hola")

        app.buttons["open-alphabet-keyboard"].tap()
        XCTAssertTrue(app.navigationBars["Alphabet keyboard"].waitForExistence(timeout: 5))
        app.buttons["alphabet-open-communication-repair"].tap()
        XCTAssertTrue(app.navigationBars["Communication repair"].waitForExistence(timeout: 5))
        app.buttons["communication-repair-phrase-3"].tap()
        app.navigationBars["Communication repair"].buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hola")
    }

    @MainActor
    func testSpanishTypedWordFormsChangeMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["Español"].tap()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("comer")
        let forms = app.buttons["typed-word-forms"]
        XCTAssertTrue(forms.waitForExistence(timeout: 5))
        forms.tap()
        XCTAssertTrue(app.navigationBars["Typed word forms"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Preview comí"].exists)
        XCTAssertTrue(app.staticTexts["I did it (yo)"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Spanish typed word forms"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["typed-word-form-past"].tap()
        XCTAssertEqual(editor.value as? String, "comí")
    }

    @MainActor
    func testSpanishPictureWordFormChangesMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["Español"].tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Food"].firstMatch.tap()
        let eatWord = app.buttons["comer"].firstMatch
        XCTAssertTrue(eatWord.waitForExistence(timeout: 5))
        eatWord.tap()
        let forms = app.buttons["word-forms"]
        XCTAssertTrue(forms.waitForExistence(timeout: 5))
        forms.tap()
        XCTAssertTrue(app.buttons["Preview comí"].waitForExistence(timeout: 5))
        app.buttons["word-form-past"].tap()
        XCTAssertTrue(app.staticTexts["Message: comí"].waitForExistence(timeout: 5))

    }

    @MainActor
    func testPictureBoardTilesOpenSceneAndKeyboardWithoutChangingMessage() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-board-scene-keyboard")
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let label = "Scene shortcut \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(label + "\n")
        app.staticTexts["When tapped"].tap()
        app.buttons["Open a scene"].firstMatch.tap()
        let scenePicker = app.buttons["button-destination-scene"]
        XCTAssertTrue(scenePicker.waitForExistence(timeout: 5))
        scenePicker.tap()
        app.buttons["Tile-linked scene"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Add button"].buttons["Save"].isEnabled)
        app.navigationBars["Add button"].buttons["Save"].tap()

        let search = app.searchFields["Find a word"]
        search.tap()
        search.typeText(label)
        let sceneTile = app.buttons[label]
        XCTAssertTrue(sceneTile.waitForExistence(timeout: 5))
        sceneTile.tap()
        if app.buttons["Open scene"].exists { app.buttons["Open scene"].tap() }
        XCTAssertTrue(app.navigationBars["Tile-linked scene"].waitForExistence(timeout: 5))
        app.navigationBars["Tile-linked scene"].buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Message: empty"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        let keyboardSearch = app.searchFields["Find a word"]
        keyboardSearch.tap()
        keyboardSearch.typeText("Open tile keyboard")
        let keyboardTile = app.buttons["Open tile keyboard"]
        XCTAssertTrue(keyboardTile.waitForExistence(timeout: 5))
        keyboardTile.tap()
        if app.buttons["Open keyboard"].exists { app.buttons["Open keyboard"].tap() }
        XCTAssertTrue(app.buttons["Pictures"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Keyboard opened from picture tile"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Pictures"].tap()
        XCTAssertTrue(app.staticTexts["Message: empty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWebButtonOpensInAppAndKeepsPictureMessage() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let label = "Example site \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(label + "\n")
        app.staticTexts["When tapped"].tap()
        app.buttons["Open a web page"].firstMatch.tap()
        let url = app.textFields["button-web-url"]
        XCTAssertTrue(url.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Add button"].buttons["Save"].isEnabled)
        url.tap()
        url.typeText("example.com\n")
        app.navigationBars["Add button"].buttons["Save"].tap()

        let search = app.searchFields["Find a word"]
        search.tap()
        search.typeText(label)
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        if app.buttons["Open page"].exists { app.buttons["Open page"].tap() }
        XCTAssertTrue(app.navigationBars[label].waitForExistence(timeout: 10))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.staticTexts.firstMatch.waitForExistence(timeout: 20))
        let opened = XCTAttachment(screenshot: app.screenshot())
        opened.name = "Website opened from AAC button"
        opened.lifetime = .keepAlways
        add(opened)
        app.buttons["web-button-done"].tap()
        XCTAssertTrue(app.staticTexts["Message: empty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSpeechVolumeMuteRelaunchAndTypingAccess() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["open-speech-volume"].tap()
        XCTAssertTrue(app.navigationBars["Speech sound"].waitForExistence(timeout: 5))
        let mute = app.buttons["speech-mute-button"]
        if mute.value as? String == "Muted" { mute.tap() }
        let slider = app.sliders["speech-volume-slider"]
        XCTAssertTrue(slider.exists)
        slider.adjust(toNormalizedSliderPosition: 0.35)
        let selectedLevel = app.staticTexts["speech-volume-value"].label
        XCTAssertNotEqual(selectedLevel, "App speech volume: 100%")
        mute.tap()
        XCTAssertEqual(mute.value as? String, "Muted")
        XCTAssertFalse(app.buttons["speech-volume-try"].isEnabled)
        let screen = XCTAttachment(screenshot: app.screenshot())
        screen.name = "Speech sound muted"
        screen.lifetime = .keepAlways
        add(screen)
        app.buttons["speech-volume-done"].tap()
        XCTAssertEqual(app.buttons["open-speech-volume"].value as? String, "Muted")

        app.terminate()
        app.launch()
        XCTAssertEqual(app.buttons["open-speech-volume"].value as? String, "Muted")
        app.buttons["Keyboard"].tap()
        app.buttons["open-speech-volume"].tap()
        XCTAssertEqual(app.buttons["speech-mute-button"].value as? String, "Muted")
        XCTAssertEqual(app.staticTexts["speech-volume-value"].label, selectedLevel)
        app.buttons["speech-mute-button"].tap()
        XCTAssertTrue(app.buttons["speech-volume-try"].isEnabled)
        app.buttons["speech-volume-done"].tap()
    }

    @MainActor
    func testSelectedHomeBoardOpensAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        let needs = app.buttons["Needs"].firstMatch
        let tabs = app.scrollViews["board-tabs"]
        for _ in 0..<5 {
            if needs.frame.midX > tabs.frame.maxX - 20 { tabs.swipeLeft() }
            else if needs.frame.midX < tabs.frame.minX + 20 { tabs.swipeRight() }
            else { break }
        }
        needs.tap()
        XCTAssertTrue(app.buttons["bathroom"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Customize"].tap()
        app.buttons["customize-set-home-board"].tap()
        let selected = XCTAttachment(screenshot: app.screenshot())
        selected.name = "Selected Needs home board"
        selected.lifetime = .keepAlways
        add(selected)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["bathroom"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Needs"].firstMatch.isSelected)
    }

    @MainActor
    func testTwoBoardsKeepCoreAvailableBesideTopic() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["customize-two-boards"].tap()

        let needs = app.buttons["Needs"].firstMatch
        let tabs = app.scrollViews["board-tabs"]
        for _ in 0..<5 {
            if needs.frame.midX > tabs.frame.maxX - 20 { tabs.swipeLeft() }
            else if needs.frame.midX < tabs.frame.minX + 20 { tabs.swipeRight() }
            else { break }
        }
        needs.tap()
        XCTAssertTrue(app.staticTexts["persistent-core-header"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["persistent-core-I"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["bathroom"].firstMatch.exists)

        let draft = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Message:")).firstMatch
        let priorDraft = draft.label
        app.buttons["persistent-core-I"].tap()
        XCTAssertNotEqual(draft.label, priorDraft)
        let updatedDraft = draft.label
        let screen = XCTAttachment(screenshot: app.screenshot())
        screen.name = "Core and Needs boards together"
        screen.lifetime = .keepAlways
        add(screen)

        app.buttons["Customize"].tap()
        app.buttons["customize-two-boards"].tap()
        XCTAssertFalse(app.staticTexts["persistent-core-header"].exists)
        XCTAssertEqual(draft.label, updatedDraft)
    }

    @MainActor
    func testLanyardCardsSwipeSpeakAndPreserveDraft() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Yes"].firstMatch.tap()
        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Message:")).firstMatch
        let draft = message.label
        XCTAssertNotEqual(draft, "Message: empty")

        app.buttons["open-lanyard-cards"].tap()
        XCTAssertTrue(app.navigationBars["Lanyard cards"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["lanyard-card-count"].label.hasPrefix("Card 1 of"))
        app.buttons["lanyard-speak"].tap()
        app.buttons["lanyard-next"].tap()
        XCTAssertTrue(app.staticTexts["lanyard-card-count"].label.hasPrefix("Card 2 of"))
        app.descendants(matching: .any)["lanyard-cards"].swipeLeft()
        XCTAssertTrue(app.staticTexts["lanyard-card-count"].label.hasPrefix("Card 3 of"))
        let screen = XCTAttachment(screenshot: app.screenshot())
        screen.name = "Lanyard cards"
        screen.lifetime = .keepAlways
        add(screen)
        app.buttons["lanyard-board-menu"].tap()
        app.buttons["Needs"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["lanyard-card-count"].label.hasPrefix("Card 1 of"))
        app.buttons["lanyard-done"].tap()
        XCTAssertEqual(message.label, draft)
    }

    @MainActor
    func testAmbientSoundsPlaySwitchStopAndLeaveForSpeak() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-calm-space"].tap()
        app.buttons["calm-open-ambient-sounds"].tap()
        XCTAssertTrue(app.navigationBars["Ambient sounds"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No sound playing"].exists)
        app.buttons["soundscape-rain"].tap()
        XCTAssertTrue(app.staticTexts["Playing Soft rain"].waitForExistence(timeout: 5))
        app.buttons["soundscape-waves"].tap()
        XCTAssertTrue(app.staticTexts["Playing Slow waves"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["soundscape-volume"].exists)
        let sounds = XCTAttachment(screenshot: app.screenshot())
        sounds.name = "Ambient sounds playing"
        sounds.lifetime = .keepAlways
        add(sounds)
        app.buttons["soundscape-stop"].tap()
        XCTAssertTrue(app.staticTexts["No sound playing"].waitForExistence(timeout: 5))
        app.buttons["soundscape-breeze"].tap()
        XCTAssertTrue(app.staticTexts["Playing Breeze"].waitForExistence(timeout: 5))
        app.buttons["Speak"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Yes"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Routine"].firstMatch.tap()
        if !app.navigationBars["Ambient sounds"].exists {
            app.buttons["open-calm-space"].tap()
            app.buttons["calm-open-ambient-sounds"].tap()
        }
        XCTAssertTrue(app.staticTexts["No sound playing"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSensoryCanvasSupportsTouchStillCirclesAndSpeakReturn() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-calm-space"].tap()
        app.buttons["calm-open-sensory-canvas"].tap()
        XCTAssertTrue(app.navigationBars["Sensory canvas"].waitForExistence(timeout: 5))
        let motion = app.switches["sensory-motion"]
        if motion.value as? String == "0" { motion.tap() }
        let clear = app.buttons["sensory-clear"]
        XCTAssertFalse(clear.isEnabled)
        let canvas = app.descendants(matching: .any)["sensory-canvas"]
        XCTAssertTrue(canvas.isHittable)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.4)).tap()
        XCTAssertTrue(clear.isEnabled)
        motion.tap()
        XCTAssertEqual(motion.value as? String, "0")
        XCTAssertFalse(clear.isEnabled)
        app.buttons["sensory-add-ripple"].tap()
        XCTAssertTrue(clear.isEnabled)
        let stillCircle = XCTAttachment(screenshot: app.screenshot())
        stillCircle.name = "Sensory canvas still circles"
        stillCircle.lifetime = .keepAlways
        add(stillCircle)
        clear.tap()
        XCTAssertFalse(clear.isEnabled)
        app.navigationBars["Sensory canvas"].buttons["Calm space"].tap()
        app.buttons["calm-open-sensory-canvas"].tap()
        XCTAssertEqual(app.switches["sensory-motion"].value as? String, "0")
        app.navigationBars["Sensory canvas"].buttons["Calm space"].tap()
        app.buttons["calm-open-speak"].tap()
        XCTAssertTrue(app.buttons["Yes"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testCalmSpaceStepScanReachesNeedsAndFocusTools() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-calm-scan"]
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-calm-space"].tap()

        let target = app.staticTexts["calm-scan-target"]
        let next = app.buttons["calm-scan-next"]
        let select = app.buttons["calm-scan-select"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Open communication board")
        next.tap()
        XCTAssertEqual(target.label, "I need quiet.")
        select.tap()
        XCTAssertEqual(app.staticTexts["calm-selected-message"].label, "I need quiet.")
        XCTAssertEqual(target.label, "Speak this request")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Calm space step scanning"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        select.tap()
        next.tap()
        XCTAssertEqual(target.label, "I need quiet.")
        for _ in 0..<7 { next.tap() }
        XCTAssertEqual(target.label, "Sensory canvas")
        next.tap()
        XCTAssertEqual(target.label, "Ambient sounds")
        next.tap()
        XCTAssertEqual(target.label, "Paced breathing")
        select.tap()
        XCTAssertTrue(app.navigationBars["Paced breathing"].waitForExistence(timeout: 5))
        app.navigationBars["Paced breathing"].buttons["Calm space"].tap()
        next.tap()
        XCTAssertEqual(target.label, "Five senses grounding")
        next.tap()
        XCTAssertEqual(target.label, "Low-light screen")
        select.tap()
        XCTAssertTrue(app.buttons["low-light-close"].waitForExistence(timeout: 5))
        app.buttons["low-light-close"].tap()
        next.tap()
        XCTAssertEqual(target.label, "Back to routine")
        select.tap()
        XCTAssertTrue(app.buttons["open-calm-space"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCalmSpaceAutoScanCanPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-calm-scan-auto"]
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-calm-space"].tap()

        let target = app.staticTexts["calm-scan-target"]
        let pause = app.buttons["calm-scan-pause"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        pause.tap()
        let held = target.label
        Thread.sleep(forTimeInterval: 3.5)
        XCTAssertEqual(target.label, held)
        pause.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", held), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 6), .completed)
    }

    @MainActor
    func testCalmSpaceNeedsBreathingGroundingAndLowLight() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-calm-space"].tap()
        XCTAssertTrue(app.navigationBars["Calm space"].waitForExistence(timeout: 5))
        app.buttons["calm-need-quiet"].tap()
        XCTAssertEqual(app.staticTexts["calm-selected-message"].label, "I need quiet.")
        XCTAssertTrue(app.staticTexts["calm-selected-message"].isHittable)
        XCTAssertTrue(app.buttons["calm-speak-request"].exists)
        let calmScreen = XCTAttachment(screenshot: app.screenshot())
        calmScreen.name = "Calm space need card"
        calmScreen.lifetime = .keepAlways
        add(calmScreen)

        app.buttons["calm-open-breathing"].tap()
        XCTAssertTrue(app.navigationBars["Paced breathing"].waitForExistence(timeout: 5))
        app.buttons["breathing-start-pause"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
        let breatheOut = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Breathe out,"))
            .firstMatch
        XCTAssertTrue(breatheOut.waitForExistence(timeout: 7))
        app.buttons["breathing-reset"].tap()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
        app.navigationBars["Paced breathing"].buttons["Calm space"].tap()

        app.buttons["calm-open-grounding"].tap()
        XCTAssertTrue(app.navigationBars["Five senses grounding"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Step 1 of 5"].exists)
        app.buttons["grounding-next"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 of 5"].waitForExistence(timeout: 5))
        app.navigationBars["Five senses grounding"].buttons["Calm space"].tap()

        app.buttons["calm-open-low-light"].tap()
        XCTAssertTrue(app.buttons["low-light-close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["I need quiet."].exists)
        let lowLightScreen = XCTAttachment(screenshot: app.screenshot())
        lowLightScreen.name = "Low light with request"
        lowLightScreen.lifetime = .keepAlways
        add(lowLightScreen)
        app.buttons["low-light-close"].tap()
        app.buttons["calm-open-speak"].tap()
        XCTAssertTrue(app.buttons["Yes"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testRewardChartCanBeFilledCollectedAndKeepsCommunicationAvailable() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-reward-chart")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-reward-charts"].tap()
        XCTAssertTrue(app.navigationBars["Reward charts"].waitForExistence(timeout: 5))
        app.buttons["reward-add-chart"].tap()
        let name = app.textFields["reward-chart-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Try a new game")
        let reward = app.textFields["reward-chart-reward"]
        reward.tap()
        reward.typeText("Choose music")
        XCTAssertTrue(app.buttons["Choose photo from Photos"].exists)
        app.buttons["reward-chart-save"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reward-chart-"))
            .firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Reward chart"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 of 5 tokens"].waitForExistence(timeout: 5))
        for _ in 0..<5 { app.buttons["reward-add-token"].tap() }
        XCTAssertTrue(app.staticTexts["Goal reached!"].waitForExistence(timeout: 5))
        let filled = XCTAttachment(screenshot: app.screenshot())
        filled.name = "Completed reward chart"
        filled.lifetime = .keepAlways
        add(filled)
        app.buttons["reward-collect"].tap()
        app.alerts["Reward collected"].buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts["0 of 5 tokens"].waitForExistence(timeout: 5))
        app.navigationBars["Reward chart"].buttons["Reward charts"].tap()
        XCTAssertTrue(app.staticTexts["Collected rewards"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Choose music"].waitForExistence(timeout: 5))
        app.buttons["Speak"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Yes"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavedRoutineAwardsOneTokenPerBoardRun() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-reward")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-routine-templates"].tap()
        app.staticTexts["Reward routine test"].tap()
        let picker = app.buttons["routine-template-reward-chart"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["Routine stars"].tap()
        app.buttons["routine-template-board"].tap()
        let progress = app.staticTexts["first-then-reward-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("Routine stars: 0 of 2 tokens"))
        app.buttons["first-then-done"].tap()
        XCTAssertTrue(progress.label.contains("Routine stars: 1 of 2 tokens"))
        XCTAssertTrue(app.staticTexts["first-then-reward-notice"].exists)

        let mode = app.descendants(matching: .any)["routine-board-mode"].firstMatch
        mode.tap()
        app.buttons["Checklist"].tap()
        app.buttons["routine-board-undo-step"].tap()
        app.buttons["routine-board-complete-step"].tap()
        XCTAssertTrue(progress.label.contains("Routine stars: 1 of 2 tokens"))
        let awarded = XCTAttachment(screenshot: app.screenshot())
        awarded.name = "Saved routine awarded one token"
        awarded.lifetime = .keepAlways
        add(awarded)

        app.buttons["first-then-reset"].tap()
        app.buttons["routine-board-complete-step"].tap()
        XCTAssertTrue(progress.label.contains("Routine stars: 2 of 2 tokens"))
        XCTAssertTrue(app.staticTexts["first-then-reward-notice"].label.contains("ready to collect"))
    }

    @MainActor
    func testVisualCalendarEventCanBeAddedCountedAndSpoken() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        XCTAssertTrue(app.navigationBars["Visual calendar"].waitForExistence(timeout: 5))
        app.buttons["calendar-add-event"].tap()
        let countdown = app.buttons["calendar-countdown"]
        XCTAssertTrue(countdown.isHittable)
        countdown.tap()
        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "Calendar countdown editor state"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)
        XCTAssertEqual(countdown.value as? String, "On")
        let title = app.textFields["calendar-event-title"]
        title.tap()
        title.typeText("Family visit")
        app.buttons["calendar-done-editing"].tap()
        app.buttons["calendar-save-event"].tap()
        XCTAssertTrue(app.staticTexts["Count days until"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Family visit"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Say Family visit"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Visual calendar with an event and day countdown"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Say Family visit"].firstMatch.tap()
    }

    @MainActor
    func testVisualCalendarAppearanceAndEventColor() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        app.buttons["calendar-settings-menu"].tap()
        app.buttons["calendar-appearance-open"].tap()
        XCTAssertTrue(app.navigationBars["Calendar appearance"].waitForExistence(timeout: 5))
        let planned = app.textFields["calendar-planned-label"]
        planned.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        planned.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + "Up next")
        app.buttons["calendar-appearance-done-editing"].tap()
        app.swipeUp()
        let recordPlanned = app.buttons["calendar-record-planned-label"]
        XCTAssertTrue(recordPlanned.waitForExistence(timeout: 5))
        XCTAssertTrue(recordPlanned.isEnabled)
        let showPlanned = app.switches["calendar-show-planned-label"]
        XCTAssertTrue(showPlanned.exists)
        if showPlanned.value as? String == "0" {
            showPlanned.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let voiceEditor = XCTAttachment(screenshot: app.screenshot())
        voiceEditor.name = "Calendar recorded label controls"
        voiceEditor.lifetime = .keepAlways
        add(voiceEditor)
        app.buttons["calendar-appearance-save"].tap()
        app.buttons["calendar-settings-menu"].tap()
        app.buttons["calendar-appearance-open"].tap()
        XCTAssertEqual(app.textFields["calendar-planned-label"].value as? String, "Up next")
        app.buttons["Cancel"].tap()

        app.buttons["calendar-add-event"].tap()
        let name = "Colorful visit \(UUID().uuidString.prefix(6))"
        let title = app.textFields["calendar-event-title"]
        title.tap()
        title.typeText(name)
        app.buttons["calendar-done-editing"].tap()
        app.swipeUp()
        let colorToggle = app.switches["calendar-custom-color"]
        XCTAssertTrue(colorToggle.waitForExistence(timeout: 5))
        if colorToggle.value as? String == "0" {
            colorToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let editorAttachment = XCTAttachment(screenshot: app.screenshot())
        editorAttachment.name = "Event color editor after enabling custom color"
        editorAttachment.lifetime = .keepAlways
        add(editorAttachment)
        XCTAssertEqual(colorToggle.value as? String, "1")
        app.buttons["calendar-save-event"].tap()
        XCTAssertTrue(app.buttons["Say \(name)"].waitForExistence(timeout: 5))
        app.segmentedControls["calendar-display-mode"].buttons["Day"].tap()
        XCTAssertTrue(app.buttons["Up next"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Colored event with custom calendar section"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["calendar-settings-menu"].tap()
        app.buttons["calendar-appearance-open"].tap()
        let hidePlanned = app.switches["calendar-show-planned-label"]
        hidePlanned.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["calendar-appearance-save"].tap()
        XCTAssertFalse(app.buttons["Up next"].exists)
        XCTAssertTrue(app.buttons["Say \(name)"].exists)
        app.buttons["calendar-settings-menu"].tap()
        app.buttons["calendar-appearance-open"].tap()
        app.switches["calendar-show-planned-label"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["calendar-appearance-save"].tap()
        XCTAssertTrue(app.buttons["Up next"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCalendarEditPINKeepsCommunicationAvailable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        XCTAssertTrue(app.buttons["calendar-add-event"].waitForExistence(timeout: 5))
        if !app.buttons["calendar-add-event"].isEnabled {
            app.buttons["calendar-settings-menu"].tap()
            app.buttons["calendar-edit-protection-open"].tap()
            let oldPIN = app.secureTextFields["calendar-lock-pin"]
            oldPIN.tap()
            oldPIN.typeText("4826")
            app.buttons["calendar-lock-done-editing"].tap()
            app.buttons["calendar-lock-unlock"].tap()
            app.buttons["calendar-settings-menu"].tap()
            app.buttons["calendar-edit-protection-open"].tap()
            app.buttons["calendar-lock-disable"].tap()
        }

        let name = "Protected visit \(UUID().uuidString.prefix(6))"
        app.buttons["calendar-add-event"].tap()
        let title = app.textFields["calendar-event-title"]
        title.tap()
        title.typeText(name)
        app.buttons["calendar-done-editing"].tap()
        app.buttons["calendar-save-event"].tap()
        XCTAssertTrue(app.buttons["Say \(name)"].waitForExistence(timeout: 5))

        app.buttons["calendar-settings-menu"].tap()
        app.buttons["calendar-edit-protection-open"].tap()
        let newPIN = app.secureTextFields["calendar-lock-new-pin"]
        newPIN.tap()
        newPIN.typeText("4826")
        let confirmPIN = app.secureTextFields["calendar-lock-confirm-pin"]
        confirmPIN.tap()
        confirmPIN.typeText("4826")
        app.buttons["calendar-lock-done-editing"].tap()
        app.buttons["calendar-lock-enable"].tap()
        XCTAssertFalse(app.buttons["calendar-add-event"].isEnabled)
        app.buttons["Say \(name)"].tap()
        app.buttons["Mark done for \(name)"].tap()
        XCTAssertTrue(app.buttons["Mark not done for \(name)"].exists)

        app.terminate()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        XCTAssertTrue(app.buttons["calendar-add-event"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["calendar-add-event"].isEnabled)
        app.buttons["calendar-settings-menu"].tap()
        app.buttons["calendar-edit-protection-open"].tap()
        let unlockPIN = app.secureTextFields["calendar-lock-pin"]
        unlockPIN.tap()
        unlockPIN.typeText("4826")
        app.buttons["calendar-lock-done-editing"].tap()
        app.buttons["calendar-lock-unlock"].tap()
        XCTAssertTrue(app.buttons["calendar-add-event"].isEnabled)
        app.buttons["calendar-settings-menu"].tap()
        app.buttons["calendar-edit-protection-open"].tap()
        app.buttons["calendar-lock-disable"].tap()
        XCTAssertTrue(app.buttons["calendar-add-event"].isEnabled)
    }

    @MainActor
    func testCalendarPINProtectsWeeklyPlanEditsAndKeepsCompletion() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-weekly-plan-edit-lock")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-weekly-plan"].tap()
        XCTAssertTrue(app.navigationBars["Weekly plan"].waitForExistence(timeout: 5))
        let add = app.buttons["add-weekly-activity"]
        for _ in 0..<4 {
            if add.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(add.isEnabled)
        let name = "Locked weekly activity"
        let say = app.buttons["Say \(name)"]
        XCTAssertTrue(say.waitForExistence(timeout: 5))
        say.tap()
        let markDone = app.buttons["Mark done: \(name)"]
        let markNotDone = app.buttons["Mark not done: \(name)"]
        if markNotDone.exists { markNotDone.tap() }
        markDone.tap()
        XCTAssertTrue(markNotDone.waitForExistence(timeout: 5))

        app.buttons["weekly-plan-protection-open"].tap()
        let pin = app.secureTextFields["calendar-lock-pin"]
        pin.tap()
        pin.typeText("4826")
        app.buttons["calendar-lock-done-editing"].tap()
        app.buttons["calendar-lock-unlock"].tap()
        XCTAssertTrue(add.isEnabled)
        app.buttons["weekly-plan-protection-open"].tap()
        app.buttons["calendar-lock-disable"].tap()
        XCTAssertTrue(add.isEnabled)
    }

    @MainActor
    func testVisualCalendarPrintsMonthWeekAndDay() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        let printMenu = app.buttons["calendar-print-menu"]
        XCTAssertTrue(printMenu.waitForExistence(timeout: 5))
        for range in ["This month", "This week", "This day"] {
            printMenu.tap()
            app.buttons[range].tap()
            XCTAssertTrue(app.navigationBars["Calendar PDF"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["share-pdf"].exists)
            XCTAssertTrue(app.buttons["Save PDF"].exists)
            XCTAssertTrue(app.buttons["Print"].exists)
            if range == "This month" {
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "Calendar month PDF preview"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            app.buttons["Done"].tap()
            XCTAssertTrue(app.navigationBars["Visual calendar"].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testVisualCalendarWeekAndDayKeepSpeechAndCompletion() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        app.buttons["calendar-add-event"].tap()
        let name = "Week view \(UUID().uuidString.prefix(6))"
        let field = app.textFields["calendar-event-title"]
        field.tap()
        field.typeText(name)
        app.buttons["calendar-done-editing"].tap()
        app.buttons["calendar-save-event"].tap()
        XCTAssertTrue(app.buttons["Say \(name)"].waitForExistence(timeout: 5))

        let mode = app.segmentedControls["calendar-display-mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.buttons["Week"].tap()
        XCTAssertTrue(app.staticTexts["calendar-week-title"].exists)
        XCTAssertTrue(app.buttons["Say \(name)"].exists)
        app.buttons["Mark done for \(name)"].tap()
        XCTAssertTrue(app.buttons["Mark not done for \(name)"].exists)

        mode.buttons["Day"].tap()
        XCTAssertTrue(app.staticTexts["calendar-day-title"].exists)
        XCTAssertTrue(app.buttons["Mark not done for \(name)"].exists)
        app.buttons["Say \(name)"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Visual calendar day view"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["Next day"].tap()
        XCTAssertFalse(app.buttons["Say \(name)"].exists)
        app.buttons["Previous day"].tap()
        XCTAssertTrue(app.buttons["Say \(name)"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWeeklyActivityCompletionStaysWithEachCalendarWeek() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-calendar-weekly-completion")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        let mode = app.segmentedControls["calendar-display-mode"]
        mode.buttons["Day"].tap()
        let title = "Calendar weekly completion"
        XCTAssertTrue(app.buttons["Say \(title)"].waitForExistence(timeout: 5))
        let markDone = app.buttons["Mark done for \(title)"]
        let markNotDone = app.buttons["Mark not done for \(title)"]
        if markNotDone.exists { markNotDone.tap() }
        XCTAssertTrue(markDone.waitForExistence(timeout: 5))
        markDone.tap()
        XCTAssertTrue(markNotDone.waitForExistence(timeout: 5))

        mode.buttons["Week"].tap()
        app.buttons["Next week"].tap()
        mode.buttons["Day"].tap()
        if markNotDone.exists { markNotDone.tap() }
        XCTAssertTrue(markDone.waitForExistence(timeout: 5))
        markDone.tap()
        XCTAssertTrue(markNotDone.waitForExistence(timeout: 5))

        mode.buttons["Week"].tap()
        app.buttons["Previous week"].tap()
        mode.buttons["Day"].tap()
        XCTAssertTrue(markNotDone.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        app.segmentedControls["calendar-display-mode"].buttons["Day"].tap()
        XCTAssertTrue(markNotDone.waitForExistence(timeout: 5))
    }

    @MainActor
    func testGrammarColorsCanBeSelectedAndShownOnThePictureBoard() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Settings"].firstMatch.tap()

        let scheme = app.descendants(matching: .any)["grammar-color-scheme"].firstMatch
        for _ in 0..<10 where !scheme.isHittable { app.swipeUp() }
        XCTAssertTrue(scheme.isHittable)
        scheme.tap()
        app.buttons["Grammar backgrounds"].tap()
        app.buttons["Speak"].firstMatch.tap()

        let person = app.buttons["I"].firstMatch
        let action = app.buttons["want"].firstMatch
        XCTAssertTrue(person.waitForExistence(timeout: 5))
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        XCTAssertTrue((person.value as? String ?? "").contains("Grammar color: People and pronouns"))
        XCTAssertTrue((action.value as? String ?? "").contains("Grammar color: Actions and verbs"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Grammar-colored Core board"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testWordFinderGuidesBoardThenRevealsStagedTarget() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()

        app.buttons["Settings"].firstMatch.tap()
        let stagePicker = app.descendants(matching: .any)["vocabulary-stage"].firstMatch
        for _ in 0..<8 where !stagePicker.isHittable { app.swipeUp() }
        XCTAssertTrue(stagePicker.isHittable)
        stagePicker.tap()
        app.buttons["Start · essential words"].tap()
        app.buttons["Speak"].firstMatch.tap()

        let openFinder = app.buttons["open-word-finder"]
        openFinder.tap()
        let query = app.textFields["finder-query"]
        query.tap()
        query.typeText("water")
        app.buttons["finder-result-Needs-water"].tap()
        XCTAssertTrue(app.staticTexts["Step 1: Choose Needs"].waitForExistence(timeout: 5))
        let needs = app.buttons["Needs"]
        XCTAssertTrue((needs.value as? String ?? "").contains("Word finder next board"))
        needs.tap()
        XCTAssertTrue(app.staticTexts["Step 2: Select water"].waitForExistence(timeout: 5))
        let water = app.buttons["water"].firstMatch
        XCTAssertTrue(water.waitForExistence(timeout: 5))
        XCTAssertTrue((water.value as? String ?? "").contains("Word finder target"))
        app.buttons["end-word-finder"].tap()

        app.buttons["Core"].tap()
        XCTAssertFalse(app.buttons["like"].firstMatch.exists)
        openFinder.tap()
        let secondQuery = app.textFields["finder-query"]
        secondQuery.tap()
        secondQuery.typeText("like")
        app.buttons["finder-result-Core-like"].tap()
        let like = app.buttons["like"].firstMatch
        XCTAssertTrue(like.waitForExistence(timeout: 5))
        XCTAssertTrue((like.value as? String ?? "").contains("Word finder target"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Word finder reveals a staged word in its fixed slot"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        like.tap()
        XCTAssertFalse(app.buttons["end-word-finder"].exists)
    }

    @MainActor
    func testListeningReplyCanBeReviewedAndSpokenWithoutReplacingPictureMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let pictureMessage = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Message:")).firstMatch
        let previousMessage = pictureMessage.label

        app.buttons["open-listening-reply"].tap()
        XCTAssertTrue(app.navigationBars["Listen and reply"].waitForExistence(timeout: 5))
        let prompt = app.descendants(matching: .any)["listen-transcript"].firstMatch
        prompt.tap()
        prompt.typeText("Do you need a break?")
        let personalReply = app.buttons["listen-reply-i need a break"].firstMatch
        XCTAssertTrue(personalReply.waitForExistence(timeout: 5))
        personalReply.tap()
        let draft = app.descendants(matching: .any)["listen-draft"].firstMatch
        XCTAssertEqual(draft.value as? String, "I need a break.")
        XCTAssertTrue(app.buttons["listen-speak"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Listening reply with reviewed question and personal phrase"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["listen-speak"].tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(pictureMessage.label, previousMessage)
    }

    @MainActor
    func testVocabularyStagesKeepWordPositionsAndExploreTemporarily() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let want = app.buttons["want"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        let need = app.buttons["need"].firstMatch
        let originalColumnSpacing = need.frame.origin.x - want.frame.origin.x
        let originalRowSpacing = need.frame.origin.y - want.frame.origin.y
        app.buttons["Settings"].firstMatch.tap()
        let stagePicker = app.descendants(matching: .any)["vocabulary-stage"].firstMatch
        for _ in 0..<8 where !stagePicker.isHittable { app.swipeUp() }
        XCTAssertTrue(stagePicker.isHittable)
        stagePicker.tap()
        app.buttons["Start · essential words"].tap()
        app.buttons["Speak"].firstMatch.tap()

        XCTAssertTrue(want.exists)
        XCTAssertEqual(need.frame.origin.x - want.frame.origin.x, originalColumnSpacing, accuracy: 1)
        XCTAssertEqual(need.frame.origin.y - want.frame.origin.y, originalRowSpacing, accuracy: 1)
        XCTAssertFalse(app.buttons["like"].firstMatch.exists)
        let explore = app.buttons["explore-vocabulary"]
        XCTAssertTrue(explore.exists)
        explore.tap()
        XCTAssertTrue(app.buttons["like"].firstMatch.exists)
        explore.tap()
        XCTAssertFalse(app.buttons["like"].firstMatch.exists)

        let search = app.searchFields["Find a word"]
        search.tap()
        search.typeText("like")
        XCTAssertTrue(app.buttons["like"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPainCheckInCanDescribeBodyAreaAndPainType() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-pain-touch"]
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let painLink = app.descendants(matching: .any)["pain-check-in-link"].firstMatch
        for _ in 0..<12 where !painLink.isHittable { app.swipeUp() }
        XCTAssertTrue(painLink.isHittable)
        painLink.tap()
        XCTAssertTrue(app.navigationBars["Pain check-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["I am in pain."].exists)
        XCTAssertTrue(app.buttons["pain-speak"].exists)
        app.buttons["pain-area-head"].tap()
        app.segmentedControls.buttons["Back"].tap()
        app.buttons["pain-area-lowerBack"].tap()
        app.buttons["Sharp"].tap()
        let fivePointScale = app.buttons["1–5"]
        for _ in 0..<8 where !fivePointScale.isHittable { app.swipeUp() }
        XCTAssertTrue(fivePointScale.isHittable)
        fivePointScale.tap()
        let strength = app.buttons["pain-strength-4"]
        for _ in 0..<8 where !strength.isHittable { app.swipeUp() }
        XCTAssertTrue(strength.isHittable)
        strength.tap()
        XCTAssertTrue(app.staticTexts[
            "I have pain in my head and my lower back. It feels sharp. Pain level 4 out of 5."
        ].waitForExistence(timeout: 5))
        app.buttons["pain-speak"].tap()
        XCTAssertFalse(app.buttons["save-pain-entry"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pain check-in with body areas"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.scrollViews.firstMatch.swipeDown()
        let messageScreenshot = XCTAttachment(screenshot: app.screenshot())
        messageScreenshot.name = "Pain check-in message and actions"
        messageScreenshot.lifetime = .keepAlways
        add(messageScreenshot)
    }

    @MainActor
    func testPainCheckInCanChooseSpecificSpotAndTenPointScale() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-pain-touch"]
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let painLink = app.descendants(matching: .any)["pain-check-in-link"].firstMatch
        for _ in 0..<12 where !painLink.isHittable { app.swipeUp() }
        XCTAssertTrue(painLink.isHittable)
        painLink.tap()
        XCTAssertTrue(app.navigationBars["Pain check-in"].waitForExistence(timeout: 5))

        func tapVisible(_ element: XCUIElement) {
            for _ in 0..<12 where !element.isHittable { app.swipeUp() }
            XCTAssertTrue(element.isHittable)
            element.tap()
        }

        tapVisible(app.buttons["pain-area-leftArm"])
        tapVisible(app.descendants(matching: .any)["pain-specific-areas"])
        tapVisible(app.buttons["pain-area-leftHand"])
        tapVisible(app.buttons["pain-area-rightKnee"])
        tapVisible(app.buttons["1–10"])
        tapVisible(app.buttons["pain-strength-8"])
        XCTAssertTrue(app.staticTexts[
            "I have pain in my left hand and my right knee. Pain level 8 out of 10."
        ].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Specific pain areas and ten-point scale"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPainCheckInStepScanCoversBodyDetailsStrengthAndSaving() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-pain-scan"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-pain-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["Phrases"].firstMatch.tap()
        let painLink = app.descendants(matching: .any)["pain-check-in-link"].firstMatch
        for _ in 0..<12 where !painLink.isHittable { app.swipeUp() }
        XCTAssertTrue(painLink.isHittable)
        painLink.tap()

        let target = app.staticTexts["pain-scan-target"]
        let next = app.buttons["pain-scan-next"]
        let select = app.buttons["pain-scan-select"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Speak pain")
        select.tap()
        next.tap()
        XCTAssertEqual(target.label, "Share")
        next.tap()
        XCTAssertEqual(target.label, "Save phrase")
        next.tap()
        XCTAssertEqual(target.label, "Front")
        next.tap()
        XCTAssertEqual(target.label, "Back")
        select.tap()
        for _ in 0..<4 { next.tap() }
        XCTAssertEqual(target.label, "Upper back")
        select.tap()
        XCTAssertTrue(app.staticTexts["pain-message"].label.contains("upper back"))
        for _ in 0..<5 { next.tap() }
        XCTAssertEqual(target.label, "Choose a more specific spot")
        select.tap()
        next.tap()
        XCTAssertEqual(target.label, "Forehead")
        select.tap()
        XCTAssertTrue(app.staticTexts["pain-message"].label.contains("forehead"))

        for _ in 0..<32 where target.label != "Sharp" { next.tap() }
        XCTAssertEqual(target.label, "Sharp")
        select.tap()
        XCTAssertTrue(app.staticTexts["pain-message"].label.contains("sharp"))
        for _ in 0..<10 where target.label != "1–5" { next.tap() }
        XCTAssertEqual(target.label, "1–5")
        for _ in 0..<6 where target.label != "Pain strength 4 out of 5" { next.tap() }
        XCTAssertEqual(target.label, "Pain strength 4 out of 5")
        select.tap()
        XCTAssertTrue(app.staticTexts["pain-message"].label.contains("Pain level 4 out of 5"))
        next.tap()
        XCTAssertEqual(target.label, "Pain strength 5 out of 5")
        next.tap()
        XCTAssertEqual(target.label, "Save pain check-in")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pain check-in step scanning"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        select.tap()
        XCTAssertEqual(target.label, "Review saved check-ins")
        next.tap()
        XCTAssertEqual(target.label, "Back")
        select.tap()
        XCTAssertTrue(painLink.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPainCheckInAutoScanCanPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-pain-scan-auto"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-pain-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["Phrases"].firstMatch.tap()
        let painLink = app.descendants(matching: .any)["pain-check-in-link"].firstMatch
        for _ in 0..<12 where !painLink.isHittable { app.swipeUp() }
        XCTAssertTrue(painLink.isHittable)
        painLink.tap()

        let target = app.staticTexts["pain-scan-target"]
        let pause = app.buttons["pain-scan-pause"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        pause.tap()
        let held = target.label
        Thread.sleep(forTimeInterval: 3.5)
        XCTAssertEqual(target.label, held)
        pause.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", held), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 6), .completed)
    }

    @MainActor
    func testPainCheckInScanCanShareTheCurrentMessage() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-pain-scan"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-pain-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["Phrases"].firstMatch.tap()
        let painLink = app.descendants(matching: .any)["pain-check-in-link"].firstMatch
        for _ in 0..<12 where !painLink.isHittable { app.swipeUp() }
        XCTAssertTrue(painLink.isHittable)
        painLink.tap()
        let target = app.staticTexts["pain-scan-target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        app.buttons["pain-scan-next"].tap()
        XCTAssertEqual(target.label, "Share")
        app.buttons["pain-scan-select"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testRoutineStepCanHaveItsOwnTimer() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["routine-time-menu"].firstMatch.tap()
        app.buttons["1 min"].tap()
        if !app.navigationBars["Step timer"].exists {
            let timer = app.buttons["routine-open-timer"].firstMatch
            XCTAssertTrue(timer.waitForExistence(timeout: 5))
            timer.tap()
        }
        XCTAssertTrue(app.navigationBars["Step timer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Get dressed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start"].exists)
        app.buttons["routine-timer-toggle"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
        app.buttons["routine-timer-toggle"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Routine step timer paused"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testRoutineStepCanBeAddedWithSpokenInstructionAndProgress() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        XCTAssertTrue(app.progressIndicators["Routine progress"].exists)
        app.buttons["routine-add-detailed-step"].tap()
        XCTAssertTrue(app.navigationBars["Add routine step"].waitForExistence(timeout: 5))
        let name = "Pack my bag \(UUID().uuidString.prefix(5))"
        let title = app.textFields["routine-step-title"]
        title.tap()
        title.typeText(name)
        let spoken = app.textFields["routine-step-spoken-text"]
        spoken.tap()
        spoken.typeText("Please bring your bag")
        app.buttons["save-routine-step"].tap()
        let say = app.buttons["Say \(name)"]
        for _ in 0..<8 where !say.exists { app.swipeUp() }
        XCTAssertTrue(say.waitForExistence(timeout: 5))
        say.tap()
        XCTAssertTrue(app.buttons["\(name), not done"].exists)
        app.buttons["\(name), not done"].tap()
        XCTAssertTrue(app.buttons["\(name), done"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Routine step with spoken instruction and progress"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        for _ in 0..<8 where !app.progressIndicators["Routine progress"].exists { app.swipeDown() }
        XCTAssertTrue(app.progressIndicators["Routine progress"].exists)
    }

    @MainActor
    func testRoutineStepEditorOffersPhotoAndVoiceSources() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["routine-add-detailed-step"].tap()
        XCTAssertTrue(app.navigationBars["Add routine step"].waitForExistence(timeout: 5))
        let photo = app.buttons["Choose photo from Files"]
        for _ in 0..<5 where !photo.exists { app.swipeUp() }
        XCTAssertTrue(photo.exists)
        XCTAssertTrue(app.buttons["take-photo"].exists)
        let recording = app.buttons["routine-record-toggle"]
        for _ in 0..<5 where !recording.exists { app.swipeUp() }
        XCTAssertTrue(recording.exists)
        XCTAssertTrue(app.buttons["Import instruction from Files"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Routine photo and voice editor"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testCameraPickerOpensFromRoutineEditorWhenAvailable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["routine-add-detailed-step"].tap()
        let camera = app.buttons["take-photo"]
        XCTAssertTrue(camera.waitForExistence(timeout: 5))
        guard camera.isEnabled else { return }
        camera.tap()
        XCTAssertTrue(app.buttons["PhotoCapture"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "System camera from routine editor"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["DismissButton"].tap()
        XCTAssertTrue(app.navigationBars["Add routine step"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Remove photo"].exists)
    }

    @MainActor
    func testRoutinePDFPreviewOffersShareSaveAndPrint() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-routine-pdf"].tap()
        XCTAssertTrue(app.navigationBars["Routine PDF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["share-pdf"].exists)
        XCTAssertTrue(app.buttons["Save PDF"].exists)
        XCTAssertTrue(app.buttons["Print"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Routine PDF preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testRoutineVideoPlaysFromStepAndSavedFirstThenBoard() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-video")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        let play = app.buttons["routine-play-video"].firstMatch
        for _ in 0..<8 where !play.exists { app.swipeUp() }
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(app.navigationBars["Watch the bus"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hotspot-video-replay"].waitForExistence(timeout: 5))
        app.navigationBars["Watch the bus"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Watch the bus, not done"].waitForExistence(timeout: 5))
        let templates = app.buttons["open-routine-templates"]
        for _ in 0..<8 where !templates.exists { app.swipeDown() }
        templates.tap()
        app.staticTexts["Video routine test"].tap()
        app.buttons["routine-template-board"].tap()
        let firstVideo = app.buttons["first-then-first-video"]
        for _ in 0..<5 where !firstVideo.exists { app.swipeUp() }
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 5))
        firstVideo.tap()
        XCTAssertTrue(app.navigationBars["Watch the bus"].waitForExistence(timeout: 5))
        app.navigationBars["Watch the bus"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["first-then-done"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRoutineVideoCanBeAddedFromPhotos() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-video")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["routine-add-detailed-step"].tap()
        let title = "Video step \(UUID().uuidString.prefix(6))"
        let field = app.textFields["routine-step-title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(title)
        let picker = app.buttons["Choose video from Photos"]
        for _ in 0..<4 where !picker.isHittable { app.swipeUp() }
        picker.tap()
        let firstVideo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 20))
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        firstVideo.tap()
        if app.navigationBars["Photos"].exists, app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        }
        let removeVideo = app.buttons["Remove video"]
        for _ in 0..<5 where !removeVideo.exists { app.swipeUp() }
        XCTAssertTrue(removeVideo.waitForExistence(timeout: 30))
        app.buttons["save-routine-step"].tap()
        let play = app.buttons["Play video for \(title)"]
        for _ in 0..<10 where !play.exists { app.swipeUp() }
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRoutineStepOpensChoiceBoardAndReturnsToSpeak() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-choice")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        let choices = app.buttons["routine-open-choice-board"]
        for _ in 0..<8 where !choices.exists { app.swipeUp() }
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        choices.tap()
        XCTAssertTrue(app.navigationBars["Make a choice"].waitForExistence(timeout: 5))
        app.buttons["Window seat"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Window seat")
        app.buttons["Back to full Speak board"].tap()
        XCTAssertTrue(app.navigationBars["Open Voice"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavedFirstThenStepOpensAttachedChoiceBoard() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-choice")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-routine-templates"].tap()
        app.staticTexts["Choice routine test"].tap()
        app.buttons["routine-template-board"].tap()
        let choices = app.buttons["first-then-first-choices"]
        for _ in 0..<5 where !choices.exists { app.swipeUp() }
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        choices.tap()
        XCTAssertTrue(app.navigationBars["Make a choice"].waitForExistence(timeout: 5))
        app.buttons["Aisle seat"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Aisle seat")
        app.navigationBars["Make a choice"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["first-then-done"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavedRoutineModesShareProgressAndKeepChoicesAvailable() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-choice")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-routine-templates"].tap()
        app.staticTexts["Choice routine test"].tap()
        app.buttons["routine-template-board"].tap()
        let mode = app.descendants(matching: .any)["routine-board-mode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5))

        mode.tap()
        app.buttons["One step"].tap()
        XCTAssertTrue(app.staticTexts["NOW"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["THEN"].exists)
        app.buttons["first-then-done"].tap()
        XCTAssertTrue(app.staticTexts["1 of 2 steps done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sit down"].exists)

        mode.tap()
        app.buttons["Checklist"].tap()
        XCTAssertTrue(app.staticTexts["Mark any step when it is done. Tap its speaker to hear the instruction."].waitForExistence(timeout: 5))
        app.buttons["routine-board-undo-step"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["0 of 2 steps done"].waitForExistence(timeout: 5))

        mode.tap()
        app.buttons["To do / Done"].tap()
        XCTAssertTrue(app.staticTexts["TO DO"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DONE"].exists)
        let complete = app.buttons["routine-board-complete-step"].firstMatch
        for _ in 0..<8 where !complete.exists { app.swipeUp() }
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertTrue(app.staticTexts["1 of 2 steps done"].waitForExistence(timeout: 5))
        let columnsScreenshot = XCTAttachment(screenshot: app.screenshot())
        columnsScreenshot.name = "Saved routine To do Done columns"
        columnsScreenshot.lifetime = .keepAlways
        add(columnsScreenshot)

        for _ in 0..<8 where !mode.isHittable { app.swipeDown() }
        mode.tap()
        app.buttons["Envelope"].tap()
        XCTAssertTrue(app.staticTexts["STEP STRIP"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Done envelope"].exists)
        let envelopeScreenshot = XCTAttachment(screenshot: app.screenshot())
        envelopeScreenshot.name = "Saved routine envelope"
        envelopeScreenshot.lifetime = .keepAlways
        add(envelopeScreenshot)
        let putInEnvelope = app.buttons["routine-board-envelope-complete"].firstMatch
        for _ in 0..<8 where !putInEnvelope.exists { app.swipeUp() }
        XCTAssertTrue(putInEnvelope.waitForExistence(timeout: 5))
        putInEnvelope.tap()
        XCTAssertTrue(app.staticTexts["2 of 2 steps done"].waitForExistence(timeout: 5))
        let reset = app.buttons["first-then-reset"]
        for _ in 0..<8 where !reset.exists { app.swipeUp() }
        reset.tap()
        XCTAssertTrue(app.staticTexts["0 of 2 steps done"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRoutineStepCanBeDraggedToDoneColumn() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-choice")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-routine-templates"].tap()
        app.staticTexts["Choice routine test"].tap()
        app.buttons["routine-template-board"].tap()
        let mode = app.descendants(matching: .any)["routine-board-mode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.tap()
        app.buttons["To do / Done"].tap()
        let source = app.staticTexts["Choose a seat"]
        let target = app.staticTexts["Drag a step here when it is done."]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        source.press(forDuration: 1.2, thenDragTo: target)
        XCTAssertTrue(app.staticTexts["1 of 2 steps done"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRoutineStepCanBeDraggedIntoEnvelope() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-choice")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-routine-templates"].tap()
        app.staticTexts["Choice routine test"].tap()
        app.buttons["routine-template-board"].tap()
        let mode = app.descendants(matching: .any)["routine-board-mode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.tap()
        app.buttons["Envelope"].tap()
        let source = app.staticTexts["Choose a seat"]
        let target = app.staticTexts["The envelope is empty."]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        source.press(forDuration: 1.2, thenDragTo: target)
        XCTAssertTrue(app.staticTexts["1 of 2 steps done"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRoutineEditorLinksSavedChoiceBoard() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-routine-choice")
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["routine-add-detailed-step"].tap()
        let title = "Make a bus choice \(UUID().uuidString.prefix(6))"
        let field = app.textFields["routine-step-title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(title)
        let picker = app.descendants(matching: .any)["routine-step-choice-board"].firstMatch
        for _ in 0..<8 where !picker.isHittable { app.swipeUp() }
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        app.buttons["Bus choices"].tap()
        app.buttons["save-routine-step"].tap()
        let open = app.buttons["Open choices for \(title)"]
        for _ in 0..<10 where !open.exists { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.navigationBars["Make a choice"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRoutineProgressCanBeRecordedAndExported() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        let recordButton = app.buttons["routine-record-more-time"]
        for _ in 0..<12 where !recordButton.exists { app.swipeUp() }
        XCTAssertTrue(recordButton.exists)
        recordButton.tap()
        XCTAssertTrue(app.alerts["Routine recorded"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        let historyButton = app.buttons["open-routine-history"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()
        XCTAssertTrue(app.navigationBars["Routine history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["routine-history-record"].firstMatch.exists)
        XCTAssertTrue(app.buttons["routine-history-export"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Routine history with CSV export"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["routine-history-record"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Routine record"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Steps at that time"].exists)
    }

    @MainActor
    func testRoutineCanBeSavedAndLoadedAgain() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["routine-time-menu"].firstMatch.tap()
        app.buttons["1 min"].tap()
        let savedRoutinesLink = app.buttons["open-routine-templates"]
        for _ in 0..<6 where !savedRoutinesLink.exists { app.swipeDown() }
        savedRoutinesLink.tap()
        XCTAssertTrue(app.navigationBars["Saved routines"].waitForExistence(timeout: 5))
        let name = "Morning \(UUID().uuidString.prefix(5))"
        let nameField = app.textFields["routine-template-name"]
        nameField.tap()
        nameField.typeText(name)
        app.buttons["routine-template-save"].tap()
        let saved = app.staticTexts[name]
        for _ in 0..<12 where !saved.exists { app.swipeUp() }
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved routine list"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        saved.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
        app.buttons["routine-template-reminders"].tap()
        XCTAssertTrue(app.navigationBars["Routine reminders"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["routine-reminder-time"].exists)
        XCTAssertTrue(app.switches["routine-reminder-sound"].exists)
        XCTAssertTrue(app.buttons["routine-reminder-save"].exists)
        app.navigationBars["Routine reminders"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
        app.buttons["routine-template-board"].tap()
        XCTAssertTrue(app.navigationBars["First/Then board"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["first-then-first-speak"].exists)
        XCTAssertTrue(app.buttons["first-then-then-speak"].exists)
        XCTAssertTrue(app.buttons["first-then-print"].exists)
        let boardLayout = app.segmentedControls["first-then-layout"]
        XCTAssertTrue(boardLayout.exists)
        boardLayout.buttons["Side by side"].tap()
        boardLayout.buttons["Stacked"].tap()
        boardLayout.buttons["Auto"].tap()
        XCTAssertTrue(app.buttons["first-then-timer-toggle"].exists)
        let boardScreenshot = XCTAttachment(screenshot: app.screenshot())
        boardScreenshot.name = "Saved routine First Then board"
        boardScreenshot.lifetime = .keepAlways
        add(boardScreenshot)
        app.buttons["first-then-done"].tap()
        XCTAssertTrue(app.buttons["first-then-reset"].isEnabled)
        app.navigationBars["First/Then board"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
        app.buttons["routine-template-load"].tap()
        XCTAssertTrue(app.buttons["Replace current routine"].waitForExistence(timeout: 5))
        app.buttons["Replace current routine"].tap()
        XCTAssertTrue(app.navigationBars["Saved routines"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReminderTargetOpensSavedFirstThenBoard() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-reminder-target")
        app.launch()
        XCTAssertTrue(app.navigationBars["First/Then board"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["first-then-first-speak"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Routine"].firstMatch.exists)
    }

    @MainActor
    func testRoutineReminderCanBeScheduled() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        let savedRoutinesLink = app.buttons["open-routine-templates"]
        for _ in 0..<6 where !savedRoutinesLink.exists { app.swipeDown() }
        savedRoutinesLink.tap()
        let name = "Reminder \(UUID().uuidString.prefix(6))"
        let nameField = app.textFields["routine-template-name"]
        nameField.tap()
        nameField.typeText(name)
        app.buttons["routine-template-save"].tap()
        let saved = app.staticTexts[name]
        for _ in 0..<12 where !saved.exists { app.swipeUp() }
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        app.buttons["routine-template-reminders"].tap()
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.buttons["routine-reminder-save"].tap()
        app.navigationBars["Routine reminders"].tap()
        XCTAssertTrue(app.buttons["routine-reminder-delete"].waitForExistence(timeout: 30))
    }

    @MainActor
    func testWeeklyReminderTargetOpensMatchingDay() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-weekly-reminder-target")
        app.launch()
        XCTAssertTrue(app.navigationBars["Weekly plan"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["weekly-day-2"].isSelected)
        XCTAssertTrue(app.buttons["Say Weekly reminder test"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Routine"].firstMatch.exists)
    }

    @MainActor
    func testWeeklyActivityReminderCanBeScheduled() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-weekly-plan"].tap()
        app.buttons["add-weekly-activity"].tap()
        let name = "Remind step \(UUID().uuidString.prefix(6))"
        let field = app.textFields["weekly-activity-title"]
        field.tap()
        field.typeText(name)
        app.buttons["save-weekly-activity"].tap()
        XCTAssertTrue(app.buttons["Say \(name)"].waitForExistence(timeout: 5))
        app.buttons["Options for \(name)"].tap()
        app.buttons["Add reminder"].tap()
        XCTAssertTrue(app.navigationBars["Activity reminder"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["weekly-reminder-time"].exists)
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.buttons["weekly-reminder-save"].tap()
        app.navigationBars["Activity reminder"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Reminder set"].firstMatch.waitForExistence(timeout: 30))
    }

    @MainActor
    func testCalendarEventReminderCanBeScheduled() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-visual-calendar"].tap()
        app.buttons["calendar-add-event"].tap()
        let name = "Calendar reminder \(UUID().uuidString.prefix(6))"
        let field = app.textFields["calendar-event-title"]
        field.tap()
        field.typeText(name)
        app.buttons["calendar-done-editing"].tap()
        app.buttons["calendar-save-event"].tap()
        let options = app.buttons["Options for \(name)"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        app.buttons["Add reminder"].tap()
        XCTAssertTrue(app.navigationBars["Event reminder"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["calendar-reminder-time"].exists)
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.buttons["calendar-reminder-save"].tap()
        let reminderNavigationBar = app.navigationBars["Event reminder"]
        if reminderNavigationBar.exists { reminderNavigationBar.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["Reminder set"].firstMatch.waitForExistence(timeout: 30))
    }

    @MainActor
    func testCalendarReminderTargetOpensMatchingEvent() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-calendar-reminder-target")
        app.launch()
        XCTAssertTrue(app.navigationBars["Visual calendar"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Say Calendar reminder test"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Routine"].firstMatch.exists)
    }

    @MainActor
    func testStoryPageOffersPersonalNarration() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.buttons["Add story"].tap()
        let title = "Story \(UUID().uuidString.prefix(6))"
        let titleField = app.alerts.textFields["Story title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        app.alerts.buttons["Create"].tap()
        app.staticTexts[title].tap()
        app.buttons["Add first page"].tap()

        let pageText = app.textViews["Page text"]
        XCTAssertTrue(pageText.waitForExistence(timeout: 5))
        pageText.tap()
        pageText.typeText("I went to the park.")
        let record = app.buttons["story-record-toggle"]
        for _ in 0..<3 {
            if record.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(record.exists)
        XCTAssertTrue(app.buttons["Import narration from Files"].exists)
        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "Story narration editor"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["story-read-page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["story-share-text"].exists)
        XCTAssertTrue(app.buttons["story-preview-pdf"].exists)
        app.buttons["story-read-page"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Story page with narration controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["story-preview-pdf"].tap()
        XCTAssertTrue(app.navigationBars["Printable story"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Save PDF"].exists)
        XCTAssertTrue(app.buttons["Print"].exists)
        let pdfScreenshot = XCTAttachment(screenshot: app.screenshot())
        pdfScreenshot.name = "Printable story preview"
        pdfScreenshot.lifetime = .keepAlways
        add(pdfScreenshot)
    }

    @MainActor
    func testStoryReadingShowsSpokenWordHighlighting() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.buttons["Create a story"].tap()
        let title = "Highlight \(UUID().uuidString.prefix(6))"
        let titleField = app.alerts.textFields["Story title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        app.alerts.buttons["Create"].tap()
        app.staticTexts[title].tap()
        app.buttons["Add first page"].tap()

        let pageText = app.textViews["Page text"]
        XCTAssertTrue(pageText.waitForExistence(timeout: 5))
        pageText.tap()
        pageText.typeText("I can tell my own story. Today I went to the park, saw a dog, and waved to a friend.")
        app.buttons["Save"].tap()
        let read = app.buttons["story-read-page"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        read.tap()
        let followAlong = app.otherElements["story-follow-along"]
        XCTAssertTrue(followAlong.waitForExistence(timeout: 5))
        let speaking = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value BEGINSWITH %@", "Now speaking:"),
            object: followAlong)
        XCTAssertEqual(XCTWaiter.wait(for: [speaking], timeout: 10), .completed)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Story word highlighting"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testOneTapStoryReadingAdvancesAndReadsTheNextPage() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-story-one-tap")
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.staticTexts["One tap story test"].tap()

        let oneTap = app.switches["story-one-tap-toggle"]
        XCTAssertTrue(oneTap.waitForExistence(timeout: 5))
        oneTap.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        XCTAssertEqual(oneTap.value as? String, "1")
        let action = app.buttons["story-read-page"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 of 2"].exists)
        let page = app.buttons["story-page-tap"]
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        page.tap()
        XCTAssertEqual(action.label, "Next and read")

        action.tap()
        XCTAssertTrue(app.staticTexts["2 of 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(page.label.contains("Then I can tell someone"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "One tap story on second page"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Previous"].tap()
        XCTAssertTrue(app.staticTexts["1 of 2"].waitForExistence(timeout: 5))
        XCTAssertEqual(action.label, "Read this page")
    }

    @MainActor
    func testTwoSwitchStoryReadingSeparatesPageTurnAndSpeech() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-story-one-tap")
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.staticTexts["One tap story test"].tap()

        let oneTap = app.switches["story-one-tap-toggle"]
        let twoSwitch = app.switches["story-two-switch-toggle"]
        XCTAssertTrue(oneTap.waitForExistence(timeout: 5))
        XCTAssertTrue(twoSwitch.exists)
        oneTap.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        XCTAssertEqual(oneTap.value as? String, "1")
        twoSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        XCTAssertEqual(twoSwitch.value as? String, "1")
        XCTAssertEqual(oneTap.value as? String, "0")

        let read = app.buttons["story-read-page"]
        let next = app.buttons["story-switch-next-page"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        XCTAssertTrue(next.exists)
        XCTAssertEqual(read.label, "Read current page")
        read.tap()
        XCTAssertTrue(app.otherElements["story-follow-along"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 of 2"].exists)

        next.tap()
        XCTAssertTrue(app.staticTexts["2 of 2"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["story-follow-along"].exists)
        read.tap()
        XCTAssertTrue(app.otherElements["story-follow-along"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Two-switch story controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStorySlideshowWaitsForNarrationAndCanPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-story-slideshow")
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.staticTexts["Slideshow story test"].tap()

        let play = app.buttons["story-slideshow-play"]
        let pauseMenu = app.buttons["story-slideshow-pause"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertTrue(pauseMenu.exists)
        pauseMenu.tap()
        app.buttons["5 second pause"].tap()
        play.tap()
        XCTAssertEqual(play.label, "Pause slideshow")
        XCTAssertTrue(app.staticTexts["1 of 2"].exists)
        let narrationFinished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "This is the first page."),
            object: app.staticTexts["This is the first page."])
        XCTAssertEqual(XCTWaiter.wait(for: [narrationFinished], timeout: 3), .completed)
        XCTAssertTrue(app.staticTexts["1 of 2"].exists)
        play.tap()
        XCTAssertEqual(play.label, "Play slideshow")
        XCTAssertTrue(app.staticTexts["1 of 2"].exists)

        pauseMenu.tap()
        app.buttons["No pause"].tap()
        play.tap()
        XCTAssertTrue(app.staticTexts["2 of 2"].waitForExistence(timeout: 8))
        XCTAssertEqual(play.label, "Play slideshow")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Story slideshow second page"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStorySlideshowAdvancesAfterSystemSpeech() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-story-one-tap")
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.staticTexts["One tap story test"].tap()
        app.buttons["story-slideshow-pause"].tap()
        app.buttons["No pause"].tap()
        app.buttons["story-slideshow-play"].tap()
        XCTAssertTrue(app.staticTexts["2 of 2"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Then I can tell someone what happened next and how I feel."].exists)
    }

    @MainActor
    func testStoryFileExportAndImportAreAvailable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        let title = "Shared story \(UUID().uuidString.prefix(6))"
        app.buttons["Add story"].tap()
        let titleField = app.alerts["New story"].textFields["Story title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        app.alerts["New story"].buttons["Create"].tap()
        let storyActions = app.buttons["Actions for \(title)"]
        for _ in 0..<10 where !storyActions.exists { app.swipeUp() }
        XCTAssertTrue(storyActions.waitForExistence(timeout: 5))
        for _ in 0..<10 where !storyActions.isHittable { app.swipeUp() }
        XCTAssertTrue(storyActions.isHittable)
        storyActions.tap()
        XCTAssertTrue(app.buttons["Export story file"].waitForExistence(timeout: 5))
        app.buttons["Export story file"].tap()
        let saveFile = app.buttons["Save"].firstMatch
        guard saveFile.waitForExistence(timeout: 30) else {
            XCTFail("Story export picker did not open")
            return
        }
        XCTAssertEqual(saveFile.label, "Save")
        saveFile.tap()
        func exporterClosed(_ timeout: TimeInterval) -> Bool {
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: saveFile)
            return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
        }
        if !exporterClosed(10), saveFile.exists {
            saveFile.tap()
        }
        guard exporterClosed(15) else {
            XCTFail("Story export picker did not close after saving")
            return
        }
        let importer = app.buttons["story-import-toolbar"]
        XCTAssertTrue(importer.waitForExistence(timeout: 5))
        XCTAssertTrue(importer.isHittable)
        importer.tap()
        if UIDevice.current.userInterfaceIdiom == .pad {
            if !app.staticTexts[title + ".json"].exists {
                let onDevice = app.cells["DOC.sidebar.item.On My iPad"]
                XCTAssertTrue(onDevice.waitForExistence(timeout: 5))
                onDevice.tap()
            }
        } else {
            let browse = app.buttons["Browse"]
            XCTAssertTrue(browse.waitForExistence(timeout: 5))
            browse.tap()
            let onDevice = app.staticTexts["On My iPhone"]
            if onDevice.exists { onDevice.tap() }
        }
        let filePicker = app.otherElements["Browse View (Picker)"]
        XCTAssertTrue(filePicker.waitForExistence(timeout: 5))
        let storyFile = filePicker.staticTexts[title + ".json"]
        XCTAssertTrue(storyFile.waitForExistence(timeout: 5))
        for _ in 0..<10 where !storyFile.isHittable { filePicker.swipeUp() }
        XCTAssertTrue(storyFile.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Story file import picker"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        if UIDevice.current.userInterfaceIdiom == .pad { return }
        storyFile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.0)).tap()
        let importedAlert = app.alerts["Story file"]
        if !importedAlert.waitForExistence(timeout: 3), storyFile.exists {
            storyFile.tap()
        }
        guard importedAlert.waitForExistence(timeout: 10) else {
            XCTFail("Story import did not finish after selecting its file")
            return
        }
        XCTAssertTrue(importedAlert.staticTexts[
            "Added \(title) (imported 2) to My stories."].exists)
        importedAlert.buttons["OK"].tap()
    }

    @MainActor
    func testStoryVideoPagePlaysAndPrintsPosterNote() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-story-video")
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.staticTexts["Story video test"].tap()
        let play = app.buttons["story-play-video"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(app.navigationBars["Page video"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hotspot-video-replay"].waitForExistence(timeout: 5))
        app.navigationBars["Page video"].buttons["Done"].tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        app.buttons["story-preview-pdf"].tap()
        XCTAssertTrue(app.navigationBars["Printable story"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testStoryVideoPageCanBeAddedFromPhotos() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Stories"].firstMatch.tap()
        app.buttons["Create a story"].tap()
        let title = "Video story \(UUID().uuidString.prefix(6))"
        let field = app.alerts.textFields["Story title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(title)
        app.alerts.buttons["Create"].tap()
        app.staticTexts[title].tap()
        app.buttons["Add first page"].tap()
        let pageText = app.textViews["Page text"]
        XCTAssertTrue(pageText.waitForExistence(timeout: 5))
        pageText.tap()
        pageText.typeText("I can watch the bus arrive.")
        let videoPicker = app.buttons["Choose video from Photos"]
        for _ in 0..<4 where !videoPicker.isHittable { app.swipeUp() }
        XCTAssertTrue(videoPicker.waitForExistence(timeout: 5))
        videoPicker.tap()
        let firstVideo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 20))
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        firstVideo.tap()
        if app.navigationBars["Photos"].exists, app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        }
        let removeVideo = app.buttons["Remove video"]
        for _ in 0..<5 where !removeVideo.exists { app.swipeUp() }
        XCTAssertTrue(removeVideo.waitForExistence(timeout: 20))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["story-play-video"].waitForExistence(timeout: 5))
        app.buttons["story-play-video"].tap()
        XCTAssertTrue(app.navigationBars["Page video"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPersonalVoiceAvailabilityIsExplainedInSettings() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["voice-picker"].waitForExistence(timeout: 5))

        let personalVoiceHeading = app.staticTexts["Personal Voice"]
        for _ in 0..<4 {
            if personalVoiceHeading.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(personalVoiceHeading.exists)
        let descriptions = [
            "Personal Voice is not supported on this device.",
            "Your Personal Voice is available in the Voice picker above.",
            "Access is allowed. Create a Personal Voice in device Accessibility settings to add it to the Voice picker.",
            "Personal Voice access is off. You can change it in the device’s Settings for Open Voice."
        ]
        XCTAssertTrue(app.buttons["personal-voice-request"].exists || descriptions.contains { app.staticTexts[$0].exists })
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Personal Voice settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSingleButtonCanBeSetUpAndLocked() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["single-button-setup-link"].tap()

        let message = "Please give me a moment \(UUID().uuidString.prefix(6))"
        let field = app.descendants(matching: .any)["single-button-new-message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(message)
        app.buttons["single-button-create"].tap()
        XCTAssertTrue(app.staticTexts[message].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["single-button-record"].exists)
        let lock = app.buttons["single-button-lock"]
        if lock.label.contains("Hide editing") { lock.tap() }
        XCTAssertTrue(lock.label.contains("Show editing"))

        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["One button mode"].tap()
        let play = app.buttons["single-button-play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["single-button-setup"].exists)
        play.tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Locked one button mode"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Done"].tap()
    }

    @MainActor
    func testJokeCanBeCreatedAndSharedInTwoSteps() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["jokes-link"].tap()
        app.buttons["add-joke"].tap()

        let title = "New joke \(UUID().uuidString.prefix(6))"
        let setup = "Why did the cup pause?"
        let punchline = "It needed a little break."
        let titleField = app.descendants(matching: .any)["joke-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        let setupField = app.descendants(matching: .any)["joke-setup"]
        setupField.tap()
        setupField.typeText(setup)
        let punchlineField = app.descendants(matching: .any)["joke-punchline"]
        punchlineField.tap()
        punchlineField.typeText(punchline)
        app.buttons["save-joke"].tap()

        let saved = app.staticTexts[title]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertEqual(app.staticTexts["joke-current-line"].label, setup)
        let jokeScreen = XCTAttachment(screenshot: app.screenshot())
        jokeScreen.name = "Joke setup on iPad"
        jokeScreen.lifetime = .keepAlways
        add(jokeScreen)
        app.buttons["joke-show-setup"].tap()
        XCTAssertEqual(app.staticTexts["large-message"].label, setup)
        let partnerScreen = XCTAttachment(screenshot: app.screenshot())
        partnerScreen.name = "Joke partner display"
        partnerScreen.lifetime = .keepAlways
        add(partnerScreen)
        app.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["joke-current-line"].label, setup)
        app.buttons["joke-next"].tap()
        XCTAssertEqual(app.staticTexts["joke-current-line"].label, punchline)
        app.buttons["joke-show-punchline"].tap()
        XCTAssertEqual(app.staticTexts["large-message"].label, punchline)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["joke-repeat"].exists)
        app.buttons["joke-repeat"].tap()
        XCTAssertEqual(app.staticTexts["joke-current-line"].label, setup)

        app.terminate()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["jokes-link"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNextWordSuggestionCompletesTypedMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("I need ")
        let nextWord = app.buttons["next-word-suggestion-a"]
        XCTAssertTrue(nextWord.waitForExistence(timeout: 5))
        nextWord.tap()
        XCTAssertEqual(editor.value as? String, "I need a ")
    }

    @MainActor
    func testAlphabetKeyboardOffersNextWordSuggestion() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        let clear = app.buttons["alphabet-clear"]
        if clear.isEnabled { clear.tap() }
        app.buttons["alphabet-key-I"].tap()
        app.buttons["alphabet-space"].tap()
        for letter in ["N", "E", "E", "D"] {
            app.buttons["alphabet-key-\(letter)"].tap()
        }
        app.buttons["alphabet-space"].tap()
        let nextWord = app.buttons["alphabet-next-word-suggestion-a"]
        XCTAssertTrue(nextWord.waitForExistence(timeout: 5))
        nextWord.tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "I need a ")
    }

    @MainActor
    func testCommonFirstLetterOrderIsSharedByKeyboardAndSpeechCues() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()

        let commonFirst = app.segmentedControls.buttons["Common first"]
        XCTAssertTrue(commonFirst.waitForExistence(timeout: 5))
        commonFirst.tap()
        let firstKeyboardKey = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "alphabet-key-")).element(boundBy: 0)
        XCTAssertEqual(firstKeyboardKey.identifier, "alphabet-key-E")
        app.buttons["Done"].tap()

        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["Speech cues"].tap()
        let firstCueLetter = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "speech-cue-letter-")).element(boundBy: 0)
        XCTAssertTrue(firstCueLetter.waitForExistence(timeout: 5))
        XCTAssertEqual(firstCueLetter.identifier, "speech-cue-letter-E")
        firstCueLetter.tap()
        XCTAssertEqual(app.staticTexts["speech-cue-output"].label, "E")
    }

    @MainActor
    func testQwertyKeyboardKeepsThreeRowsAndTypedDraft() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        let clear = app.buttons["alphabet-clear"]
        if clear.isEnabled { clear.tap() }
        let qwerty = app.segmentedControls.buttons["QWERTY"]
        XCTAssertTrue(qwerty.waitForExistence(timeout: 5))
        qwerty.tap()
        let q = app.buttons["alphabet-key-Q"]
        let p = app.buttons["alphabet-key-P"]
        let a = app.buttons["alphabet-key-A"]
        let z = app.buttons["alphabet-key-Z"]
        XCTAssertTrue(q.waitForExistence(timeout: 5))
        XCTAssertEqual(q.frame.midY, p.frame.midY, accuracy: 1)
        XCTAssertGreaterThan(a.frame.midY, q.frame.midY)
        XCTAssertGreaterThan(z.frame.midY, a.frame.midY)
        q.tap()
        app.buttons["alphabet-key-U"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Qu")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "QWERTY large-key keyboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.segmentedControls.buttons["A–Z"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Qu")
        app.navigationBars["Alphabet keyboard"].buttons["Done"].tap()
    }

    @MainActor
    func testCustomLetterOrderReordersKeyboardAndSpeechCues() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        let clear = app.buttons["alphabet-clear"]
        if clear.isEnabled { clear.tap() }
        app.segmentedControls.buttons["Custom"].tap()
        app.buttons["alphabet-edit-custom-order"].tap()
        XCTAssertTrue(app.navigationBars["Custom letter order"].waitForExistence(timeout: 5))
        app.collectionViews.buttons["A–Z"].tap()
        app.buttons["custom-letter-down-A"].tap()
        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "Custom letter order editor"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)
        app.navigationBars["Custom letter order"].buttons["Done"].tap()

        let firstKeyboardKey = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "alphabet-key-")).element(boundBy: 0)
        XCTAssertEqual(firstKeyboardKey.identifier, "alphabet-key-B")
        app.buttons["alphabet-key-B"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "B")
        app.navigationBars["Alphabet keyboard"].buttons["Done"].tap()

        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["Speech cues"].tap()
        let firstCueLetter = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "speech-cue-letter-")).element(boundBy: 0)
        XCTAssertTrue(firstCueLetter.waitForExistence(timeout: 5))
        XCTAssertEqual(firstCueLetter.identifier, "speech-cue-letter-B")
    }

    @MainActor
    func testOpenBoardImportAndExportAreAvailableInBoardManager() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        let importer = app.buttons["import-open-board"]
        let exporter = app.buttons["export-open-boards"]
        for _ in 0..<5 {
            if importer.isHittable && exporter.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(importer.isHittable)
        XCTAssertTrue(exporter.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Open Board Format controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testEditableWordKeyboardComposesAndKeepsTheTypedDraft() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        let clear = app.buttons["alphabet-clear"]
        if clear.isEnabled { clear.tap() }
        let wordKeys = app.switches["alphabet-word-keys-toggle"]
        XCTAssertTrue(wordKeys.waitForExistence(timeout: 5))
        if wordKeys.value as? String != "1" { wordKeys.tap() }
        XCTAssertTrue(app.buttons["Insert I"].waitForExistence(timeout: 5))
        app.buttons["Insert I"].tap()
        app.buttons["Insert want"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "I want ")

        app.buttons["alphabet-edit-word-keys"].tap()
        XCTAssertTrue(app.navigationBars["Edit word keys"].waitForExistence(timeout: 5))
        app.buttons["add-word-key"].tap()
        let unique = String(UUID().uuidString.prefix(6))
        let customText = "a break \(unique)"
        let label = app.textFields["word-key-label"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText("break \(unique)")
        let insertedText = app.textFields["word-key-text"]
        insertedText.tap()
        insertedText.typeText(customText)
        app.buttons["save-word-key"].tap()
        app.navigationBars["Edit word keys"].buttons["Done"].tap()
        app.swipeUp()
        app.buttons["Insert \(customText)"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "I want \(customText) ")
        app.swipeUp()
        app.buttons["word-key-delete"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "I want \(customText)")
        app.buttons["word-key-space"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "I want \(customText) ")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Editable word keyboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars["Alphabet keyboard"].buttons["Done"].tap()
        XCTAssertEqual(app.textViews["Type a message"].value as? String, "I want \(customText) ")
    }

    @MainActor
    func testAlphabetKeyboardBuildsTheSameTypedMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let open = app.buttons["open-alphabet-keyboard"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.navigationBars["Alphabet keyboard"].waitForExistence(timeout: 5))
        let clear = app.buttons["alphabet-clear"]
        if clear.isEnabled { clear.tap() }
        app.buttons["alphabet-key-H"].tap()
        app.buttons["alphabet-key-I"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hi")
        app.buttons["alphabet-cursor-left"].tap()
        app.buttons["alphabet-key-A"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hai")
        app.buttons["alphabet-delete"].tap()
        app.buttons["alphabet-cursor-right"].tap()
        app.buttons["alphabet-space"].tap()
        app.buttons["alphabet-key-A"].tap()
        app.buttons["alphabet-delete"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hi ")
        XCTAssertTrue(app.buttons["alphabet-speak"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Alphabet keyboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars["Alphabet keyboard"].buttons["Done"].tap()
        XCTAssertEqual(app.textViews["Type a message"].value as? String, "Hi ")
    }

    @MainActor
    func testGroupedKeyboardUsesLargeTwoStepKeysWithoutLosingTheMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        let clear = app.buttons["alphabet-clear"]
        if clear.isEnabled { clear.tap() }
        app.segmentedControls.buttons["A–Z"].tap()
        let grouped = app.switches["alphabet-grouped-keys"]
        XCTAssertTrue(grouped.waitForExistence(timeout: 5))
        if (grouped.value as? String) != "1" { grouped.tap() }

        let secondGroup = app.buttons["alphabet-key-group-1"]
        XCTAssertTrue(secondGroup.waitForExistence(timeout: 5))
        secondGroup.tap()
        XCTAssertTrue(app.buttons["alphabet-all-key-groups"].exists)
        app.buttons["alphabet-key-H"].tap()
        XCTAssertTrue(secondGroup.exists)
        secondGroup.tap()
        app.buttons["alphabet-key-I"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hi")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Grouped keyboard after typing"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["123"].tap()
        app.buttons["alphabet-key-group-0"].tap()
        app.buttons["alphabet-key-1"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hi1")
        app.buttons["ABC"].tap()
        grouped.tap()
        XCTAssertTrue(app.buttons["alphabet-key-A"].exists)
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hi1")
    }

    @MainActor
    func testTenKeyKeyboardHasTenLargeTargetsAndReturnsAfterEachLetter() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        let clear = app.buttons["alphabet-clear"]
        if clear.isEnabled { clear.tap() }
        app.segmentedControls.buttons["A–Z"].tap()
        let tenKey = app.switches["alphabet-ten-key-toggle"]
        XCTAssertTrue(tenKey.waitForExistence(timeout: 5))
        if (tenKey.value as? String) != "1" { tenKey.tap() }

        let targets = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "alphabet-ten-key-"))
        XCTAssertEqual(targets.count, 10)
        let firstGroup = app.buttons["alphabet-ten-key-group-0"]
        XCTAssertTrue(firstGroup.exists)
        XCTAssertEqual(firstGroup.label, "Key group A, B, C, D, E")
        let secondGroup = app.buttons["alphabet-ten-key-group-1"]
        secondGroup.tap()
        app.buttons["alphabet-key-H"].tap()
        XCTAssertTrue(secondGroup.exists)
        secondGroup.tap()
        app.buttons["alphabet-key-I"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hi")
        app.buttons["alphabet-ten-key-space"].tap()
        app.buttons["alphabet-ten-key-numbers"].tap()
        XCTAssertEqual(app.buttons["alphabet-ten-key-group-0"].label, "Key group 0, 1, 2, 3")
        app.buttons["alphabet-ten-key-group-0"].tap()
        app.buttons["alphabet-key-1"].tap()
        app.buttons["alphabet-ten-key-shift"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hi 1.")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Ten Key large-target keyboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["alphabet-ten-key-delete"].tap()
        app.buttons["alphabet-ten-key-numbers"].tap()
        tenKey.tap()
        XCTAssertTrue(app.buttons["alphabet-key-A"].exists)
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Hi 1")
    }

    @MainActor
    func testTypedWordFormsWorkInSystemAndAlphabetKeyboards() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Keyboard"].tap()

        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("go")
        let forms = app.buttons["typed-word-forms"]
        XCTAssertTrue(forms.isEnabled)
        let systemScreenshot = XCTAttachment(screenshot: app.screenshot())
        systemScreenshot.name = "System keyboard typed word forms"
        systemScreenshot.lifetime = .keepAlways
        add(systemScreenshot)
        forms.tap()
        XCTAssertTrue(app.navigationBars["Typed word forms"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Preview went"].exists)
        app.buttons["typed-word-form-past"].tap()
        XCTAssertEqual(editor.value as? String, "went")

        app.terminate()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        XCTAssertTrue(app.navigationBars["Alphabet keyboard"].waitForExistence(timeout: 5))
        let alphabetClear = app.buttons["alphabet-clear"]
        if alphabetClear.isEnabled { alphabetClear.tap() }
        for key in ["G", "O"] { app.buttons["alphabet-key-\(key)"].tap() }
        app.buttons["alphabet-space"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Go ")
        for key in ["H", "O", "M", "E"] { app.buttons["alphabet-key-\(key)"].tap() }
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Go home")
        for _ in 0..<5 { app.buttons["alphabet-cursor-left"].tap() }
        let alphabetForms = app.buttons["alphabet-word-forms"]
        XCTAssertTrue(alphabetForms.waitForExistence(timeout: 5))
        alphabetForms.tap()
        XCTAssertTrue(app.navigationBars["Typed word forms"].waitForExistence(timeout: 5))
        let pickerScreenshot = XCTAttachment(screenshot: app.screenshot())
        pickerScreenshot.name = "Typed word form picker"
        pickerScreenshot.lifetime = .keepAlways
        add(pickerScreenshot)
        app.buttons["typed-word-form-past"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Went home")
        let keyboardScreenshot = XCTAttachment(screenshot: app.screenshot())
        keyboardScreenshot.name = "Typed form in alphabet keyboard"
        keyboardScreenshot.lifetime = .keepAlways
        add(keyboardScreenshot)
    }

    @MainActor
    func testSavedSentenceSuggestionCompletesBothTypingMethods() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let token = String((0..<6).map { _ in letters.randomElement()! })
        let phrase = "\(token) please give me time to answer."
        let phraseField = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<6 where !phraseField.isHittable { app.swipeUp() }
        XCTAssertTrue(phraseField.isHittable)
        phraseField.tap()
        phraseField.typeText(phrase)
        let save = app.buttons["Save phrase"]
        for _ in 0..<5 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()

        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        editor.tap()
        editor.typeText(token)
        let sentence = app.buttons["sentence-suggestion-0"]
        XCTAssertTrue(sentence.waitForExistence(timeout: 5))
        XCTAssertTrue(sentence.label.contains(phrase))
        let systemScreenshot = XCTAttachment(screenshot: app.screenshot())
        systemScreenshot.name = "Sentence suggestion while typing"
        systemScreenshot.lifetime = .keepAlways
        add(systemScreenshot)
        sentence.tap()
        XCTAssertEqual(editor.value as? String, phrase)

        app.buttons["open-alphabet-keyboard"].tap()
        let alphabetClear = app.buttons["alphabet-clear"]
        if alphabetClear.isEnabled { alphabetClear.tap() }
        for letter in token { app.buttons["alphabet-key-\(letter)"].tap() }
        let suggestions = app.buttons["alphabet-sentence-suggestions"]
        XCTAssertTrue(suggestions.waitForExistence(timeout: 5))
        suggestions.tap()
        XCTAssertTrue(app.navigationBars["Sentence suggestions"].waitForExistence(timeout: 5))
        let firstChoice = app.buttons["sentence-choice-0"]
        XCTAssertTrue(firstChoice.label.contains(phrase))
        let alphabetScreenshot = XCTAttachment(screenshot: app.screenshot())
        alphabetScreenshot.name = "Sentence suggestions in large-key keyboard"
        alphabetScreenshot.lifetime = .keepAlways
        add(alphabetScreenshot)
        firstChoice.tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, phrase)
    }

    @MainActor
    func testPronunciationCorrectionCanBeAddedAndPreviewed() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let link = app.buttons["pronunciations-link"]
        for _ in 0..<5 {
            if link.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.navigationBars["Pronunciations"].waitForExistence(timeout: 5))
        app.buttons["add-pronunciation"].tap()

        let written = "AAC\(String(UUID().uuidString.prefix(6)))"
        let writtenField = app.textFields["pronunciation-written"]
        let spokenField = app.textFields["pronunciation-spoken"]
        XCTAssertTrue(writtenField.waitForExistence(timeout: 5))
        writtenField.tap()
        writtenField.typeText(written)
        spokenField.tap()
        spokenField.typeText("A A C")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts[written].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try \(written)"].exists)
        app.buttons["Try \(written)"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pronunciation corrections"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testTypingSpeechChoicesAreAvailable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let options = app.buttons["typing-speech-options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        app.textViews["Type a message"].tap()
        XCTAssertTrue(options.isHittable)
        options.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Characters"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Words"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["Sentences"].firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Typing speech choices"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testTypedSpeechShowsFollowAlongInEditorAndLargeMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let typed = app.textViews["Type a message"]
        typed.tap()
        typed.typeText("Please wait while I speak. We can talk slowly. "
                       + "I need a moment. Thank you for listening.")
        app.buttons["Speak text"].firstMatch.tap()
        let followAlong = app.descendants(matching: .any)["speech-follow-along"].firstMatch
        XCTAssertTrue(followAlong.waitForExistence(timeout: 3))
        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "Typed speech follow along"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)

        app.buttons["More"].tap()
        app.buttons["Show large message"].tap()
        app.buttons["Speak message"].tap()
        let largeMessage = app.descendants(matching: .any)["large-message"].firstMatch
        XCTAssertTrue(largeMessage.waitForExistence(timeout: 3))
        XCTAssertTrue(largeMessage.label.contains("Speaking"))
        let largeScreenshot = XCTAttachment(screenshot: app.screenshot())
        largeScreenshot.name = "Large speech follow along"
        largeScreenshot.lifetime = .keepAlways
        add(largeScreenshot)
        app.buttons["Face partner"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["current-spoken-word"].firstMatch.exists)
        let partnerScreenshot = XCTAttachment(screenshot: app.screenshot())
        partnerScreenshot.name = "Partner-facing speech follow along"
        partnerScreenshot.lifetime = .keepAlways
        add(partnerScreenshot)
    }

    @MainActor
    func testSavedPhraseShortcutExpandsInKeyboardMode() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let suffix = String(UUID().uuidString.prefix(6))
        let phrase = "Thank you for waiting \(suffix)."
        let shortcut = "ty\(suffix.lowercased())"
        let phraseField = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<4 {
            if phraseField.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(phraseField.waitForExistence(timeout: 5))
        phraseField.tap()
        phraseField.typeText(phrase)
        let shortcutField = app.textFields["Typing shortcut (optional)"]
        for _ in 0..<5 {
            if shortcutField.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(shortcutField.waitForExistence(timeout: 5))
        shortcutField.tap()
        shortcutField.typeText(shortcut)
        let save = app.buttons["Save phrase"]
        for _ in 0..<3 {
            if save.exists { break }
            app.swipeUp()
        }
        save.tap()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Keyboard"].tap()
        let message = app.textViews["Type a message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()
        message.typeText("Please \(shortcut)")
        let suggestion = app.buttons["shortcut-\(shortcut)"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()
        XCTAssertTrue(message.value as? String == "Please \(phrase) ")
    }

    @MainActor
    func testFillablePhraseCanBeCompletedAndShown() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()

        let suffix = String(UUID().uuidString.prefix(6))
        let template = "I would like {drink} at {place} \(suffix)."
        let phraseField = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<4 {
            if phraseField.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(phraseField.waitForExistence(timeout: 5))
        phraseField.tap()
        phraseField.typeText(template)
        app.buttons["Save phrase"].tap()

        let row = app.buttons[template]
        for _ in 0..<4 {
            if row.exists { break }
            app.swipeDown()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["Complete phrase"].waitForExistence(timeout: 5))
        let drink = app.textFields["phrase-template-field-drink"]
        let place = app.textFields["phrase-template-field-place"]
        drink.tap()
        drink.typeText("water")
        place.tap()
        place.typeText("home")
        let completed = "I would like water at home \(suffix)."
        XCTAssertEqual(app.staticTexts["phrase-template-preview"].label, completed)
        let fillScreenshot = XCTAttachment(screenshot: app.screenshot())
        fillScreenshot.name = "Fillable phrase completed"
        fillScreenshot.lifetime = .keepAlways
        add(fillScreenshot)

        let show = app.buttons["phrase-template-show-partner"]
        XCTAssertTrue(show.waitForExistence(timeout: 5))
        show.tap()
        XCTAssertTrue(app.staticTexts["large-message"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["large-message"].label, completed)
    }

    @MainActor
    func testSpeechCueTopicCanBeAdded() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["Speech cues"].tap()
        app.segmentedControls.buttons["Topics"].tap()
        app.buttons["Manage topics"].tap()

        let topic = "Books \(String(UUID().uuidString.prefix(6)))"
        let name = app.textFields["Topic name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(topic)
        app.buttons["Add topic"].tap()
        XCTAssertTrue(app.staticTexts[topic].waitForExistence(timeout: 5))
        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "Speech topic editor"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)
    }

    @MainActor
    func testPartnerSpellingUsesYesNoRowsAndShowsTheMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["Speech cues"].tap()
        app.segmentedControls.buttons["Partner"].tap()

        let prompt = app.staticTexts["partner-spelling-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.label, "Is your letter in A, B, C, D?")
        app.buttons["partner-spelling-next"].tap()
        XCTAssertEqual(prompt.label, "Is your letter in E, F, G, H?")
        app.buttons["partner-spelling-choose"].tap()
        XCTAssertEqual(prompt.label, "Is it E?")
        app.buttons["partner-spelling-next"].tap()
        XCTAssertEqual(prompt.label, "Is it F?")
        app.buttons["partner-spelling-choose"].tap()
        XCTAssertEqual(app.staticTexts["speech-cue-output"].label, "F")
        app.buttons["speech-cue-show-partner"].tap()
        XCTAssertTrue(app.staticTexts["large-message"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["large-message"].label, "F")
        app.buttons["Done"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Partner-assisted spelling"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["partner-spelling-space"].tap()
        app.buttons["partner-spelling-delete"].tap()
        XCTAssertEqual(app.staticTexts["speech-cue-output"].label, "F")
        for _ in 0..<7 { app.buttons["partner-spelling-next"].tap() }
        XCTAssertEqual(prompt.label, "Do you need an action?")
        XCTAssertEqual(app.staticTexts["partner-spelling-options"].label, "Space · Delete · Wait · Please guess")
        let scanScreenshot = XCTAttachment(screenshot: app.screenshot())
        scanScreenshot.name = "Partner-assisted action row"
        scanScreenshot.lifetime = .keepAlways
        add(scanScreenshot)
        app.buttons["partner-spelling-choose"].tap()
        app.buttons["partner-spelling-next"].tap()
        app.buttons["partner-spelling-next"].tap()
        XCTAssertEqual(prompt.label, "Is it Wait?")
        app.buttons["partner-spelling-choose"].tap()
        XCTAssertEqual(app.staticTexts["partner-spelling-signal"].label, "Please wait.")
        XCTAssertEqual(app.staticTexts["speech-cue-output"].label, "F")
        let actionScreenshot = XCTAttachment(screenshot: app.screenshot())
        actionScreenshot.name = "Partner-assisted spelling actions"
        actionScreenshot.lifetime = .keepAlways
        add(actionScreenshot)
    }

    @MainActor
    func testSpeechCueBoardLettersTopicsAndPartnerDisplay() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["Speech cues"].tap()

        XCTAssertTrue(app.buttons["speech-cue-letter-A"].waitForExistence(timeout: 5))
        app.buttons["speech-cue-letter-A"].tap()
        app.buttons["speech-cue-letter-B"].tap()
        XCTAssertEqual(app.staticTexts["speech-cue-output"].label, "AB")
        let lettersScreenshot = XCTAttachment(screenshot: app.screenshot())
        lettersScreenshot.name = "Speech cue letters"
        lettersScreenshot.lifetime = .keepAlways
        add(lettersScreenshot)

        app.buttons["speech-cue-show-partner"].tap()
        XCTAssertTrue(app.staticTexts["large-message"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["large-message"].label, "AB")
        app.buttons["Done"].tap()

        app.segmentedControls.buttons["Topics"].tap()
        app.buttons["People"].tap()
        XCTAssertEqual(app.staticTexts["speech-cue-output"].label, "People")
        XCTAssertTrue(app.buttons["Manage topics"].exists)
        let topicsScreenshot = XCTAttachment(screenshot: app.screenshot())
        topicsScreenshot.name = "Speech cue topics"
        topicsScreenshot.lifetime = .keepAlways
        add(topicsScreenshot)
    }

    @MainActor
    func testSpeechCuePrintablePDFPreviewOffersSaveAndPrint() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["Speech cues"].tap()
        let printable = app.buttons["speech-cue-printable"]
        XCTAssertTrue(printable.waitForExistence(timeout: 5))
        printable.tap()
        XCTAssertTrue(app.navigationBars["Printable cue boards"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertTrue(app.buttons["Save PDF"].exists)
        XCTAssertTrue(app.buttons["Print"].exists)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Printable speech cue board preview"
        preview.lifetime = .keepAlways
        add(preview)
    }

    @MainActor
    func testSavedPhraseCanBeFiledAndFound() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()

        let suffix = String(UUID().uuidString.prefix(6))
        let phrase = "Please take me to the library \(suffix)"
        let folder = "Places \(suffix)"
        let phraseField = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<3 {
            if phraseField.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(phraseField.waitForExistence(timeout: 5))
        phraseField.tap()
        phraseField.typeText(phrase)
        let folderField = app.textFields["Folder (optional)"]
        folderField.tap()
        folderField.typeText(folder)
        let hideKeyboard = app.keyboards.buttons["Hide keyboard"]
        if hideKeyboard.exists { hideKeyboard.tap() }
        let savePhrase = app.buttons["Save phrase"]
        for _ in 0..<4 where !savePhrase.isHittable { app.swipeUp() }
        XCTAssertTrue(savePhrase.isHittable)
        savePhrase.tap()

        XCTAssertTrue(app.staticTexts[folder].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[phrase].exists)
        let folderScreenshot = XCTAttachment(screenshot: app.screenshot())
        folderScreenshot.name = "Saved phrase folder"
        folderScreenshot.lifetime = .keepAlways
        add(folderScreenshot)

        let search = app.searchFields["Find a phrase"]
        if app.buttons["Search"].exists {
            app.buttons["Search"].tap()
        }
        for _ in 0..<4 {
            if search.exists { break }
            app.swipeDown()
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(suffix)
        XCTAssertTrue(app.buttons[phrase].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch.exists)

        let rename = app.buttons["Rename folder \(folder)"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.tap()
        let folderName = app.textFields["Folder name"]
        XCTAssertTrue(folderName.waitForExistence(timeout: 5))
        folderName.tap()
        let renamed = "New places \(suffix)"
        folderName.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: folder.count) + renamed)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[renamed].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[phrase].exists)
    }

    @MainActor
    func testSavedPhraseTapInsertsIntoTypedDraftAndOpensKeyboard() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let typed = app.textViews["Type a message"]
        typed.tap()
        typed.typeText("I need")
        let firstPart = (typed.value as? String) ?? ""
        XCTAssertFalse(firstPart.isEmpty)

        app.buttons["Phrases"].firstMatch.tap()
        let addToText = app.segmentedControls.buttons["Add to text"]
        XCTAssertTrue(addToText.waitForExistence(timeout: 5))
        addToText.tap()
        let phrase = "a little time \(UUID().uuidString.prefix(5))"
        let phraseField = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<8 where !phraseField.isHittable { app.swipeUp() }
        XCTAssertTrue(phraseField.isHittable)
        phraseField.tap()
        phraseField.typeText(phrase)
        app.buttons["Save phrase"].tap()

        let row = app.buttons[phrase]
        for _ in 0..<8 where !row.isHittable { app.swipeDown() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(typed.waitForExistence(timeout: 5))
        XCTAssertEqual(typed.value as? String, "\(firstPart) \(phrase)")
        XCTAssertTrue(app.buttons["Pictures"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved phrase added to typed draft"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPhraseTapOverrideAddsToTextFromListAndCardBoard() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let typed = app.textViews["Type a message"]
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Phrases"].firstMatch.tap()
        app.segmentedControls.buttons["Speak"].tap()

        let phrase = "Please add this thought \(UUID().uuidString.prefix(5))."
        let field = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<8 where !field.isHittable { app.swipeUp() }
        XCTAssertTrue(field.isHittable)
        field.tap()
        field.typeText(phrase)
        app.buttons["Save phrase"].tap()
        let row = app.buttons[phrase]
        for _ in 0..<8 where !row.isHittable { app.swipeDown() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 0.8)
        app.buttons["Edit phrase"].tap()
        let picker = app.descendants(matching: .any)["phrase-tap-action-override"].firstMatch
        for _ in 0..<5 where !picker.isHittable { app.swipeUp() }
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        let insert = app.descendants(matching: .any)["phrase-action-insert"].firstMatch
        XCTAssertTrue(insert.waitForExistence(timeout: 5))
        insert.tap()
        app.buttons["Save"].tap()

        for _ in 0..<8 where !row.isHittable { app.swipeDown() }
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(typed.waitForExistence(timeout: 5))
        XCTAssertEqual(typed.value as? String, phrase)

        app.buttons["Phrases"].firstMatch.tap()
        let openBoard = app.buttons["phrases-card-board"]
        for _ in 0..<8 where !openBoard.isHittable { app.swipeDown() }
        XCTAssertTrue(openBoard.isHittable)
        openBoard.tap()
        XCTAssertTrue(app.navigationBars["Phrase cards"].waitForExistence(timeout: 5))
        let search = app.searchFields["Find a phrase"]
        if search.exists {
            search.tap()
            search.typeText(phrase)
        }
        let card = app.buttons[phrase]
        for _ in 0..<8 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(typed.waitForExistence(timeout: 5))
        XCTAssertEqual(typed.value as? String, "\(phrase) \(phrase)")
    }

    @MainActor
    func testFilledSavedPhraseCanInsertIntoTypedDraft() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Phrases"].firstMatch.tap()
        app.segmentedControls.buttons["Add to text"].tap()

        let suffix = String(UUID().uuidString.prefix(5))
        let template = "I need {item} \(suffix)"
        let phraseField = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<8 where !phraseField.isHittable { app.swipeUp() }
        XCTAssertTrue(phraseField.isHittable)
        phraseField.tap()
        phraseField.typeText(template)
        app.buttons["Save phrase"].tap()

        let row = app.buttons[template]
        for _ in 0..<8 where !row.isHittable { app.swipeDown() }
        XCTAssertTrue(row.isHittable)
        row.tap()
        let item = app.textFields["phrase-template-field-item"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        item.typeText("water")
        XCTAssertEqual(app.staticTexts["phrase-template-preview"].label, "I need water \(suffix)")
        app.buttons["Insert into typed message"].tap()
        let typed = app.textViews["Type a message"]
        XCTAssertTrue(typed.waitForExistence(timeout: 5))
        XCTAssertEqual(typed.value as? String, "I need water \(suffix)")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Filled phrase added to typed draft"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSavedPhraseVoiceEditorOpens() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let edit = app.buttons["Record voice for I need a break."]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        let phrasesScreenshot = XCTAttachment(screenshot: app.screenshot())
        phrasesScreenshot.name = "Saved phrases with voice controls"
        phrasesScreenshot.lifetime = .keepAlways
        add(phrasesScreenshot)
        edit.tap()
        XCTAssertTrue(app.navigationBars["Phrase voice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["phrase-record-toggle"].exists)
        XCTAssertTrue(app.buttons["Import audio from Files"].exists)
        let voiceScreenshot = XCTAttachment(screenshot: app.screenshot())
        voiceScreenshot.name = "Saved phrase voice editor"
        voiceScreenshot.lifetime = .keepAlways
        add(voiceScreenshot)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testSavedPhrasePictureAndColorEditorPersists() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()

        let phrase = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break."))
            .firstMatch
        for _ in 0..<5 {
            if phrase.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))
        phrase.press(forDuration: 0.8)
        app.buttons["Edit phrase"].tap()

        XCTAssertTrue(app.navigationBars["Edit phrase"].waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if app.buttons["phrase-picture-photos"].exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["phrase-picture-photos"].exists)
        XCTAssertTrue(app.buttons["phrase-picture-files"].exists)
        for _ in 0..<4 {
            if app.buttons["phrase-color-mint"].exists { break }
            app.swipeUp()
        }
        app.buttons["phrase-color-mint"].tap()
        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "Saved phrase picture and color editor"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)
        app.buttons["Save"].tap()

        app.terminate()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        for _ in 0..<5 {
            if app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch.waitForExistence(timeout: 5))
        let phraseScreenshot = XCTAttachment(screenshot: app.screenshot())
        phraseScreenshot.name = "Saved phrase with color cue after relaunch"
        phraseScreenshot.lifetime = .keepAlways
        add(phraseScreenshot)
    }

    @MainActor
    func testSavedPhraseKeepsItsOwnSpokenLanguageAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let phrase = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch
        for _ in 0..<5 {
            if phrase.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))
        phrase.press(forDuration: 0.8)
        app.buttons["Edit phrase"].tap()
        let picker = app.descendants(matching: .any)["phrase-spoken-language"].firstMatch
        for _ in 0..<4 {
            if picker.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let spanish = app.descendants(matching: .any)["phrase-language-es-ES"].firstMatch
        XCTAssertTrue(spanish.waitForExistence(timeout: 5))
        spanish.tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "es-ES"))
            .firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        for _ in 0..<5 {
            if app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "es-ES"))
                .firstMatch.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "es-ES"))
            .firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPicturePhraseBoardShowsLargeSpeakingCards() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.segmentedControls.buttons["Speak"].tap()
        let openBoard = app.buttons["phrases-card-board"]
        XCTAssertTrue(openBoard.waitForExistence(timeout: 5))
        openBoard.tap()

        XCTAssertTrue(app.navigationBars["Phrase cards"].waitForExistence(timeout: 5))
        let phrase = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break."))
            .firstMatch
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))
        let boardScreenshot = XCTAttachment(screenshot: app.screenshot())
        boardScreenshot.name = "Picture phrase board"
        boardScreenshot.lifetime = .keepAlways
        add(boardScreenshot)
        phrase.tap()
        XCTAssertTrue(app.navigationBars["Phrase cards"].exists)
        let folderPicker = app.buttons["phrase-card-folder"]
        XCTAssertTrue(folderPicker.exists)
        folderPicker.tap()
        app.buttons["Quick communication"].tap()
        XCTAssertTrue(phrase.exists)
    }

    @MainActor
    func testRecentlyUsedPhraseAppearsInListAndPictureBoard() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-recent-phrases")
        app.launch()
        defer {
            app.terminate()
            app.launchArguments = ["-ui-test-recent-phrases-cleanup"]
            app.launch()
            app.terminate()
        }

        app.buttons["Phrases"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Phrases you speak or add to text will appear here."]
            .waitForExistence(timeout: 5))
        let saved = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", "saved-phrase-", "Please give me time."
        )).firstMatch
        for _ in 0..<12 where !saved.isHittable { app.swipeUp() }
        XCTAssertTrue(saved.isHittable)
        saved.tap()

        let recent = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label == %@", "recent-phrase-", "Please give me time."
        )).firstMatch
        for _ in 0..<12 where !recent.isHittable { app.swipeDown() }
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        XCTAssertTrue(recent.isHittable)

        let openBoard = app.buttons["phrases-card-board"]
        for _ in 0..<5 where !openBoard.isHittable { app.swipeDown() }
        XCTAssertTrue(openBoard.isHittable)
        openBoard.tap()
        let folderPicker = app.buttons["phrase-card-folder"]
        if folderPicker.exists {
            folderPicker.tap()
        } else {
            app.buttons["More"].tap()
            app.buttons["Folder"].tap()
        }
        app.buttons["Recent phrases"].tap()
        XCTAssertTrue(app.staticTexts["phrase-card-current-folder"].waitForExistence(timeout: 5))
        let card = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "phrase-card-", "Please give me time."
        )).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
    }

    @MainActor
    func testShortPhraseLabelAppearsOnListAndCardAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let suffix = String(UUID().uuidString.prefix(6))
        let fullPhrase = "Please give me time to explain my answer \(suffix)."
        let cardLabel = "My answer \(suffix)"
        let phraseField = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<6 where !phraseField.isHittable { app.swipeUp() }
        XCTAssertTrue(phraseField.isHittable)
        phraseField.tap()
        phraseField.typeText(fullPhrase)
        let labelField = app.textFields["new-phrase-card-label"]
        for _ in 0..<4 where !labelField.isHittable { app.swipeUp() }
        XCTAssertTrue(labelField.isHittable)
        labelField.tap()
        labelField.typeText(cardLabel)
        let save = app.buttons["Save phrase"]
        for _ in 0..<5 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()

        let search = app.searchFields["Find a phrase"]
        if app.buttons["Search"].exists { app.buttons["Search"].tap() }
        for _ in 0..<6 where !search.exists { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(suffix)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", cardLabel)).firstMatch
        for _ in 0..<6 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.isHittable)
        XCTAssertTrue(row.label.contains(fullPhrase))

        app.terminate()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-card-board"].tap()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", cardLabel)).firstMatch
        for _ in 0..<4 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.isHittable)
        XCTAssertTrue(card.label.contains(fullPhrase))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Short label on picture phrase card"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPhraseCollectionFileCanBeShared() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let share = app.buttons["share-phrase-file"]
        for _ in 0..<8 where !share.isHittable { app.swipeUp() }
        XCTAssertTrue(share.isHittable)
        share.tap()
        let allPhrases = app.descendants(matching: .any)["All phrases"].firstMatch
        XCTAssertTrue(allPhrases.waitForExistence(timeout: 5))
        allPhrases.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Phrase collection file share"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPhraseCollectionFileExportAndImportPreview() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let exporter = app.buttons["export-phrase-file"]
        for _ in 0..<8 where !exporter.isHittable { app.swipeUp() }
        XCTAssertTrue(exporter.isHittable)
        exporter.tap()
        let allPhrases = app.descendants(matching: .any)["All phrases"].firstMatch
        XCTAssertTrue(allPhrases.waitForExistence(timeout: 5))
        allPhrases.tap()
        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 30))
        save.tap()
        if app.alerts.buttons["Replace"].waitForExistence(timeout: 2) {
            app.alerts.buttons["Replace"].tap()
        }
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 15), .completed)
        let importer = app.buttons["import-phrase-file"]
        XCTAssertTrue(importer.waitForExistence(timeout: 5))
        importer.tap()
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            XCTAssertTrue(app.buttons["Browse"].waitForExistence(timeout: 5))
            return
        }
        let fileName = "open-voice-phrases.json"
        if !app.staticTexts[fileName].exists {
            let onDevice = app.cells["DOC.sidebar.item.On My iPad"]
            XCTAssertTrue(onDevice.waitForExistence(timeout: 5))
            onDevice.tap()
        }
        let picker = app.otherElements["Browse View (Picker)"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let phraseFile = picker.staticTexts[fileName]
        XCTAssertTrue(phraseFile.waitForExistence(timeout: 10))
        for _ in 0..<8 where !phraseFile.isHittable { picker.swipeUp() }
        XCTAssertTrue(phraseFile.isHittable)
        phraseFile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.0)).tap()
        let preview = app.navigationBars["Import phrases"]
        if !preview.waitForExistence(timeout: 5), phraseFile.exists {
            phraseFile.tap()
        }
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        let update = app.buttons["phrase-file-update-matching"]
        for _ in 0..<8 where !update.isHittable { app.swipeUp() }
        XCTAssertTrue(update.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Phrase collection import preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        update.tap()
        let status = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@",
            "Added 0, updated ")).firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPhraseCardsCanBeReorderedAndKeepTheirPositionsAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-card-board"].tap()
        let breakCard = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch
        let answerCard = app.buttons["Please give me time to answer."]
        XCTAssertTrue(breakCard.waitForExistence(timeout: 5))
        XCTAssertTrue(answerCard.waitForExistence(timeout: 5))
        XCTAssertEqual(Set([breakCard.value as? String, answerCard.value as? String]),
                       Set(["Card 1 of 5", "Card 2 of 5"]))
        let first = breakCard.value as? String == "Card 1 of 5" ? breakCard : answerCard
        let second = breakCard.value as? String == "Card 2 of 5" ? breakCard : answerCard
        second.press(forDuration: 0.8)
        let moveEarlier = app.buttons["Move earlier"]
        XCTAssertTrue(moveEarlier.waitForExistence(timeout: 5))
        XCTAssertTrue(moveEarlier.isEnabled)
        moveEarlier.tap()
        let firstPosition = NSPredicate(format: "value == %@", "Card 1 of 5")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: firstPosition,
                                                                     object: second)], timeout: 5), .completed)
        XCTAssertEqual(first.value as? String, "Card 2 of 5")

        app.terminate()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-card-board"].tap()
        XCTAssertEqual(second.value as? String, "Card 1 of 5")
        second.press(forDuration: 0.8)
        app.buttons["Move later"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: firstPosition,
                                                                     object: first)], timeout: 5), .completed)
    }

    @MainActor
    func testPhraseCardGridSupportsSixteenBySixteenAndPagedSingleCards() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-card-board"].tap()
        app.buttons["phrase-card-grid-settings"].tap()
        XCTAssertTrue(app.navigationBars["Phrase card grid"].waitForExistence(timeout: 5))
        let columns = app.descendants(matching: .any)["phrase-grid-columns"].firstMatch
        if !columns.exists { app.buttons["phrase-grid-mode"].tap() }
        columns.tap()
        app.buttons["16"].tap()
        let rows = app.descendants(matching: .any)["phrase-grid-rows"].firstMatch
        rows.tap()
        app.buttons["16"].tap()
        XCTAssertTrue(app.staticTexts["256 card positions per page"].exists)
        app.navigationBars["Phrase card grid"].buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["16 columns × 16 rows"].waitForExistence(timeout: 5))

        app.buttons["phrase-card-grid-settings"].tap()
        columns.tap()
        app.buttons["4"].tap()
        columns.tap()
        app.buttons["1"].tap()
        rows.tap()
        app.buttons["4"].tap()
        rows.tap()
        app.buttons["1"].tap()
        XCTAssertTrue(app.staticTexts["1 card position per page"].exists)
        app.navigationBars["Phrase card grid"].buttons["Done"].tap()
        let pageCount = app.staticTexts["phrase-grid-page-count"]
        XCTAssertTrue(pageCount.waitForExistence(timeout: 5))
        XCTAssertTrue(pageCount.label.hasPrefix("Page 1 of "))
        let total = String(pageCount.label.dropFirst("Page 1 of ".count))
        XCTAssertGreaterThan(Int(total) ?? 0, 1)
        app.buttons["phrase-grid-next-page"].tap()
        XCTAssertEqual(pageCount.label, "Page 2 of \(total)")
        app.buttons["phrase-grid-previous-page"].tap()
        let totalPages = Int(total) ?? 0
        guard totalPages > 1 else { XCTFail("Expected more than one phrase page"); return }
        var cardToMove: XCUIElement?
        var sourcePosition = 1
        for page in 1...totalPages {
            let card = app.buttons.matching(NSPredicate(format: "value == %@", "Grid position \(page)"))
                .firstMatch
            if card.exists {
                cardToMove = card
                sourcePosition = page
                break
            }
            if page < totalPages { app.buttons["phrase-grid-next-page"].tap() }
        }
        guard let cardToMove else { XCTFail("No phrase card found on the grid"); return }
        cardToMove.press(forDuration: 0.8)
        app.buttons["Move to grid position"].tap()
        XCTAssertTrue(app.navigationBars["Move phrase card"].waitForExistence(timeout: 5))
        let position = app.textFields["phrase-grid-position-input"]
        XCTAssertTrue(position.waitForExistence(timeout: 5))
        let destination = totalPages + 3
        XCTAssertLessThanOrEqual(destination, 10_000)
        position.tap()
        position.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: String(sourcePosition).count) + String(destination))
        let doneTyping = app.buttons["Done typing"]
        if doneTyping.exists { doneTyping.tap() }
        app.buttons["phrase-grid-confirm-move"].tap()
        let movedPage = NSPredicate(format: "label == %@", "Page \(destination) of \(destination)")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: movedPage,
                                                                     object: pageCount)], timeout: 5), .completed)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "value == %@", "Grid position \(destination)"))
            .firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testQuickPhraseListCanReorderCardsInTheSameFolder() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-card-board"].tap()
        let breakCard = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch
        let answerCard = app.buttons["Please give me time to answer."]
        XCTAssertTrue(breakCard.waitForExistence(timeout: 5))
        XCTAssertTrue(answerCard.waitForExistence(timeout: 5))
        let secondLabel = breakCard.value as? String == "Card 2 of 5"
            ? "I need a break." : "Please give me time to answer."
        app.navigationBars["Phrase cards"].buttons.firstMatch.tap()
        let row = app.buttons[secondLabel]
        for _ in 0..<8 {
            if row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
        row.press(forDuration: 0.8)
        let moveEarlier = app.buttons["Move earlier"]
        XCTAssertTrue(moveEarlier.waitForExistence(timeout: 5))
        XCTAssertTrue(moveEarlier.isEnabled)
        moveEarlier.tap()
        let boardLink = app.buttons["phrases-card-board"]
        for _ in 0..<8 {
            if boardLink.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(boardLink.isHittable)
        boardLink.tap()
        let movedCard = app.buttons[secondLabel]
        XCTAssertEqual(movedCard.value as? String, "Card 1 of 5")
        movedCard.press(forDuration: 0.8)
        app.buttons["Move later"].tap()
    }

    @MainActor
    func testSavedPhrasePhotoAppearsOnPictureBoardAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let phrase = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch
        for _ in 0..<5 {
            if phrase.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))
        phrase.press(forDuration: 0.8)
        app.buttons["Edit phrase"].tap()
        XCTAssertTrue(app.navigationBars["Edit phrase"].waitForExistence(timeout: 5))
        let choosePhoto = app.buttons["phrase-picture-photos"]
        for _ in 0..<4 {
            if choosePhoto.exists { break }
            app.swipeUp()
        }
        choosePhoto.tap()
        let firstPhoto = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 20))
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        firstPhoto.tap()
        if app.navigationBars["Photos"].exists, app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        }
        XCTAssertTrue(app.images["Phrase picture"].waitForExistence(timeout: 10))
        app.buttons["Save"].tap()

        app.terminate()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-card-board"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Picture phrase card after photo import and relaunch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSavedPhraseCanShareItsAudio() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let share = app.buttons["Share I need a break."]
        for _ in 0..<5 {
            if share.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.buttons["Share text"].waitForExistence(timeout: 5))
        app.buttons["Share audio"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 20))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved phrase audio share"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPicturePhraseCardCanShareItsAudio() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        app.buttons["phrases-card-board"].tap()
        let phrase = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "I need a break.")).firstMatch
        XCTAssertTrue(phrase.waitForExistence(timeout: 5))
        phrase.press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["Share audio"].waitForExistence(timeout: 5))
        app.buttons["Share audio"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testSavedPhraseTextShareStillOpensShareSheet() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let share = app.buttons["Share I need a break."]
        for _ in 0..<5 {
            if share.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        app.buttons["Share text"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMessageBankImportIsAvailableInQuickPhrases() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let importButton = app.buttons["message-bank-import"]
        for _ in 0..<5 {
            if importButton.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(importButton.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Message bank import in Quick phrases"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testHistoryCanBePausedFromSpeakAndPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let saveHistory = app.switches["Save spoken messages on this device"]
        for _ in 0..<6 {
            if saveHistory.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(saveHistory.isHittable)
        if saveHistory.value as? String == "0" {
            saveHistory.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(saveHistory.value as? String, "1")
        app.buttons["Speak"].firstMatch.tap()

        let toggle = app.buttons["toggle-history-pause"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.label == "Resume message history" { toggle.tap() }
        XCTAssertEqual(toggle.label, "Pause message history")
        toggle.tap()
        XCTAssertTrue(app.staticTexts["History paused"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["New spoken messages are not saved"].exists)
        app.buttons["Keyboard"].tap()
        XCTAssertTrue(app.staticTexts["History paused"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["History paused"].waitForExistence(timeout: 5))
        app.buttons["toggle-history-pause"].tap()
        XCTAssertFalse(app.staticTexts["History paused"].exists)

        app.buttons["Settings"].firstMatch.tap()
        let resetHistory = app.switches["Save spoken messages on this device"]
        for _ in 0..<6 {
            if resetHistory.isHittable { break }
            app.swipeUp()
        }
        if resetHistory.value as? String == "1" {
            resetHistory.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
    }

    @MainActor
    func testLearnedWordSuggestionsCanBeEnabledAndCleared() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let history = app.switches["Save spoken messages on this device"]
        for _ in 0..<6 {
            if history.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(history.isHittable)
        if history.value as? String == "1" {
            history.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let learning = app.switches["learn-prediction-toggle"]
        for _ in 0..<8 {
            if learning.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(learning.isHittable)
        if learning.value as? String == "0" {
            learning.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(learning.value as? String, "1")
        let previousWords = app.buttons["clear-learned-prediction"]
        if previousWords.exists { previousWords.tap() }
        app.buttons["Speak"].firstMatch.tap()
        let pause = app.buttons["toggle-history-pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        if pause.label.contains("Resume") { pause.tap() }
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("zephyrium")
        XCTAssertEqual(editor.value as? String, "zephyrium")
        for _ in 0..<3 { app.buttons["Speak text"].tap() }
        clear.tap()
        editor.tap()
        editor.typeText("zep")
        let suggestion = app.buttons["word-suggestion-zephyrium"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()
        XCTAssertEqual(editor.value as? String, "zephyrium ")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Completed learned word"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Settings"].firstMatch.tap()
        let clearLearned = app.buttons["clear-learned-prediction"]
        for _ in 0..<8 {
            if clearLearned.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(clearLearned.isHittable)
        clearLearned.tap()
        XCTAssertFalse(clearLearned.exists)
        let reset = app.switches["learn-prediction-toggle"]
        if reset.value as? String == "1" {
            reset.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
    }

    @MainActor
    func testLearnedSentenceCompletesTypedDraftWithoutMessageHistory() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let history = app.switches["Save spoken messages on this device"]
        let settingsList = app.collectionViews.firstMatch
        for _ in 0..<20 {
            if history.isHittable { break }
            settingsList.swipeUp()
        }
        XCTAssertTrue(history.isHittable)
        if history.value as? String == "1" {
            history.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let learning = app.switches["learn-prediction-toggle"]
        for _ in 0..<12 {
            if learning.isHittable { break }
            settingsList.swipeUp()
        }
        XCTAssertTrue(learning.isHittable)
        if learning.value as? String == "0" {
            learning.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let old = app.buttons["clear-learned-prediction"]
        if old.exists { old.tap() }
        app.buttons["Speak"].firstMatch.tap()
        let pause = app.buttons["toggle-history-pause"]
        if pause.label.contains("Resume") { pause.tap() }
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        app.buttons["open-alphabet-keyboard"].tap()
        for letter in "BLUERAVEN" {
            if letter == "R" { app.buttons["alphabet-space"].tap() }
            app.buttons["alphabet-key-\(letter)"].tap()
        }
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Blue raven")
        for _ in 0..<3 { app.buttons["alphabet-speak"].tap() }
        app.buttons["alphabet-clear"].tap()
        for letter in "BLUER" {
            if letter == "R" { app.buttons["alphabet-space"].tap() }
            app.buttons["alphabet-key-\(letter)"].tap()
        }
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Blue r")
        let sentence = app.buttons["alphabet-sentence-suggestions"]
        XCTAssertTrue(sentence.waitForExistence(timeout: 5))
        sentence.tap()
        let choice = app.buttons["sentence-choice-0"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        XCTAssertEqual(choice.label, "Blue raven")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Learned sentence suggestion"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        choice.tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "Blue raven")
        app.buttons["Done"].tap()
        app.buttons["Settings"].firstMatch.tap()
        let clearLearned = app.buttons["clear-learned-prediction"]
        for _ in 0..<12 {
            if clearLearned.isHittable { break }
            settingsList.swipeUp()
        }
        XCTAssertTrue(clearLearned.isHittable)
        clearLearned.tap()
        let reset = app.switches["learn-prediction-toggle"]
        if reset.value as? String == "1" {
            reset.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
    }

    @MainActor
    func testSystemKeyboardKeepsRapidMultiwordTextInOrder() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("blue raven")
        XCTAssertEqual(editor.value as? String, "blue raven")
        clear.tap()
    }

    @MainActor
    func testSystemKeyboardWordFormsUsesTappedMiddleWord() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        editor.tap()
        editor.typeText("go home")
        XCTAssertEqual(editor.value as? String, "go home")
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.05)).tap()
        let forms = app.buttons["typed-word-forms"]
        XCTAssertTrue(forms.isEnabled)
        forms.tap()
        XCTAssertTrue(app.staticTexts["Choose a form for “go”. Preview speaks it before you use it."].exists)
        app.buttons["typed-word-form-past"].tap()
        XCTAssertEqual(editor.value as? String, "went home")
    }

    @MainActor
    func testEmojiInputOffersWordAndKeepChoicesInBothKeyboards() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        editor.tap()
        editor.typeText("🛸")
        let ufo = app.buttons["emoji-word-ufo"]
        XCTAssertTrue(ufo.waitForExistence(timeout: 5))
        ufo.tap()
        XCTAssertEqual(editor.value as? String, "UFO ")

        clear.tap()
        editor.tap()
        editor.typeText("🛸")
        app.buttons["open-alphabet-keyboard"].tap()
        XCTAssertTrue(app.buttons["alphabet-emoji-word-ufo"].waitForExistence(timeout: 5))
        app.buttons["alphabet-emoji-keep"].tap()
        XCTAssertEqual(app.staticTexts["alphabet-message"].label, "🛸 ")
    }

    @MainActor
    func testQuickRepliesStayAvailableAcrossTabsAndTyping() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()

        app.buttons["Phrases"].firstMatch.tap()
        let yes = app.buttons["quick-response-yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5))
        let repliesScreenshot = XCTAttachment(screenshot: app.screenshot())
        repliesScreenshot.name = "Quick replies on Phrases"
        repliesScreenshot.lifetime = .keepAlways
        add(repliesScreenshot)
        yes.tap()

        app.buttons["Settings"].firstMatch.tap()
        app.buttons["quick-response-no"].tap()

        app.buttons["Speak"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: yes no"].waitForExistence(timeout: 5))
        app.buttons["Keyboard"].tap()
        app.buttons["quick-response-help"].tap()
        app.buttons["Pictures"].tap()
        XCTAssertTrue(app.staticTexts["Message: yes no help"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCustomQuickReplyCanBeSavedAndSpoken() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Settings"].firstMatch.tap()
        let editReplies = app.buttons["edit-quick-replies"]
        for _ in 0..<8 where !editReplies.isHittable { app.swipeUp() }
        XCTAssertTrue(editReplies.isHittable)
        editReplies.tap()
        XCTAssertTrue(app.navigationBars["Quick replies"].waitForExistence(timeout: 5))

        let reset = app.buttons["Use starter replies"]
        for _ in 0..<8 where !reset.isHittable { app.swipeUp() }
        XCTAssertTrue(reset.isHittable)
        reset.tap()
        let addReply = app.buttons["add-quick-reply"]
        for _ in 0..<8 where !addReply.isHittable { app.swipeUp() }
        XCTAssertTrue(addReply.isHittable)
        addReply.tap()
        let englishFields = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-reply-english-"))
        let english = englishFields.element(boundBy: englishFields.count - 1)
        for _ in 0..<6 where !english.isHittable { app.swipeUp() }
        let phrase = "I need a break \(UUID().uuidString.prefix(4))"
        english.tap()
        english.typeText(phrase)
        let spanishFields = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-reply-spanish-"))
        let spanish = spanishFields.element(boundBy: spanishFields.count - 1)
        spanish.tap()
        spanish.typeText("Necesito un descanso")
        let voiceID = english.identifier.replacingOccurrences(of: "quick-reply-english-", with: "quick-reply-voice-")
        let voice = app.buttons[voiceID]
        for _ in 0..<6 where !voice.isHittable { app.swipeUp() }
        XCTAssertTrue(voice.isHittable)
        voice.tap()
        XCTAssertTrue(app.navigationBars["Quick reply voice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quick-reply-record-toggle"].exists)
        XCTAssertTrue(app.buttons["Import audio from Files"].exists)
        let voiceScreenshot = XCTAttachment(screenshot: app.screenshot())
        voiceScreenshot.name = "Quick reply voice editor"
        voiceScreenshot.lifetime = .keepAlways
        add(voiceScreenshot)
        app.navigationBars["Quick reply voice"].buttons["Cancel"].tap()
        app.navigationBars["Quick replies"].buttons["Save"].tap()

        let custom = app.buttons["quick-response-\(phrase)"]
        let lastStarter = app.buttons["quick-response-break"]
        if !custom.isHittable { lastStarter.swipeLeft() }
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        XCTAssertTrue(custom.isHittable)
        let barScreenshot = XCTAttachment(screenshot: app.screenshot())
        barScreenshot.name = "Edited quick reply bar"
        barScreenshot.lifetime = .keepAlways
        add(barScreenshot)
        custom.tap()
        app.buttons["Speak"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: \(phrase)"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Custom quick reply"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSpeakOnlyQuickReplyKeepsPictureAndTypedDrafts() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let editReplies = app.buttons["edit-quick-replies"]
        for _ in 0..<8 where !editReplies.isHittable { app.swipeUp() }
        XCTAssertTrue(editReplies.isHittable)
        editReplies.tap()
        let reset = app.buttons["Use starter replies"]
        for _ in 0..<8 where !reset.isHittable { app.swipeUp() }
        reset.tap()
        let addReply = app.buttons["add-quick-reply"]
        for _ in 0..<8 where !addReply.isHittable { app.swipeUp() }
        addReply.tap()
        let englishFields = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-reply-english-"))
        let english = englishFields.element(boundBy: englishFields.count - 1)
        for _ in 0..<6 where !english.isHittable { app.swipeUp() }
        let phrase = "Please wait \(UUID().uuidString.prefix(4))"
        english.tap()
        english.typeText(phrase)
        let actionID = english.identifier.replacingOccurrences(of: "quick-reply-english-",
                                                                with: "quick-reply-action-")
        let action = app.descendants(matching: .any)[actionID].firstMatch
        for _ in 0..<6 where !action.isHittable { app.swipeUp() }
        XCTAssertTrue(action.isHittable)
        action.tap()
        app.buttons["Speak only"].tap()
        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "Speak-only quick reply setting"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)
        app.navigationBars["Quick replies"].buttons["Save"].tap()

        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clearPicture = app.buttons["Clear message"]
        if clearPicture.isEnabled { clearPicture.tap() }
        app.buttons["Core"].tap()
        app.buttons["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))
        app.buttons["Keyboard"].tap()
        let clearTyped = app.buttons["Clear"]
        if clearTyped.isEnabled { clearTyped.tap() }
        let typed = app.textViews["Type a message"]
        typed.tap()
        typed.typeText("I am writing")
        let draftBeforeReply = typed.value as? String
        XCTAssertFalse(draftBeforeReply?.isEmpty ?? true)

        let reply = app.buttons["quick-response-\(phrase)"]
        if !reply.isHittable { app.buttons["quick-response-break"].swipeLeft() }
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        XCTAssertTrue(reply.isHittable)
        reply.tap()
        let confirm = app.buttons["Speak now"]
        if confirm.exists { confirm.tap() }
        XCTAssertEqual(typed.value as? String, draftBeforeReply)
        app.buttons["Pictures"].tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCardPhraseChoiceSpeaksIntoMessageAndKeepsBaseWord() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Switch profile"].tap()
        app.buttons["Add profile"].tap()
        let alert = app.alerts["New profile"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields["Profile name"].tap()
        alert.textFields["Profile name"].typeText("Card phrases \(UUID().uuidString.prefix(6))")
        alert.buttons["Create"].tap()
        app.navigationBars["Profiles"].buttons["Done"].tap()

        let card = app.buttons["different"].firstMatch
        let wordGrid = app.scrollViews.element(boundBy: 1)
        for _ in 0..<5 where !card.isHittable { wordGrid.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["card-word-choice"].waitForExistence(timeout: 5))
        let choicesScreenshot = XCTAttachment(screenshot: app.screenshot())
        choicesScreenshot.name = "Card phrase choices"
        choicesScreenshot.lifetime = .keepAlways
        add(choicesScreenshot)
        app.buttons["card-phrase-choice-1"].tap()
        XCTAssertTrue(app.staticTexts["Message: I want something different."].waitForExistence(timeout: 5))

        card.tap()
        app.buttons["card-word-choice"].tap()
        XCTAssertTrue(app.staticTexts["Message: I want something different. different"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCardPhraseCanBeEditedOnAPersonalButton() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let label = "Phrase \(UUID().uuidString.prefix(6))"
        let labelField = app.textFields["Button label"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 5))
        labelField.tap()
        labelField.typeText(label)
        app.buttons["Add phrase"].tap()
        let phraseField = app.textFields["Phrase"]
        XCTAssertTrue(phraseField.waitForExistence(timeout: 5))
        phraseField.tap()
        phraseField.typeText("Please make a plan.")
        let spanishField = app.textFields["Spanish phrase (optional)"]
        spanishField.tap()
        spanishField.typeText("Hagamos un plan.")
        app.navigationBars["Add button"].buttons["Save"].tap()

        let card = app.buttons[label]
        for _ in 0..<5 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["card-phrase-choice-1"].waitForExistence(timeout: 5))
        app.buttons["card-phrase-choice-1"].tap()
        XCTAssertTrue(app.staticTexts["Message: Please make a plan."].waitForExistence(timeout: 5))

        app.buttons["Clear message"].tap()
        app.buttons["board-language"].tap()
        app.buttons["Español"].tap()
        card.tap()
        app.buttons["card-phrase-choice-1"].tap()
        XCTAssertTrue(app.staticTexts["Message: Hagamos un plan."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDrawingBoardCanDrawAndShowPartner() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Drawing board"].tap()
        let canvas = app.otherElements["drawing-canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        if app.buttons["Clear"].isEnabled {
            app.buttons["Clear"].tap()
            app.buttons["Clear drawing"].tap()
        }
        XCTAssertFalse(app.buttons["show-drawing"].isEnabled)
        XCTAssertFalse(app.buttons["read-drawing-writing"].isEnabled)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8)))
        XCTAssertEqual(canvas.label, "Drawing canvas, 1 marks")
        XCTAssertTrue(app.buttons["show-drawing"].isEnabled)
        XCTAssertTrue(app.buttons["read-drawing-writing"].isEnabled)
        let drawingScreenshot = XCTAttachment(screenshot: app.screenshot())
        drawingScreenshot.name = "Drawing board after a stroke"
        drawingScreenshot.lifetime = .keepAlways
        add(drawingScreenshot)
        app.buttons["show-drawing"].tap()
        XCTAssertTrue(app.otherElements["large-drawing"].waitForExistence(timeout: 5))
        let flip = app.buttons["flip-drawing"]
        XCTAssertEqual(flip.label, "Face partner")
        flip.tap()
        XCTAssertEqual(flip.label, "Face me")
        app.navigationBars["Show drawing"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        app.buttons["Undo"].tap()
        XCTAssertFalse(app.buttons["show-drawing"].isEnabled)
        app.buttons["Redo"].tap()
        XCTAssertTrue(app.buttons["show-drawing"].isEnabled)
        app.navigationBars["Drawing board"].buttons["Done"].tap()

        app.terminate()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Drawing board"].tap()
        XCTAssertTrue(app.buttons["show-drawing"].isEnabled)
    }

    @MainActor
    func testDrawingWritingCanBeReviewedAndAddedToMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Drawing board"].tap()
        let canvas = app.otherElements["drawing-canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        if app.buttons["Clear"].isEnabled {
            app.buttons["Clear"].tap()
            app.buttons["Clear drawing"].tap()
        }
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: x1, dy: y1))
                .press(forDuration: 0.05, thenDragTo: canvas.coordinate(
                    withNormalizedOffset: CGVector(dx: x2, dy: y2)))
        }
        line(0.18, 0.23, 0.18, 0.77)
        line(0.18, 0.50, 0.40, 0.50)
        line(0.40, 0.23, 0.40, 0.77)
        line(0.58, 0.23, 0.82, 0.23)
        line(0.70, 0.23, 0.70, 0.77)
        line(0.58, 0.77, 0.82, 0.77)
        app.buttons["read-drawing-writing"].tap()
        XCTAssertTrue(app.navigationBars["Review writing"].waitForExistence(timeout: 15))
        let text = app.descendants(matching: .any)["recognized-drawing-text"]
        XCTAssertTrue(text.exists)
        text.tap()
        text.typeText("HI")
        XCTAssertTrue(app.buttons["speak-drawing-text"].isEnabled)
        app.buttons["add-drawing-text"].tap()
        XCTAssertTrue(app.staticTexts["drawing-recognition-feedback"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSpeechToPicturesReviewsTextAndAddsVisualMessage() {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Clear message"].isEnabled { app.buttons["Clear message"].tap() }
        app.buttons["Customize"].tap()
        app.buttons["Speech to pictures"].tap()
        XCTAssertTrue(app.navigationBars["Speech to pictures"].waitForExistence(timeout: 5))
        let transcript = app.descendants(matching: .any)["visual-message-transcript"]
        transcript.tap()
        transcript.typeText("water xylophonezz")
        XCTAssertTrue(app.otherElements["visual-message-preview"].exists)
        app.buttons["visual-message-part-0"].tap()
        XCTAssertTrue(app.navigationBars["Choose picture"].waitForExistence(timeout: 5))
        let pictureSearch = app.searchFields["Find a picture button"]
        pictureSearch.tap()
        pictureSearch.typeText("help")
        app.buttons["Use help picture"].firstMatch.tap()
        XCTAssertEqual(app.buttons["visual-message-part-0"].value as? String, "Picture from help")
        app.buttons["visual-message-add"].tap()
        XCTAssertTrue(app.staticTexts["Message: water xylophonezz"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFocusHighlightsTargetsWithoutHidingOtherWords() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["open-focus"].tap()
        let word = app.buttons["Focus word I"]
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        if String(describing: word.value ?? "") != "Selected" { word.tap() }
        XCTAssertEqual(word.value as? String, "Selected")
        app.buttons["start-focus"].tap()

        let focused = app.buttons["I"].firstMatch
        XCTAssertEqual(focused.value as? String, "Focus word")
        XCTAssertTrue(app.buttons["want"].exists)
        XCTAssertEqual(app.buttons["Core"].value as? String, "Contains focus words")
        app.buttons["Needs"].tap()
        XCTAssertTrue(app.buttons["water"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["end-focus"].exists)

        app.terminate()
        app.launch()
        XCTAssertNotEqual(app.buttons["I"].firstMatch.value as? String, "Focus word")
        app.buttons["open-focus"].tap()
        XCTAssertEqual(app.buttons["Focus word I"].value as? String, "Selected")
    }

    @MainActor
    func testPracticeTogetherKeepsCommunicationAvailableAcrossTurns() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["open-practice"].tap()
        app.buttons["practice-topic-talkAboutInterests"].tap()
        XCTAssertTrue(app.staticTexts["Show something you like."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Yes"].firstMatch.exists)
        app.buttons["practice-switch-turn"].tap()
        XCTAssertTrue(app.staticTexts["Say what you like or do not like."].waitForExistence(timeout: 5))
        app.buttons["practice-next-idea"].tap()
        XCTAssertTrue(app.staticTexts["Comment on something you notice."].waitForExistence(timeout: 5))
        app.buttons["I"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: I"].waitForExistence(timeout: 5))
        let practiceScreenshot = XCTAttachment(screenshot: app.screenshot())
        practiceScreenshot.name = "Practice together on Speak"
        practiceScreenshot.lifetime = .keepAlways
        add(practiceScreenshot)
        app.buttons["Keyboard"].tap()
        XCTAssertTrue(app.staticTexts["Comment on something you notice."].exists)
        app.buttons["Pictures"].tap()
        XCTAssertTrue(app.buttons["Yes"].firstMatch.exists)
        app.buttons["practice-end"].tap()
        XCTAssertFalse(app.staticTexts["Comment on something you notice."].exists)
        XCTAssertTrue(app.staticTexts["Message: I"].exists)
        XCTAssertTrue(app.buttons["Yes"].firstMatch.exists)
    }

    @MainActor
    func testContextualBoardHintsHighlightWordsInPlace() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        let toggle = app.buttons["board-suggestion-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.label == "Hints" { toggle.tap() }

        app.buttons["I"].firstMatch.tap()
        let want = app.buttons["want"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        XCTAssertEqual(want.value as? String, "Suggested next")
        let highlightedScreenshot = XCTAttachment(screenshot: app.screenshot())
        highlightedScreenshot.name = "Picture board next-word hints"
        highlightedScreenshot.lifetime = .keepAlways
        add(highlightedScreenshot)
        let position = want.frame.origin
        toggle.tap()
        XCTAssertEqual(want.value as? String, "")
        XCTAssertEqual(want.frame.origin.x, position.x, accuracy: 1)
        XCTAssertEqual(want.frame.origin.y, position.y, accuracy: 1)
    }

    @MainActor
    func testConversationsKeepPictureAndTypedDraftsSeparate() {
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["open-conversations"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Keyboard"].tap()
        let clearTyped = app.buttons["Clear"]
        if clearTyped.isEnabled { clearTyped.tap() }
        app.buttons["Pictures"].tap()
        app.buttons["I"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: I"].waitForExistence(timeout: 5))

        open.tap()
        app.buttons["add-conversation"].tap()
        let name = "Reply \(UUID().uuidString.prefix(6))"
        let alert = app.alerts["New conversation"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields["Conversation name"].tap()
        alert.textFields["Conversation name"].typeText(name)
        alert.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Message: empty"].waitForExistence(timeout: 5))

        app.buttons["Keyboard"].tap()
        let editor = app.textViews["Type a message"]
        editor.tap()
        editor.typeText("A different answer")
        app.buttons["open-conversations"].firstMatch.tap()
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Use conversation ")).element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertEqual(editor.value as? String, "")
        app.buttons["Pictures"].tap()
        XCTAssertTrue(app.staticTexts["Message: I"].waitForExistence(timeout: 5))

        open.tap()
        app.buttons["Use conversation \(name)"].tap()
        app.buttons["Keyboard"].tap()
        XCTAssertEqual(app.textViews["Type a message"].value as? String, "A different answer")
    }

    @MainActor
    func testLargeMessageCanFacePartner() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["I"].firstMatch.tap()
        app.buttons["More"].tap()
        app.buttons["Show large message"].tap()
        XCTAssertTrue(app.staticTexts["large-message"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["picture-message-visual"].exists)
        XCTAssertTrue(app.buttons["share-picture-message"].waitForExistence(timeout: 5))
        let pictureScreen = XCTAttachment(screenshot: app.screenshot())
        pictureScreen.name = "Visual picture message"
        pictureScreen.lifetime = .keepAlways
        add(pictureScreen)
        let flip = app.buttons["flip-message"]
        XCTAssertEqual(flip.label, "Face partner")
        flip.tap()
        XCTAssertEqual(flip.label, "Face me")
        XCTAssertEqual(app.staticTexts["large-message"].label, "I")
    }

    @MainActor
    func testPictureMessagePDFPreviewOffersShareSaveAndPrint() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["I"].firstMatch.tap()
        app.buttons["More"].tap()
        app.buttons["Show large message"].tap()
        app.buttons["picture-message-pdf"].tap()
        XCTAssertTrue(app.navigationBars["Picture PDF"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["share-pdf"].exists)
        XCTAssertTrue(app.buttons["Save PDF"].exists)
        XCTAssertTrue(app.buttons["Print"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Picture message PDF preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPictureMessageAudioOpensShareSheet() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["I"].firstMatch.tap()
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["share-picture-audio"].waitForExistence(timeout: 5))
        app.buttons["Show large message"].tap()
        let shareAudio = app.buttons["share-large-message-audio"]
        XCTAssertTrue(shareAudio.waitForExistence(timeout: 5))
        shareAudio.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 20))
        let pictureScreenshot = XCTAttachment(screenshot: app.screenshot())
        pictureScreenshot.name = "Picture message audio share"
        pictureScreenshot.lifetime = .keepAlways
        add(pictureScreenshot)
    }

    @MainActor
    func testTypedMessageOffersAudioSharing() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let typed = app.textViews["Type a message"]
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        typed.tap()
        typed.typeText("I need a moment")
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["share-typed-audio"].waitForExistence(timeout: 5))
        app.buttons["share-typed-audio"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 20))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Typed message audio share"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testNearbyChatCanStartAndShowPictureDraft() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["I"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Nearby chat"].tap()
        XCTAssertTrue(app.navigationBars["Nearby chat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nearby-send-picture"].exists)
        XCTAssertFalse(app.buttons["nearby-send-picture"].isEnabled)
        app.buttons["nearby-start-stop"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.waitForExistence(timeout: 2) {
            let allow = springboard.alerts.buttons["Allow"]
            if allow.exists { allow.tap() }
        }
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 8))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Nearby chat discovery"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["nearby-start-stop"].tap()
        XCTAssertTrue(app.buttons["Start"].exists)
    }

    @MainActor
    func testCallAudioSetupIsAvailableFromSpeakAndSettings() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Call audio"].tap()
        XCTAssertTrue(app.navigationBars["Call audio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Status"].exists)
        XCTAssertTrue(app.buttons["call-audio-toggle"].exists
                      || app.buttons["call-audio-request"].exists
                      || app.buttons["call-audio-system-settings"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Call audio setup"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Done"].tap()
        app.buttons["Settings"].firstMatch.tap()
        let link = app.buttons["call-audio-link"]
        for _ in 0..<10 where !link.isHittable { app.swipeUp() }
        XCTAssertTrue(link.isHittable)
        link.tap()
        XCTAssertTrue(app.navigationBars["Call audio"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAttentionAlertOpensFromPicturesAndKeyboard() {
        let app = XCUIApplication()
        app.launch()
        let attention = app.buttons["get-attention"]
        XCTAssertTrue(attention.waitForExistence(timeout: 10))
        attention.tap()
        XCTAssertTrue(app.staticTexts["attention-message"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["attention-message"].label,
                       "Excuse me. I have something to say.")
        XCTAssertTrue(app.buttons["repeat-attention"].exists)
        let alertScreenshot = XCTAttachment(screenshot: app.screenshot())
        alertScreenshot.name = "Attention alert"
        alertScreenshot.lifetime = .keepAlways
        add(alertScreenshot)
        app.buttons["repeat-attention"].tap()
        app.buttons["Done"].tap()

        app.buttons["Keyboard"].tap()
        XCTAssertTrue(attention.waitForExistence(timeout: 5))
        attention.tap()
        XCTAssertTrue(app.staticTexts["attention-message"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testScannerCanOpenAttentionAlertWithAnEmptyMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let scanSwitch = app.switches["Scan the communication board"]
        for _ in 0..<4 where !scanSwitch.exists { app.swipeUp() }
        XCTAssertTrue(scanSwitch.waitForExistence(timeout: 5))
        if String(describing: scanSwitch.value ?? "") != "1" {
            scanSwitch.switches.firstMatch.tap()
        }
        app.buttons.matching(identifier: "quote.bubble.fill").firstMatch.tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        XCTAssertTrue(app.staticTexts["Message: empty"].waitForExistence(timeout: 5))
        app.buttons["scan-pause"].tap()
        let target = app.staticTexts["scan-target"]
        for _ in 0..<50 where target.label != "Message controls" { app.buttons["scan-next"].tap() }
        XCTAssertEqual(target.label, "Message controls")
        app.buttons["scan-select"].tap()
        for _ in 0..<5 where target.label != "Get attention" { app.buttons["scan-next"].tap() }
        XCTAssertEqual(target.label, "Get attention")
        Thread.sleep(forTimeInterval: 0.4)
        app.buttons["scan-select"].tap()
        XCTAssertTrue(app.staticTexts["attention-message"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<4 where !scanSwitch.exists { app.swipeUp() }
        scanSwitch.switches.firstMatch.tap()
    }

    @MainActor
    func testOptInFeelingsLogCanSaveAndReviewCheckIn() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let saveLog = app.switches["Keep a private feelings log"]
        for _ in 0..<20 where !saveLog.exists { app.swipeUp() }
        XCTAssertTrue(saveLog.waitForExistence(timeout: 5))
        let initialValue = String(describing: saveLog.value ?? "").lowercased()
        if ["0", "off", "false"].contains(initialValue) { saveLog.switches.firstMatch.tap() }
        let enabledValue = String(describing: saveLog.value ?? "").lowercased()
        XCTAssertTrue(["1", "on", "true"].contains(enabledValue), "Unexpected feelings-log switch value: \(enabledValue)")

        app.buttons["Phrases"].firstMatch.tap()
        let feelingLink = app.buttons["feeling-check-in-link"]
        for _ in 0..<16 where !feelingLink.isHittable { app.swipeUp() }
        XCTAssertTrue(feelingLink.isHittable)
        feelingLink.tap()
        app.buttons["happy"].tap()
        let saveCheckIn = app.buttons["save-feeling-entry"]
        for _ in 0..<4 where !saveCheckIn.exists { app.swipeUp() }
        XCTAssertTrue(saveCheckIn.waitForExistence(timeout: 5))
        XCTAssertTrue(saveCheckIn.isEnabled)
        saveCheckIn.tap()
        XCTAssertTrue(app.staticTexts["Saved to your private feelings log"].waitForExistence(timeout: 5))
        app.buttons["Review saved check-ins"].tap()
        XCTAssertTrue(app.navigationBars["Feelings log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share shown check-ins"].exists)
    }

    @MainActor
    func testFeelingStepScanBuildsSpeaksAndSavesCheckIn() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-feeling-scan"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-feeling-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["Phrases"].firstMatch.tap()
        let feelingLink = app.buttons["feeling-check-in-link"]
        for _ in 0..<16 where !feelingLink.isHittable { app.swipeUp() }
        XCTAssertTrue(feelingLink.isHittable)
        feelingLink.tap()
        let target = app.staticTexts["feeling-scan-target"]
        let next = app.buttons["feeling-scan-next"]
        let select = app.buttons["feeling-scan-select"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Tell someone about pain")
        for _ in 0..<20 where target.label != "happy" { next.tap() }
        XCTAssertEqual(target.label, "happy")
        select.tap()
        XCTAssertEqual(target.label, "Strength 3 out of 5")
        next.tap()
        XCTAssertEqual(target.label, "Strength 4 out of 5")
        select.tap()
        XCTAssertEqual(target.label, "Please give me space.")
        select.tap()
        XCTAssertEqual(target.label, "Speak")
        XCTAssertTrue(app.staticTexts["I feel happy. It is a 4 out of 5. Please give me space."].exists)
        select.tap()
        next.tap()
        XCTAssertEqual(target.label, "Share")
        next.tap()
        XCTAssertEqual(target.label, "Save phrase")
        next.tap()
        XCTAssertEqual(target.label, "Save check-in")
        select.tap()
        XCTAssertTrue(app.staticTexts["Saved to your private feelings log"].waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Review saved check-ins")
        select.tap()
        XCTAssertTrue(app.navigationBars["Feelings log"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeelingScanCanOpenPainCheckIn() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-feeling-scan"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-feeling-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["Phrases"].firstMatch.tap()
        let feelingLink = app.buttons["feeling-check-in-link"]
        for _ in 0..<16 where !feelingLink.isHittable { app.swipeUp() }
        XCTAssertTrue(feelingLink.isHittable)
        feelingLink.tap()
        XCTAssertEqual(app.staticTexts["feeling-scan-target"].label, "Tell someone about pain")
        app.buttons["feeling-scan-select"].tap()
        XCTAssertTrue(app.navigationBars["Pain check-in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["pain-scan-target"].waitForExistence(timeout: 5))
        app.navigationBars["Pain check-in"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["How I feel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["feeling-scan-target"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeelingScanCanShareSelectedMessage() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-feeling-scan"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-feeling-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["Phrases"].firstMatch.tap()
        let feelingLink = app.buttons["feeling-check-in-link"]
        for _ in 0..<16 where !feelingLink.isHittable { app.swipeUp() }
        XCTAssertTrue(feelingLink.isHittable)
        feelingLink.tap()
        let target = app.staticTexts["feeling-scan-target"]
        let next = app.buttons["feeling-scan-next"]
        let select = app.buttons["feeling-scan-select"]
        for _ in 0..<20 where target.label != "happy" { next.tap() }
        select.tap()
        let strength = target.label
        XCTAssertTrue(strength.contains("Strength"))
        select.tap()
        select.tap()
        XCTAssertEqual(target.label, "Speak")
        next.tap()
        XCTAssertEqual(target.label, "Share")
        select.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testFeelingAutoScanCanPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-feeling-scan-auto"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-feeling-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["Phrases"].firstMatch.tap()
        let feelingLink = app.buttons["feeling-check-in-link"]
        for _ in 0..<16 where !feelingLink.isHittable { app.swipeUp() }
        XCTAssertTrue(feelingLink.isHittable)
        feelingLink.tap()
        let target = app.staticTexts["feeling-scan-target"]
        let pause = app.buttons["feeling-scan-pause"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        pause.tap()
        let held = target.label
        Thread.sleep(forTimeInterval: 3.5)
        XCTAssertEqual(target.label, held)
        pause.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", held), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 6), .completed)
    }

    @MainActor
    func testSpanishFeelingCheckInSpeaksTheSelectedLanguage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let languagePicker = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Communication language")
        ).firstMatch
        for _ in 0..<12 where !languagePicker.isHittable { app.swipeUp() }
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 5))
        languagePicker.tap()
        app.buttons["Español"].tap()

        app.buttons["Phrases"].firstMatch.tap()
        let feelingLink = app.buttons["feeling-check-in-link"]
        for _ in 0..<16 where !feelingLink.isHittable { app.swipeUp() }
        XCTAssertTrue(feelingLink.isHittable)
        feelingLink.tap()
        let feeling = app.buttons["feliz"]
        XCTAssertTrue(feeling.waitForExistence(timeout: 5))
        feeling.tap()
        XCTAssertTrue(app.staticTexts["Me siento feliz. Intensidad 3 de 5."].waitForExistence(timeout: 5))
        app.buttons["Necesito ayuda."].tap()
        XCTAssertTrue(app.staticTexts["Me siento feliz. Intensidad 3 de 5. Necesito ayuda."].waitForExistence(timeout: 5))

        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<12 where !languagePicker.isHittable { app.swipeUp() }
        languagePicker.tap()
        app.buttons["English"].tap()
    }

    @MainActor
    func testWeeklyPlanActivityCanSpeakAndBeMarkedDone() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-weekly-plan"].tap()
        XCTAssertTrue(app.navigationBars["Weekly plan"].waitForExistence(timeout: 5))
        app.buttons["add-weekly-activity"].tap()
        XCTAssertTrue(app.navigationBars["New activity"].waitForExistence(timeout: 5))
        let name = "Weekly test \(UUID().uuidString.prefix(6))"
        let field = app.textFields["weekly-activity-title"]
        field.tap()
        field.typeText(name)
        app.buttons["save-weekly-activity"].tap()
        let say = app.buttons["Say \(name)"]
        XCTAssertTrue(say.waitForExistence(timeout: 5))
        say.tap()
        let done = app.buttons["Mark done: \(name)"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons["Mark not done: \(name)"].waitForExistence(timeout: 5))
        app.buttons["Speak"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: \(name)"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWeeklyTemplateCanBeSavedAndApplied() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Routine"].firstMatch.tap()
        app.buttons["open-weekly-plan"].tap()
        app.buttons["add-weekly-activity"].tap()
        let activityName = "Template step \(UUID().uuidString.prefix(6))"
        let field = app.textFields["weekly-activity-title"]
        field.tap()
        field.typeText(activityName)
        app.buttons["save-weekly-activity"].tap()
        XCTAssertTrue(app.buttons["Say \(activityName)"].waitForExistence(timeout: 5))

        let saveTemplate = app.buttons["save-weekly-template"]
        for _ in 0..<5 where !saveTemplate.exists { app.swipeUp() }
        XCTAssertTrue(saveTemplate.waitForExistence(timeout: 5))
        saveTemplate.tap()
        let alert = app.alerts["Save day template"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let nameField = alert.textFields["Template name"]
        nameField.tap()
        nameField.typeText(" \(UUID().uuidString.prefix(6))")
        let templateName = nameField.value as? String ?? ""
        alert.buttons["Save"].tap()

        let nextWeekday = Calendar.current.component(.weekday, from: Date()) % 7 + 1
        let nextDay = app.buttons["weekly-day-\(nextWeekday)"]
        for _ in 0..<5 where !nextDay.exists { app.swipeDown() }
        XCTAssertTrue(nextDay.waitForExistence(timeout: 5))
        nextDay.tap()
        let useTemplate = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Use \(templateName) on")
        ).firstMatch
        for _ in 0..<5 where !useTemplate.exists { app.swipeUp() }
        XCTAssertTrue(useTemplate.waitForExistence(timeout: 5))
        useTemplate.tap()
        app.buttons["Replace activities"].tap()
        XCTAssertTrue(app.buttons["Say \(activityName)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mark done: \(activityName)"].exists)
    }

    @MainActor
    func testScenesGalleryAndEditorOpen() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["open-scenes"].tap()
        XCTAssertTrue(app.navigationBars["Scenes"].waitForExistence(timeout: 5))
        app.buttons["create-scene"].tap()
        XCTAssertTrue(app.navigationBars["New scene"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Choose or change photo"].exists)
        XCTAssertTrue(app.buttons["scene-import-photo-file"].exists)
        XCTAssertTrue(app.buttons["add-scene-word"].exists)
        XCTAssertFalse(app.buttons["save-scene"].isEnabled)
        app.buttons["Cancel"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["import-scene-file"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSceneShowsWrittenWordWhenHotspotIsTapped() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-scene-literacy")
        app.launch()
        app.buttons["open-scenes"].tap()
        app.buttons["Options for Literacy scene"].tap()
        XCTAssertTrue(app.buttons["Export scene file"].exists)
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit scene"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.buttons["create-scene"].tap()
        XCTAssertTrue(app.navigationBars["New scene"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        let scene = app.buttons["Open Literacy scene scene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 5))
        scene.tap()
        XCTAssertTrue(app.navigationBars["Literacy scene"].waitForExistence(timeout: 5))
        let showOnTap = app.buttons["scene-label-onTap"]
        XCTAssertTrue(showOnTap.waitForExistence(timeout: 5))
        showOnTap.tap()
        XCTAssertEqual(showOnTap.value as? String, "Selected")
        app.buttons["books"].tap()
        XCTAssertEqual(showOnTap.value as? String, "Selected")
        let cue = app.staticTexts["scene-literacy-word"]
        XCTAssertTrue(cue.waitForExistence(timeout: 2))
        XCTAssertEqual(cue.label, "books")
        XCTAssertTrue(app.staticTexts["scene-selected-word"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Scene word cue"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: cue
        )], timeout: 7), .completed)
    }

    @MainActor
    func testLinkedSceneOpensAndReturnsWithoutAddingAWord() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-linked-scenes")
        app.launch()
        app.buttons["open-scenes"].tap()
        app.swipeUp()
        let home = app.buttons["Open Linked test home scene"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.tap()
        XCTAssertTrue(app.navigationBars["Linked test home"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["scene-selected-word"].exists)
        app.buttons["Open Linked test garden from garden"].tap()
        XCTAssertTrue(app.navigationBars["Linked test garden"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["scene-selected-word"].exists)
        app.buttons["scene-back"].tap()
        XCTAssertTrue(app.navigationBars["Linked test home"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSceneStepScanSpeaksAndNavigatesLinkedScenes() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-scene-scan"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-scene-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["open-scenes"].tap()
        let home = app.buttons["Open Scan test home scene"]
        for _ in 0..<8 where !home.isHittable { app.swipeUp() }
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.tap()

        let target = app.staticTexts["scene-scan-target"]
        let next = app.buttons["scene-scan-next"]
        let select = app.buttons["scene-scan-select"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "hello")
        select.tap()
        XCTAssertTrue(app.staticTexts["scene-selected-word"].waitForExistence(timeout: 5))
        next.tap()
        XCTAssertEqual(target.label, "Open Scan test garden from garden")
        select.tap()
        XCTAssertTrue(app.navigationBars["Scan test garden"].waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "flowers")
        select.tap()
        next.tap()
        XCTAssertEqual(target.label, "Always visible")
        next.tap()
        XCTAssertEqual(target.label, "Show on tap")
        select.tap()
        XCTAssertEqual(app.buttons["scene-label-onTap"].value as? String, "Selected")
        next.tap()
        XCTAssertEqual(target.label, "Back to previous scene")
        select.tap()
        XCTAssertTrue(app.navigationBars["Scan test home"].waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "hello")
        for _ in 0..<4 { next.tap() }
        XCTAssertEqual(target.label, "Speak message")
        select.tap()
        next.tap()
        XCTAssertEqual(target.label, "Back to full Speak board")
        next.tap()
        XCTAssertEqual(target.label, "Done")
        select.tap()
        XCTAssertTrue(app.buttons["Open Scan test home scene"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSceneAutoScanCanPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-scene-scan-auto"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-scene-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["open-scenes"].tap()
        let home = app.buttons["Open Scan test home scene"]
        for _ in 0..<8 where !home.isHittable { app.swipeUp() }
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.tap()
        let target = app.staticTexts["scene-scan-target"]
        let pause = app.buttons["scene-scan-pause"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        pause.tap()
        let held = target.label
        Thread.sleep(forTimeInterval: 3.5)
        XCTAssertEqual(target.label, held)
        pause.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", held), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 6), .completed)
    }

    @MainActor
    func testSceneScanReachesVideoPlaybackControls() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-scene-scan"]
        app.launch()
        defer {
            app.terminate()
            let cleanup = XCUIApplication()
            cleanup.launchArguments += ["-ui-test-scene-scan-cleanup"]
            cleanup.launch()
            cleanup.terminate()
        }
        app.buttons["open-scenes"].tap()
        let video = app.buttons["Open Scan test video scene"]
        for _ in 0..<10 where !video.isHittable { app.swipeUp() }
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        video.tap()
        let target = app.staticTexts["scene-scan-target"]
        let next = app.buttons["scene-scan-next"]
        let select = app.buttons["scene-scan-select"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "play")
        next.tap()
        next.tap()
        next.tap()
        XCTAssertEqual(target.label, "Play scene video")
        select.tap()
        XCTAssertEqual(target.label, "Pause scene video")
        next.tap()
        XCTAssertEqual(target.label, "Replay scene video")
        select.tap()
        next.tap()
        XCTAssertEqual(target.label, "Back to full Speak board")
    }

    @MainActor
    func testSceneEditorCanSwitchAWordBetweenSpeechAndLinkedScene() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-linked-scenes")
        app.launch()
        app.buttons["open-scenes"].tap()
        app.swipeUp()
        app.buttons["Options for Linked test home"].tap()
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit scene"].waitForExistence(timeout: 5))
        app.swipeUp()
        let action = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "scene-action-"
        )).firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
        app.buttons["Say this word"].tap()
        XCTAssertTrue(action.label.contains("Says this word"))
        action.tap()
        app.buttons["Open Linked test garden"].tap()
        XCTAssertTrue(action.label.contains("Opens Linked test garden"))
        app.buttons["save-scene"].tap()
        app.buttons["Open Linked test home scene"].tap()
        app.buttons["Open Linked test garden from garden"].tap()
        XCTAssertTrue(app.navigationBars["Linked test garden"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCustomizedSceneHotspotsOfferControlsAndRespectIndependentActions() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-scene-hotspots")
        app.launch()
        app.buttons["open-scenes"].tap()
        app.swipeUp()
        app.buttons["Options for Hotspot test scene"].tap()
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit scene"].waitForExistence(timeout: 5))
        app.swipeUp()
        let customize = app.buttons["Customize write"]
        XCTAssertTrue(customize.waitForExistence(timeout: 5))
        customize.tap()
        app.swipeUp()
        XCTAssertTrue(app.sliders.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene-width-")).firstMatch.exists)
        XCTAssertTrue(app.sliders.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene-height-")).firstMatch.exists)
        XCTAssertTrue(app.switches.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene-show-label-")).firstMatch.exists)
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene-spoken-text-")).firstMatch.exists)
        app.buttons["Cancel"].tap()

        let open = app.buttons["Open Hotspot test scene scene"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.buttons["talk"].waitForExistence(timeout: 5))
        app.buttons["talk"].tap()
        XCTAssertFalse(app.staticTexts["Hello there"].exists)
        app.buttons["write"].tap()
        XCTAssertTrue(app.staticTexts["Please write"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVideoScenePlaysWithCommunicationHotspots() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-video-scene")
        app.launch()
        app.buttons["open-scenes"].tap()
        app.swipeUp()
        app.buttons["Options for Video test scene"].tap()
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Choose video from Photos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scene-import-video-file"].exists)
        app.buttons["Cancel"].tap()

        let open = app.buttons["Open Video test scene scene"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        let play = app.buttons["scene-video-play-pause"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertTrue(play.isEnabled)
        play.tap()
        XCTAssertTrue(app.buttons["Pause scene video"].waitForExistence(timeout: 3))
        let playingScene = XCTAttachment(screenshot: app.screenshot())
        playingScene.name = "Video scene playing"
        playingScene.lifetime = .keepAlways
        add(playingScene)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene-hotspot-"))
            .firstMatch.tap()
        XCTAssertTrue(app.staticTexts["scene-selected-word"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Play scene video"].exists)
        app.buttons["Replay"].tap()
        XCTAssertTrue(app.buttons["Pause scene video"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSceneVideoCanBeImportedFromPhotosAndSaved() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["open-scenes"].tap()
        app.buttons["create-scene"].tap()
        let name = "My clip \(UUID().uuidString.prefix(6))"
        let title = app.textFields["scene-title"]
        title.tap()
        title.typeText(name)
        let word = app.textFields["scene-custom-word"]
        word.tap()
        word.typeText("wave")
        app.buttons["Add"].tap()
        app.buttons["Choose video from Photos"].tap()
        let firstVideo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 20))
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        firstVideo.tap()
        if app.navigationBars["Photos"].exists, app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        }
        XCTAssertTrue(app.staticTexts["Video scene: position words on its first frame."]
            .waitForExistence(timeout: 20))
        let save = app.buttons["save-scene"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let open = app.buttons["Open \(name) scene"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.buttons["scene-video-play-pause"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAttachedSceneHotspotVideoPlaysAndReturns() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-hotspot-video")
        app.launch()
        app.buttons["open-scenes"].tap()
        app.swipeUp()
        app.buttons["Options for Hotspot video test"].tap()
        app.buttons["Edit"].tap()
        app.swipeUp()
        app.buttons["Customize watch"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "scene-remove-hotspot-video-"
        )).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        app.buttons["Open Hotspot video test scene"].tap()
        let marker = app.buttons["Play video for watch"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        marker.tap()
        XCTAssertTrue(app.navigationBars["watch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hotspot-video-replay"].waitForExistence(timeout: 5))
        let videoScreen = XCTAttachment(screenshot: app.screenshot())
        videoScreen.name = "Attached hotspot video"
        videoScreen.lifetime = .keepAlways
        add(videoScreen)
        app.buttons["hotspot-video-replay"].tap()
        app.navigationBars["watch"].buttons["Done"].tap()
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["scene-selected-word"].exists)
    }

    @MainActor
    func testBoardVideoButtonOpensAndReturns() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-board-video")
        app.launch()
        let button = app.buttons["Watch clip"]
        for _ in 0..<6 where !button.exists { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.navigationBars["Watch clip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hotspot-video-replay"].waitForExistence(timeout: 5))
        app.buttons["hotspot-video-replay"].tap()
        app.navigationBars["Watch clip"].buttons["Done"].tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
    }

    @MainActor
    func testBoardVideoButtonCanBeCreatedFromPhotos() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let name = "Video button \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["button-action"].tap()
        app.buttons["Play video"].tap()
        let picker = app.buttons["Choose video from Photos"]
        for _ in 0..<4 where !picker.exists { app.swipeUp() }
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let firstVideo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 20))
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        firstVideo.tap()
        if app.navigationBars["Photos"].exists, app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        }
        let removeVideo = app.buttons["Remove video"]
        for _ in 0..<6 where !removeVideo.exists { app.swipeUp() }
        XCTAssertTrue(removeVideo.waitForExistence(timeout: 20))
        app.buttons["Save"].tap()
        let button = app.buttons[name]
        for _ in 0..<6 where !button.exists { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVideoCanBeAttachedToSceneHotspotFromPhotos() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-test-hotspot-attach")
        app.launch()
        app.buttons["open-scenes"].tap()
        app.swipeUp()
        app.buttons["Options for Attach video test"].tap()
        app.buttons["Edit"].tap()
        app.swipeUp()
        app.buttons["Customize watch"].tap()
        app.swipeUp()
        app.buttons["Attach video to watch from Photos"].tap()
        let firstVideo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstVideo.waitForExistence(timeout: 20))
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        firstVideo.tap()
        if app.navigationBars["Photos"].exists, app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        }
        XCTAssertTrue(app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "scene-remove-hotspot-video-"
        )).firstMatch.waitForExistence(timeout: 20))
        app.buttons["save-scene"].tap()
        app.buttons["Open Attach video test scene"].tap()
        app.buttons["Play video for watch"].tap()
        XCTAssertTrue(app.navigationBars["watch"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCommunicationAndStoryScreensOpen() {
        let app = XCUIApplication()
        app.launch()

        let boardOpened = app.buttons["Yes"].waitForExistence(timeout: 10)
        XCTAssertTrue(boardOpened)
        app.buttons["Stories"].firstMatch.tap()
        let storiesOpened = app.navigationBars["Stories"].waitForExistence(timeout: 5)
        let canCreateStory = app.buttons["Create a story"].exists
        XCTAssertTrue(storiesOpened)
        XCTAssertTrue(canCreateStory)
        app.buttons["Routine"].firstMatch.tap()
        let routineOpened = app.navigationBars["My routine"].waitForExistence(timeout: 5)
        XCTAssertTrue(routineOpened)
        app.buttons["Phrases"].firstMatch.tap()
        let phrasesOpened = app.navigationBars["Quick phrases"].waitForExistence(timeout: 5)
        XCTAssertTrue(phrasesOpened)
    }

    @MainActor
    func testKeyboardCanCompleteAWord() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        let editorOpened = editor.waitForExistence(timeout: 5)
        XCTAssertTrue(editorOpened)
        editor.tap()
        editor.typeText("I wa")
        let suggestion = app.scrollViews["Word suggestions"].buttons["want"]
        let suggestionShown = suggestion.waitForExistence(timeout: 5)
        XCTAssertTrue(suggestionShown)
        suggestion.tap()
        let completedText = editor.value as? String ?? ""
        XCTAssertTrue(completedText.contains("I want"))
    }

    @MainActor
    func testSpanishPictureWordsComposeAndQuickWordWorks() {
        let app = XCUIApplication()
        app.launch()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Settings"].firstMatch.tap()
        let languagePicker = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Communication language")
        ).firstMatch
        for _ in 0..<12 where !languagePicker.isHittable { app.swipeUp() }
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 5))
        languagePicker.tap()
        app.buttons["Español"].tap()

        app.buttons.matching(identifier: "quote.bubble.fill").firstMatch.tap()
        let yes = app.buttons["Sí"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5))
        yes.tap()
        XCTAssertTrue(app.staticTexts["Message: sí"].waitForExistence(timeout: 5))
        let want = app.buttons["quiero"]
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        want.tap()
        XCTAssertTrue(app.staticTexts["Message: sí quiero"].waitForExistence(timeout: 5))

        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["I"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: sí quiero I"].waitForExistence(timeout: 5))

        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<12 where !languagePicker.isHittable { app.swipeUp() }
        languagePicker.tap()
        app.buttons["English"].tap()
    }

    @MainActor
    func testTouchHoldSelectsPictureTileAndWordEditingRemainsAvailable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let holdPicker = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Hold picture tiles to select")
        ).firstMatch
        for _ in 0..<4 where !holdPicker.exists { app.swipeUp() }
        XCTAssertTrue(holdPicker.waitForExistence(timeout: 5))
        holdPicker.tap()
        app.buttons["0.5 seconds"].tap()

        app.buttons.matching(identifier: "quote.bubble.fill").firstMatch.tap()
        let word = app.buttons["I"]
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        word.tap()
        XCTAssertTrue(app.staticTexts["Message: empty"].exists)
        word.press(forDuration: 0.7)
        XCTAssertTrue(app.staticTexts["Message: I"].waitForExistence(timeout: 5))

        app.buttons["Customize"].tap()
        app.buttons["Edit words"].tap()
        XCTAssertTrue(app.navigationBars["Edit words"].waitForExistence(timeout: 5))
        let wordSearches = app.searchFields.matching(identifier: "Find a word")
        let wordSearch = wordSearches.element(boundBy: wordSearches.count - 1)
        XCTAssertTrue(wordSearch.waitForExistence(timeout: 5))
        wordSearch.tap()
        wordSearch.typeText("yes")
        XCTAssertTrue(app.buttons["Edit yes"].waitForExistence(timeout: 5))
        if app.buttons["close"].exists { app.buttons["close"].tap() }
        app.buttons["Done"].tap()

        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<4 where !holdPicker.exists { app.swipeUp() }
        holdPicker.tap()
        app.buttons["Off"].tap()
    }

    @MainActor
    func testPointerDwellSettingPreservesPictureAndKeyboardTouch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let dwellPicker = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Pointer dwell to select")
        ).firstMatch
        for _ in 0..<12 where !dwellPicker.isHittable { app.swipeUp() }
        XCTAssertTrue(dwellPicker.isHittable)
        dwellPicker.tap()
        app.buttons["0.8 seconds"].tap()

        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let grouping = app.buttons["grouped-picture-board-toggle"]
        if grouping.label == "Full grid" { grouping.tap() }
        app.scrollViews["board-tabs"].buttons["Core"].tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        let want = app.buttons["want"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        XCTAssertTrue((want.value as? String)?.contains("Pointer dwell 0.8 seconds") == true)
        want.tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 4))

        app.buttons["Keyboard"].tap()
        app.buttons["open-alphabet-keyboard"].tap()
        XCTAssertTrue(app.navigationBars["Alphabet keyboard"].waitForExistence(timeout: 5))
        let keyboardClear = app.buttons["alphabet-clear"]
        if keyboardClear.isEnabled { keyboardClear.tap() }
        let letter = app.buttons["alphabet-key-A"]
        XCTAssertTrue(letter.waitForExistence(timeout: 5))
        letter.tap()
        let typed = app.staticTexts["alphabet-message"]
        XCTAssertTrue(typed.waitForExistence(timeout: 4))
        XCTAssertEqual(typed.label, "A")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Large-key keyboard with pointer dwell enabled"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.navigationBars["Alphabet keyboard"].buttons["Done"].tap()
        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<12 where !dwellPicker.isHittable { app.swipeUp() }
        dwellPicker.tap()
        app.buttons["Off"].tap()
    }

    @MainActor
    func testPersonalBoardCanBeCreated() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let boardsOpened = app.navigationBars["Boards"].waitForExistence(timeout: 5)
        XCTAssertTrue(boardsOpened)

        app.buttons["Add board"].tap()
        let name = "Test board \(UUID().uuidString.prefix(6))"
        let field = app.alerts["New board"].textFields["Board name"]
        field.tap()
        field.typeText(name)
        app.alerts.buttons["Create"].tap()
        let createdRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", name))
            .firstMatch
        let created = createdRow.waitForExistence(timeout: 5)
        XCTAssertTrue(created)
    }

    @MainActor
    func testBoardsCanUseDifferentButtonSizes() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        let coreSize = app.buttons["board-size-Core"]
        let needsSize = app.buttons["board-size-Needs"]
        XCTAssertTrue(coreSize.waitForExistence(timeout: 5))
        coreSize.tap()
        app.buttons["Large"].tap()
        XCTAssertEqual(coreSize.value as? String, "Large")
        XCTAssertTrue(needsSize.waitForExistence(timeout: 5))
        needsSize.tap()
        app.buttons["Compact"].tap()
        XCTAssertEqual(needsSize.value as? String, "Compact")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Different button sizes for Core and Needs"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Done"].tap()
        let coreWord = app.buttons["want"].firstMatch
        XCTAssertTrue(coreWord.waitForExistence(timeout: 5))
        let coreFrame = coreWord.frame
        let needsTab = app.buttons["Needs"].firstMatch
        let boardTabs = app.scrollViews["board-tabs"]
        XCTAssertTrue(boardTabs.exists)
        for _ in 0..<5 {
            if needsTab.frame.midX > boardTabs.frame.maxX - 20 {
                boardTabs.swipeLeft()
            } else if needsTab.frame.midX < boardTabs.frame.minX + 20 {
                boardTabs.swipeRight()
            } else {
                break
            }
        }
        needsTab.tap()
        let needsWord = app.buttons["bathroom"].firstMatch
        XCTAssertTrue(needsWord.waitForExistence(timeout: 5))
        let needsFrame = needsWord.frame
        XCTAssertGreaterThan(coreFrame.width, needsFrame.width)
        XCTAssertGreaterThan(coreFrame.height, needsFrame.height)
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        XCTAssertTrue(coreSize.waitForExistence(timeout: 5))
        coreSize.tap()
        app.buttons["Use default"].tap()
        XCTAssertEqual(coreSize.value as? String, "Default")
    }

    @MainActor
    func testFixedBoardGridPaginatesWithoutLosingButtons() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Core"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        app.buttons["board-grid-Core"].tap()
        XCTAssertTrue(app.navigationBars["Core grid"].waitForExistence(timeout: 5))
        let fixedGrid = app.buttons["grid-mode"]
        XCTAssertTrue(fixedGrid.waitForExistence(timeout: 5))
        let columns = app.descendants(matching: .any)["grid-columns"].firstMatch
        if !columns.exists { fixedGrid.tap() }
        XCTAssertTrue(columns.waitForExistence(timeout: 5))
        columns.tap()
        app.buttons["2"].tap()
        let rows = app.descendants(matching: .any)["grid-rows"].firstMatch
        XCTAssertTrue(rows.waitForExistence(timeout: 5))
        rows.tap()
        app.buttons["2"].tap()
        XCTAssertTrue(app.staticTexts["4 button positions per page"].exists)
        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "Core fixed grid editor"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)
        app.navigationBars["Core grid"].buttons["Done"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()
        let pageCount = app.staticTexts["board-page-count"]
        XCTAssertTrue(pageCount.waitForExistence(timeout: 5))
        XCTAssertTrue(pageCount.label.hasPrefix("Page 1 of "))
        let nextPage = app.buttons["board-next-page"]
        XCTAssertTrue(nextPage.isEnabled)
        nextPage.tap()
        XCTAssertTrue(pageCount.label.hasPrefix("Page 2 of "))
        let pageScreenshot = XCTAttachment(screenshot: app.screenshot())
        pageScreenshot.name = "Core fixed grid second page"
        pageScreenshot.lifetime = .keepAlways
        add(pageScreenshot)
        let previousPage = app.buttons["board-previous-page"]
        previousPage.tap()
        XCTAssertTrue(pageCount.label.hasPrefix("Page 1 of "))
        app.buttons["open-word-finder"].tap()
        let query = app.textFields["finder-query"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.tap()
        query.typeText("different")
        app.buttons["finder-result-Core-different"].tap()
        XCTAssertTrue(app.buttons["different"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(pageCount.label.hasPrefix("Page 1 of "))
        app.buttons["end-word-finder"].tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        app.buttons["board-grid-Core"].tap()
        fixedGrid.tap()
        app.navigationBars["Core grid"].buttons["Done"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()
        XCTAssertFalse(app.staticTexts["board-page-count"].exists)
    }

    @MainActor
    func testLargeFixedBoardGridCanBeConfiguredAndDisplayed() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Core"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        app.buttons["board-grid-Core"].tap()
        XCTAssertTrue(app.navigationBars["Core grid"].waitForExistence(timeout: 5))

        let columns = app.descendants(matching: .any)["grid-columns"].firstMatch
        if !columns.exists { app.buttons["grid-mode"].tap() }
        XCTAssertTrue(columns.waitForExistence(timeout: 5))
        columns.tap()
        app.buttons["16"].tap()
        let rows = app.descendants(matching: .any)["grid-rows"].firstMatch
        rows.tap()
        app.buttons["16"].tap()
        XCTAssertTrue(app.staticTexts["256 button positions per page"].exists)

        app.navigationBars["Core grid"].buttons["Done"].tap()
        XCTAssertEqual(app.buttons["board-grid-Core"].value as? String, "16×16 grid")
        app.navigationBars["Boards"].buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["16 columns × 16 rows"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSharedGridLayoutAppliesToCoreAndCanReturnToAutomatic() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        app.buttons["default-grid-layout"].tap()
        XCTAssertTrue(app.navigationBars["Shared grid"].waitForExistence(timeout: 5))
        let mode = app.buttons["grid-mode"]
        if mode.label == "Use automatic grid" { mode.tap() }
        mode.tap()
        let positions = app.staticTexts["12 button positions per page"]
        XCTAssertTrue(positions.waitForExistence(timeout: 5))
        app.navigationBars["Shared grid"].buttons["Done"].tap()
        XCTAssertEqual(app.buttons["board-grid-Core"].value as? String, "3×4 grid")
        app.navigationBars["Boards"].buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["board-page-count"].waitForExistence(timeout: 5))
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        app.buttons["default-grid-layout"].tap()
        app.buttons["grid-mode"].tap()
        app.navigationBars["Shared grid"].buttons["Done"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()
        XCTAssertFalse(app.staticTexts["board-page-count"].exists)
    }

    @MainActor
    func testPersonalButtonCanRecordAVoice() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let name = "Voice note \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["Record a voice"].tap()
        XCTAssertTrue(app.buttons["Stop recording"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["Stop recording"].tap()
        XCTAssertTrue(app.buttons["Play recording"].waitForExistence(timeout: 5))
        app.buttons["Play recording"].tap()
        app.buttons["Save"].tap()
        XCTAssertFalse(app.navigationBars["Add button"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCommunicatorProfileCanBeCreated() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["Manage profiles"].tap()
        XCTAssertTrue(app.navigationBars["Profiles"].waitForExistence(timeout: 5))
        app.buttons["Add profile"].tap()
        let name = "Test profile \(UUID().uuidString.prefix(6))"
        let field = app.alerts["New profile"].textFields["Profile name"]
        field.tap()
        field.typeText(name)
        app.alerts.buttons["Create"].tap()
        XCTAssertTrue(app.buttons["Use profile \(name)"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVisitButtonReturnsAfterOneWord() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let name = "Visit needs \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.staticTexts["When tapped"].tap()
        app.buttons["Visit a board for one word"].tap()
        app.buttons["Save"].tap()

        let search = app.searchFields["Find a word"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        let link = app.buttons[name]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.buttons["water"].waitForExistence(timeout: 5))
        app.buttons["water"].tap()
        XCTAssertTrue(app.buttons["I"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Message: water"].exists)
    }

    @MainActor
    func testCommunicationPassportCanBeEditedAndDisplayed() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["My communication passport"].tap()
        XCTAssertTrue(app.navigationBars["My communication passport"].waitForExistence(timeout: 5))
        if app.buttons["Create my passport"].exists {
            app.buttons["Create my passport"].tap()
        } else {
            app.buttons["Edit"].tap()
        }
        let name = "Passport (UUID().uuidString.prefix(6))"
        let field = app.textFields["passport-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share my passport"].exists)
    }

    @MainActor
    func testScanningCanChooseBoardAndWord() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let scanSwitch = app.switches["Scan the communication board"]
        for _ in 0..<4 where !scanSwitch.exists { app.swipeUp() }
        XCTAssertTrue(scanSwitch.waitForExistence(timeout: 5))
        if String(describing: scanSwitch.value ?? "") != "1" {
            scanSwitch.switches.firstMatch.tap()
        }
        XCTAssertEqual(String(describing: scanSwitch.value ?? ""), "1")
        app.buttons.matching(identifier: "quote.bubble.fill").firstMatch.tap()
        let clearMessage = app.buttons["Clear message"]
        if clearMessage.isEnabled { clearMessage.tap() }

        let target = app.staticTexts["scan-target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let initial = target.label
        let deadline = Date().addingTimeInterval(4)
        while target.label == initial && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertNotEqual(target.label, initial)
        app.buttons["scan-pause"].tap()

        func advanceUntil(_ label: String) {
            for _ in 0..<50 {
                if target.label == label { return }
                app.buttons["scan-next"].tap()
            }
            XCTFail("Scanning never reached \(label)")
        }

        advanceUntil("Choose board")
        app.buttons["scan-select"].tap()
        advanceUntil("Needs")
        app.buttons["scan-select"].tap()
        advanceUntil("water")
        XCTAssertTrue(app.buttons["water"].waitForExistence(timeout: 5))
        app.buttons["scan-select"].tap()
        XCTAssertTrue(app.staticTexts["Message: water"].waitForExistence(timeout: 5))

        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<4 where !scanSwitch.exists { app.swipeUp() }
        scanSwitch.switches.firstMatch.tap()
    }

    @MainActor
    func testLargeBoardStartsAndScansAfterRelaunch() {
        let app = XCUIApplication()
        defer {
            if app.state == .runningForeground { app.terminate() }
            app.launchArguments = ["-ui-test-large-board-cleanup"]
            app.launch()
            app.terminate()
        }
        app.launchArguments += ["-ui-test-large-board-scan"]
        let started = Date()
        app.launch()
        let target = app.staticTexts["scan-target"]
        XCTAssertTrue(target.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["I"].exists)
        XCTAssertLessThan(Date().timeIntervalSince(started), 30)

        let first = target.label
        app.buttons["scan-next"].tap()
        XCTAssertNotEqual(target.label, first)

        app.terminate()
        app.launchArguments = []
        let restarted = Date()
        app.launch()
        XCTAssertTrue(target.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["I"].exists)
        XCTAssertLessThan(Date().timeIntervalSince(restarted), 30)
    }

    @MainActor
    func testStepScanningMovesOnlyWhenNextIsActivated() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let scanSwitch = app.switches["Scan the communication board"]
        for _ in 0..<5 where !scanSwitch.isHittable { app.swipeUp() }
        XCTAssertTrue(scanSwitch.isHittable)
        if String(describing: scanSwitch.value ?? "") != "1" {
            scanSwitch.switches.firstMatch.tap()
        }
        let mode = app.descendants(matching: .any)["scanning-mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.tap()
        app.buttons["Step"].firstMatch.tap()
        app.buttons["Speak"].firstMatch.tap()

        let target = app.staticTexts["scan-target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Choose board")
        XCTAssertFalse(app.buttons["scan-pause"].exists)
        Thread.sleep(forTimeInterval: 2.2)
        XCTAssertEqual(target.label, "Choose board")
        app.buttons["scan-next"].tap()
        XCTAssertEqual(target.label, "Message controls")
        app.buttons["scan-select"].tap()
        XCTAssertEqual(target.label, "Return to words")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["STEP SCAN · WORDS"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["scan-target"].label, "Choose board")

        app.buttons["Settings"].firstMatch.tap()
        let resetSwitch = app.switches["Scan the communication board"]
        for _ in 0..<5 where !resetSwitch.isHittable { app.swipeUp() }
        let resetMode = app.descendants(matching: .any)["scanning-mode"]
        resetMode.tap()
        app.buttons["Auto"].firstMatch.tap()
        resetSwitch.switches.firstMatch.tap()
    }

    @MainActor
    func testRowAndColumnScanningHighlightsAndSelectsVisibleButtons() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let scanSwitch = app.switches["Scan the communication board"]
        for _ in 0..<5 where !scanSwitch.isHittable { app.swipeUp() }
        XCTAssertTrue(scanSwitch.isHittable)
        if String(describing: scanSwitch.value ?? "") != "1" {
            scanSwitch.switches.firstMatch.tap()
        }
        let mode = app.descendants(matching: .any)["scanning-mode"]
        mode.tap()
        app.buttons["Step"].firstMatch.tap()
        let pattern = app.descendants(matching: .any)["scanning-pattern"]
        pattern.tap()
        app.buttons["Row then button"].firstMatch.tap()
        app.buttons["Speak"].firstMatch.tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }

        let target = app.staticTexts["scan-target"]
        XCTAssertEqual(target.label, "Choose board")
        for _ in 0..<6 { app.buttons["scan-next"].tap() }
        XCTAssertEqual(target.label, "Row 1")
        XCTAssertTrue(app.buttons["I"].firstMatch.isSelected)
        XCTAssertTrue(app.buttons["want"].firstMatch.isSelected)
        let rowScreenshot = XCTAttachment(screenshot: app.screenshot())
        rowScreenshot.name = "Row scan highlight"
        rowScreenshot.lifetime = .keepAlways
        add(rowScreenshot)
        app.buttons["scan-select"].tap()
        XCTAssertEqual(target.label, "Return to rows or columns")
        app.buttons["scan-next"].tap()
        XCTAssertEqual(target.label, "I")
        app.buttons["scan-next"].tap()
        XCTAssertEqual(target.label, "want")
        app.buttons["scan-select"].tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))

        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<5 where !pattern.isHittable { app.swipeUp() }
        pattern.tap()
        app.buttons["Column then button"].firstMatch.tap()
        app.buttons["Speak"].firstMatch.tap()
        for _ in 0..<7 { app.buttons["scan-next"].tap() }
        XCTAssertEqual(target.label, "Column 2")
        XCTAssertTrue(app.buttons["want"].firstMatch.isSelected)
        XCTAssertFalse(app.buttons["I"].firstMatch.isSelected)
        let columnScreenshot = XCTAttachment(screenshot: app.screenshot())
        columnScreenshot.name = "Column scan highlight"
        columnScreenshot.lifetime = .keepAlways
        add(columnScreenshot)

        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<5 where !scanSwitch.isHittable { app.swipeUp() }
        pattern.tap()
        app.buttons["One at a time"].firstMatch.tap()
        mode.tap()
        app.buttons["Auto"].firstMatch.tap()
        scanSwitch.switches.firstMatch.tap()
    }

    @MainActor
    func testScanCueModesPersistAndScanningRuns() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let scanSwitch = app.switches["Scan the communication board"]
        for _ in 0..<4 where !scanSwitch.isHittable { app.swipeUp() }
        if String(describing: scanSwitch.value ?? "") != "1" {
            scanSwitch.switches.firstMatch.tap()
        }
        let cueMode = app.descendants(matching: .any)["scan-cue-mode"]
        XCTAssertTrue(cueMode.waitForExistence(timeout: 5))
        cueMode.tap()
        app.buttons["Spoken preview"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["scan-cue-voice"].exists)
        let mode = app.descendants(matching: .any)["scanning-mode"]
        mode.tap()
        app.buttons["Step"].firstMatch.tap()
        app.buttons["Speak"].firstMatch.tap()
        let target = app.staticTexts["scan-target"]
        XCTAssertEqual(target.label, "Choose board")
        app.buttons["scan-next"].tap()
        XCTAssertEqual(target.label, "Message controls")

        app.buttons["Settings"].firstMatch.tap()
        cueMode.tap()
        app.buttons["Blip"].firstMatch.tap()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["scan-next"].tap()
        app.buttons["Settings"].firstMatch.tap()
        cueMode.tap()
        app.buttons["Woodblock"].firstMatch.tap()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["scan-next"].tap()

        app.terminate()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<4 where !cueMode.exists { app.swipeUp() }
        XCTAssertTrue(cueMode.waitForExistence(timeout: 5))
        XCTAssertTrue(cueMode.label.contains("Woodblock") || app.staticTexts["Woodblock"].exists)
        cueMode.tap()
        app.buttons["Off"].firstMatch.tap()
        mode.tap()
        app.buttons["Auto"].firstMatch.tap()
        scanSwitch.switches.firstMatch.tap()
    }

    @MainActor
    func testButtonCanBeDimmedAndHiddenWithoutMovingNeighbors() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let want = app.buttons["want"].firstMatch
        let need = app.buttons["need"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        XCTAssertTrue(need.waitForExistence(timeout: 5))
        let needPosition = need.frame.origin

        func setVisibility(_ choice: String) {
            app.buttons["Customize"].tap()
            app.buttons["Edit words"].tap()
            let search = app.textFields["word-manager-search"]
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            search.typeText("want\n")
            app.buttons["Edit want"].firstMatch.tap()
            let picker = app.descendants(matching: .any)["button-visibility"]
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            picker.tap()
            app.buttons[choice].firstMatch.tap()
            app.navigationBars["Edit button"].buttons["Save"].tap()
            let closeSearch = app.buttons["close"].firstMatch
            if closeSearch.exists { closeSearch.tap() }
            let wordManager = app.navigationBars["Edit words"]
            if wordManager.exists { wordManager.buttons["Done"].tap() }
            XCTAssertTrue(app.buttons["Customize"].firstMatch.isHittable)
        }

        setVisibility("Dimmed")
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        XCTAssertTrue((want.value as? String)?.contains("Dimmed") == true)
        XCTAssertEqual(need.frame.origin.x, needPosition.x, accuracy: 1)
        let dimmedScreenshot = XCTAttachment(screenshot: app.screenshot())
        dimmedScreenshot.name = "Dimmed board button"
        dimmedScreenshot.lifetime = .keepAlways
        add(dimmedScreenshot)

        app.buttons["Settings"].firstMatch.tap()
        let activeSwitch = app.switches["Dimmed buttons can be selected"]
        for _ in 0..<4 where !activeSwitch.isHittable { app.swipeUp() }
        XCTAssertTrue(activeSwitch.isHittable)
        if String(describing: activeSwitch.value ?? "") == "1" {
            activeSwitch.switches.firstMatch.tap()
        }
        app.buttons["Speak"].firstMatch.tap()
        XCTAssertFalse(want.isEnabled)

        setVisibility("Hidden")
        XCTAssertFalse(want.exists)
        XCTAssertEqual(need.frame.origin.x, needPosition.x, accuracy: 1)
        XCTAssertEqual(need.frame.origin.y, needPosition.y, accuracy: 1)
        let hiddenScreenshot = XCTAttachment(screenshot: app.screenshot())
        hiddenScreenshot.name = "Hidden board button keeps its slot"
        hiddenScreenshot.lifetime = .keepAlways
        add(hiddenScreenshot)

        setVisibility("Shown")
        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<4 where !activeSwitch.isHittable { app.swipeUp() }
        if String(describing: activeSwitch.value ?? "") != "1" {
            activeSwitch.switches.firstMatch.tap()
        }
        app.buttons["Speak"].firstMatch.tap()
        XCTAssertTrue(want.exists)
    }

    @MainActor
    func testBoardButtonsCanBeReorderedAndRestored() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Core"].firstMatch.tap()
        let want = app.buttons["want"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        let originalPosition = want.frame.origin

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        XCTAssertTrue(app.navigationBars["Arrange buttons"].waitForExistence(timeout: 5))
        let moveDown = app.buttons["move-down-want"]
        XCTAssertTrue(moveDown.waitForExistence(timeout: 5))
        let originalRowY = moveDown.frame.midY
        moveDown.tap()
        XCTAssertGreaterThan(moveDown.frame.midY, originalRowY)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Board button arrangement"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        XCTAssertNotEqual(want.frame.origin, originalPosition)

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        let moveUp = app.buttons["move-up-want"]
        XCTAssertTrue(moveUp.waitForExistence(timeout: 5))
        moveUp.tap()
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertEqual(want.frame.origin.x, originalPosition.x, accuracy: 1)
        XCTAssertEqual(want.frame.origin.y, originalPosition.y, accuracy: 1)
    }

    @MainActor
    func testBoardButtonsCanSwapGridPositionsAndRestoreThem() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Core"].firstMatch.tap()
        let want = app.buttons["want"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        let originalPosition = want.frame.origin

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        app.segmentedControls.buttons["Swap"].tap()
        let wantSlot = app.buttons["swap-cell-want"]
        let needSlot = app.buttons["swap-cell-need"]
        XCTAssertTrue(wantSlot.waitForExistence(timeout: 5))
        wantSlot.tap()
        needSlot.tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Swap picture button positions"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertNotEqual(want.frame.origin, originalPosition)

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        app.segmentedControls.buttons["Swap"].tap()
        needSlot.tap()
        wantSlot.tap()
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertEqual(want.frame.origin.x, originalPosition.x, accuracy: 1)
        XCTAssertEqual(want.frame.origin.y, originalPosition.y, accuracy: 1)
    }

    @MainActor
    func testBoardButtonCanMoveIntoEmptyGridPositionAndRestore() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Core"].firstMatch.tap()
        let first = app.buttons["I"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let originalPosition = first.frame.origin

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        app.segmentedControls.buttons["Swap"].tap()
        app.buttons["swap-cell-I"].tap()
        let empty = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "swap-empty-")).firstMatch
        let next = app.buttons["swap-page-next"]
        while !empty.exists && next.isEnabled { next.tap() }
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        empty.tap()
        XCTAssertTrue(app.buttons["swap-cell-I"].waitForExistence(timeout: 5))

        app.buttons["swap-cell-I"].tap()
        let previous = app.buttons["swap-page-previous"]
        while !app.buttons["swap-empty-1"].exists && previous.isEnabled { previous.tap() }
        XCTAssertTrue(app.buttons["swap-empty-1"].waitForExistence(timeout: 5))
        app.buttons["swap-empty-1"].tap()
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertEqual(first.frame.origin.x, originalPosition.x, accuracy: 1)
        XCTAssertEqual(first.frame.origin.y, originalPosition.y, accuracy: 1)
    }

    @MainActor
    func testBoardButtonsCanBeDraggedAcrossGridAndInserted() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Core"].firstMatch.tap()
        let first = app.buttons["I"].firstMatch
        let need = app.buttons["need"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let firstPosition = first.frame.origin
        let needPosition = need.frame.origin

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        app.segmentedControls.buttons["Swap"].tap()
        let firstSlot = app.buttons["swap-cell-I"]
        let needSlot = app.buttons["swap-cell-need"]
        XCTAssertTrue(needSlot.waitForExistence(timeout: 5))
        needSlot.press(forDuration: 1.2, thenDragTo: firstSlot,
                       withVelocity: .slow, thenHoldForDuration: 0.5)
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertEqual(need.frame.origin.x, firstPosition.x, accuracy: 1)
        XCTAssertEqual(need.frame.origin.y, firstPosition.y, accuracy: 1)
        XCTAssertEqual(first.frame.origin.x, needPosition.x, accuracy: 1)
        XCTAssertEqual(first.frame.origin.y, needPosition.y, accuracy: 1)

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        app.segmentedControls.buttons["Swap"].tap()
        firstSlot.press(forDuration: 1.2, thenDragTo: needSlot,
                        withVelocity: .slow, thenHoldForDuration: 0.5)
        let insertBefore = firstSlot.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        needSlot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.2, thenDragTo: insertBefore,
                   withVelocity: .slow, thenHoldForDuration: 0.5)
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertEqual(need.frame.origin.x, firstPosition.x, accuracy: 1)
        XCTAssertEqual(need.frame.origin.y, firstPosition.y, accuracy: 1)
        XCTAssertNotEqual(first.frame.origin, needPosition)

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        app.segmentedControls.buttons["Swap"].tap()
        let wantSlot = app.buttons["swap-cell-want"]
        let insertAfter = wantSlot.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        needSlot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.2, thenDragTo: insertAfter,
                   withVelocity: .slow, thenHoldForDuration: 0.5)
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertEqual(first.frame.origin.x, firstPosition.x, accuracy: 1)
        XCTAssertEqual(first.frame.origin.y, firstPosition.y, accuracy: 1)
        XCTAssertEqual(need.frame.origin.x, needPosition.x, accuracy: 1)
        XCTAssertEqual(need.frame.origin.y, needPosition.y, accuracy: 1)
    }

    @MainActor
    func testSelectedBoardButtonsCanBeAlphabetizedAndRestored() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        app.buttons["Core"].firstMatch.tap()
        let want = app.buttons["want"].firstMatch
        let need = app.buttons["need"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        let wantPosition = want.frame.origin
        let needPosition = need.frame.origin

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        app.navigationBars["Arrange buttons"].buttons["Sort"].tap()
        let alphabetize = app.buttons["Alphabetize selected"]
        XCTAssertFalse(alphabetize.isEnabled)
        app.buttons["Select all"].tap()
        XCTAssertTrue(alphabetize.isEnabled)
        app.buttons["Clear selection"].tap()
        XCTAssertFalse(alphabetize.isEnabled)
        app.buttons["sort-select-want"].tap()
        app.buttons["sort-select-need"].tap()
        XCTAssertTrue(alphabetize.isEnabled)
        let selection = XCTAttachment(screenshot: app.screenshot())
        selection.name = "Select picture buttons to alphabetize"
        selection.lifetime = .keepAlways
        add(selection)
        alphabetize.tap()
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertEqual(want.frame.origin.x, needPosition.x, accuracy: 1)
        XCTAssertEqual(want.frame.origin.y, needPosition.y, accuracy: 1)
        XCTAssertEqual(need.frame.origin.x, wantPosition.x, accuracy: 1)
        XCTAssertEqual(need.frame.origin.y, wantPosition.y, accuracy: 1)

        app.buttons["Customize"].tap()
        app.buttons["Arrange buttons"].tap()
        app.segmentedControls.buttons["Swap"].tap()
        app.buttons["swap-cell-need"].tap()
        app.buttons["swap-cell-want"].tap()
        app.navigationBars["Arrange buttons"].buttons["Done"].tap()
        XCTAssertEqual(want.frame.origin.x, wantPosition.x, accuracy: 1)
        XCTAssertEqual(want.frame.origin.y, wantPosition.y, accuracy: 1)
        XCTAssertEqual(need.frame.origin.x, needPosition.x, accuracy: 1)
        XCTAssertEqual(need.frame.origin.y, needPosition.y, accuracy: 1)
    }

    @MainActor
    func testGroupedPictureBoardUsesTwoLargeStepsAndKeepsTheMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }

        let toggle = app.buttons["grouped-picture-board-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.label == "Large groups" { toggle.tap() }
        let firstGroup = app.buttons["picture-group-0"]
        XCTAssertTrue(firstGroup.waitForExistence(timeout: 5))
        XCTAssertTrue(firstGroup.label.contains("I"))
        firstGroup.tap()
        XCTAssertTrue(app.buttons["all-picture-groups"].waitForExistence(timeout: 5))
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "Enlarged picture buttons in a selected group"
        detail.lifetime = .keepAlways
        add(detail)
        app.buttons["I"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: I"].waitForExistence(timeout: 5))
        XCTAssertTrue(firstGroup.waitForExistence(timeout: 5))

        firstGroup.tap()
        app.buttons["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: I want"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Grouped picture board with composed message"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        toggle.tap()
        XCTAssertTrue(app.buttons["want"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(firstGroup.exists)
        XCTAssertTrue(app.staticTexts["Message: I want"].exists)
    }

    @MainActor
    func testOptInRecentPictureWordsOfferFastRepeatWithoutMovingCoreBoard() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let recentSetting = app.switches["recent-picture-words-setting"]
        for _ in 0..<10 where !recentSetting.isHittable { app.swipeUp() }
        XCTAssertTrue(recentSetting.isHittable)
        let before = String(describing: recentSetting.value ?? "")
        if before == "0" || before == "Off" {
            recentSetting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let after = String(describing: recentSetting.value ?? "")
        XCTAssertTrue(["1", "On"].contains(after), "Recent setting value: \(after)")
        guard ["1", "On"].contains(after) else { return }
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let grouping = app.buttons["grouped-picture-board-toggle"]
        if grouping.label == "Full grid" { grouping.tap() }
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }

        let coreI = app.buttons["I"].firstMatch
        let coreWant = app.buttons["want"].firstMatch
        XCTAssertTrue(coreI.waitForExistence(timeout: 5))
        XCTAssertTrue(coreWant.waitForExistence(timeout: 5))
        let corePosition = coreWant.frame.origin
        coreI.tap()
        coreWant.tap()
        XCTAssertTrue(app.staticTexts["Message: I want"].waitForExistence(timeout: 5))

        let recentTab = app.buttons["recent-board-tab"]
        XCTAssertTrue(recentTab.waitForExistence(timeout: 5))
        recentTab.tap()
        let recentWant = app.buttons["want"].firstMatch
        let recentI = app.buttons["I"].firstMatch
        XCTAssertTrue(recentWant.waitForExistence(timeout: 5))
        XCTAssertTrue(recentI.waitForExistence(timeout: 5))
        XCTAssertLessThan(recentWant.frame.minX, recentI.frame.minX)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Opt-in Recent picture words"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        recentI.tap()
        XCTAssertTrue(app.staticTexts["Message: I want I"].waitForExistence(timeout: 5))
        XCTAssertLessThan(recentI.frame.minX, recentWant.frame.minX)
        let coreTab = app.buttons["Core"].firstMatch
        let boardTabs = app.scrollViews["board-tabs"]
        XCTAssertTrue(boardTabs.waitForExistence(timeout: 5))
        boardTabs.swipeLeft()
        coreTab.tap()
        XCTAssertEqual(app.buttons["want"].firstMatch.frame.origin.x, corePosition.x, accuracy: 1)
        XCTAssertEqual(app.buttons["want"].firstMatch.frame.origin.y, corePosition.y, accuracy: 1)
    }

    @MainActor
    func testRecentWordHighlightKeepsOriginalPicturePosition() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let setting = app.switches["recent-word-highlights-setting"]
        for _ in 0..<10 where !setting.isHittable { app.swipeUp() }
        XCTAssertTrue(setting.isHittable)
        if setting.value as? String != "1" {
            setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(setting.value as? String, "1")

        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let grouping = app.buttons["grouped-picture-board-toggle"]
        if grouping.label == "Full grid" { grouping.tap() }
        let core = app.scrollViews["board-tabs"].buttons["Core"]
        XCTAssertTrue(core.waitForExistence(timeout: 5))
        core.tap()
        let want = app.buttons["want"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        let position = want.frame.origin
        want.tap()
        XCTAssertTrue((want.value as? String)?.contains("Recently used") == true)
        XCTAssertEqual(want.frame.origin.x, position.x, accuracy: 1)
        XCTAssertEqual(want.frame.origin.y, position.y, accuracy: 1)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Recent word highlighted in its original position"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Settings"].firstMatch.tap()
        let savedSetting = app.switches["recent-word-highlights-setting"]
        for _ in 0..<10 where !savedSetting.isHittable { app.swipeUp() }
        XCTAssertEqual(savedSetting.value as? String, "1")
        savedSetting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    @MainActor
    func testTimeOfDayHighlightKeepsOriginalPicturePosition() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let setting = app.switches["time-of-day-highlights-setting"]
        for _ in 0..<12 where !setting.isHittable { app.swipeUp() }
        XCTAssertTrue(setting.isHittable)
        if setting.value as? String != "1" {
            setting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(setting.value as? String, "1")

        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let grouping = app.buttons["grouped-picture-board-toggle"]
        if grouping.label == "Full grid" { grouping.tap() }
        let core = app.scrollViews["board-tabs"].buttons["Core"]
        XCTAssertTrue(core.waitForExistence(timeout: 5))
        core.tap()
        let want = app.buttons["want"].firstMatch
        let need = app.buttons["need"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        let position = want.frame.origin
        want.tap()
        need.tap()
        want.tap()
        XCTAssertTrue((want.value as? String)?.contains("Often used at this time") == true)
        XCTAssertEqual(want.frame.origin.x, position.x, accuracy: 1)
        XCTAssertEqual(want.frame.origin.y, position.y, accuracy: 1)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Time-of-day word highlighted in its original position"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Settings"].firstMatch.tap()
        let savedSetting = app.switches["time-of-day-highlights-setting"]
        for _ in 0..<12 where !savedSetting.isHittable { app.swipeUp() }
        XCTAssertEqual(savedSetting.value as? String, "1")
        savedSetting.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    @MainActor
    func testSpokenPictureMessageClearsOnlyWhenNextWordIsChosen() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let autoClear = app.switches["auto-clear-picture-message"]
        for _ in 0..<8 where !autoClear.isHittable { app.swipeUp() }
        XCTAssertTrue(autoClear.isHittable)
        if String(describing: autoClear.value ?? "") != "1" { autoClear.switches.firstMatch.tap() }
        XCTAssertEqual(String(describing: autoClear.value ?? ""), "1")

        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["want"].firstMatch.tap()
        app.buttons["need"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: want need"].waitForExistence(timeout: 5))
        app.buttons["speak-picture-message"].tap()
        XCTAssertTrue(app.staticTexts["Message: want need"].exists)
        let spokenScreenshot = XCTAttachment(screenshot: app.screenshot())
        spokenScreenshot.name = "Spoken picture message stays visible"
        spokenScreenshot.lifetime = .keepAlways
        add(spokenScreenshot)

        app.buttons["like"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: like"].waitForExistence(timeout: 5))
        app.buttons["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: like want"].waitForExistence(timeout: 5))

        app.buttons["Settings"].firstMatch.tap()
        for _ in 0..<8 where !autoClear.isHittable { app.swipeUp() }
        XCTAssertTrue(autoClear.isHittable)
        XCTAssertEqual(String(describing: autoClear.value ?? ""), "1")
        if String(describing: autoClear.value ?? "") == "1" { autoClear.switches.firstMatch.tap() }
        app.buttons["Speak"].firstMatch.tap()
        if clear.isEnabled { clear.tap() }
    }

    @MainActor
    func testPersonalClearButtonActsOnThePictureMessage() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))

        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let label = "Clear draft \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(label + "\n")
        app.staticTexts["When tapped"].tap()
        app.buttons["Clear picture message"].firstMatch.tap()
        app.navigationBars["Add button"].buttons["Save"].tap()

        let search = app.searchFields["Find a word"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(label)
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Personal clear button before use"
        before.lifetime = .keepAlways
        add(before)
        button.tap()
        XCTAssertTrue(app.staticTexts["Message: empty"].waitForExistence(timeout: 5))
        let undoClear = app.buttons["undo-clear-message"]
        XCTAssertTrue(undoClear.waitForExistence(timeout: 5))
        undoClear.tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPersonalHomeButtonReturnsToCore() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let needs = app.buttons["Needs"]
        let core = app.buttons["Core"]
        core.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: core.coordinate(withNormalizedOffset: CGVector(dx: -1.5, dy: 0.5)))
        needs.tap()
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()

        let label = "Home draft \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(label + "\n")
        app.staticTexts["When tapped"].tap()
        app.buttons["Go to home board"].firstMatch.tap()
        app.navigationBars["Add button"].buttons["Save"].tap()

        let search = app.searchFields["Find a word"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(label)
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.buttons["Core"].isSelected)
    }

    @MainActor
    func testPictureMessageCanBecomeReusableButton() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["I"].firstMatch.tap()
        app.buttons["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: I want"].waitForExistence(timeout: 5))

        app.buttons["More"].tap()
        app.buttons["Save as button"].tap()
        XCTAssertTrue(app.navigationBars["Save message as button"].waitForExistence(timeout: 5))
        let labelField = app.textFields["Button label"]
        XCTAssertEqual(labelField.value as? String, "I want")
        XCTAssertEqual(app.textFields["Spoken message (optional)"].value as? String, "I want")
        let label = "Saved line \(UUID().uuidString.prefix(6))"
        labelField.tap()
        labelField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + label + "\n")
        app.navigationBars["Save message as button"].buttons["Save"].tap()

        clear.tap()
        let search = app.searchFields["Find a word"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(label)
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["Message: I want"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTypedMessageCanBecomeReusableButton() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Keyboard"].tap()
        let clear = app.buttons["Clear"]
        if clear.isEnabled { clear.tap() }
        let editor = app.textViews["Type a message"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Please wait for me")
        app.buttons["More"].tap()
        app.buttons["Save as button"].tap()
        XCTAssertTrue(app.navigationBars["Save message as button"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Spoken message (optional)"].value as? String, "Please wait for me")
        let label = "Typed line \(UUID().uuidString.prefix(6))"
        let labelField = app.textFields["Button label"]
        labelField.tap()
        labelField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 24) + label + "\n")
        app.navigationBars["Save message as button"].buttons["Save"].tap()

        app.buttons["Pictures"].tap()
        let pictureClear = app.buttons["Clear message"]
        if pictureClear.isEnabled { pictureClear.tap() }
        let search = app.searchFields["Find a word"]
        search.tap()
        search.typeText(label)
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["Message: Please wait for me"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testComposedMessageCanReplaceExistingButtonSpeech() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }

        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let label = "Target \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(label + "\n")
        app.navigationBars["Add button"].buttons["Save"].tap()

        app.buttons["I"].firstMatch.tap()
        app.buttons["want"].firstMatch.tap()
        app.buttons["More"].tap()
        app.buttons["Store on existing button"].tap()
        XCTAssertTrue(app.navigationBars["Store on a button"].waitForExistence(timeout: 5))
        let targetSearch = app.textFields["store-message-search"]
        targetSearch.tap()
        targetSearch.typeText(label + "\n")
        app.buttons["Store on \(label)"].tap()
        XCTAssertTrue(app.alerts["Replace button message?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Store message"].tap()

        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        let search = app.searchFields["Find a word"]
        search.tap()
        search.typeText(label)
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["Message: I want"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPersonalButtonCanUseCustomColors() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let label = "Color cue \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Button label"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(label + "\n")
        let background = app.switches["Custom background"]
        XCTAssertTrue(background.waitForExistence(timeout: 5))
        background.switches.firstMatch.tap()
        XCTAssertEqual(String(describing: background.value ?? ""), "1")
        let border = app.switches["Custom border"]
        if !border.switches.firstMatch.exists { app.swipeUp() }
        if border.switches.firstMatch.exists { border.switches.firstMatch.tap() }
        else { border.tap() }
        XCTAssertEqual(String(describing: border.value ?? ""), "1")
        app.navigationBars["Add button"].buttons["Save"].tap()

        let search = app.searchFields["Find a word"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(label)
        XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5))
        let colorScreen = XCTAttachment(screenshot: app.screenshot())
        colorScreen.name = "Personal button colors"
        colorScreen.lifetime = .keepAlways
        add(colorScreen)
    }

    @MainActor
    func testPrintableBoardsPreviewOffersSaveAndPrint() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let export = app.buttons["Preview printable boards"]
        for _ in 0..<6 where !export.exists { app.swipeUp() }
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        XCTAssertTrue(app.navigationBars["Printable boards"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertTrue(app.buttons["Save PDF"].exists)
        XCTAssertTrue(app.buttons["Print"].exists)
    }

    @MainActor
    func testChoiceBoardCanBeCreatedAndUsed() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Choice boards"].tap()
        XCTAssertTrue(app.navigationBars["Choice boards"].waitForExistence(timeout: 5))
        let create = app.buttons["Create a choice board"]
        for _ in 0..<8 where !create.exists { app.swipeUp() }
        create.tap()
        XCTAssertTrue(app.navigationBars["New choice board"].waitForExistence(timeout: 5))

        let name = "Lunch \(UUID().uuidString.prefix(6))"
        let title = app.textFields["choice-board-title"]
        title.tap()
        title.typeText(name)
        let custom = app.textFields["custom-choice-label"]
        app.swipeUp()
        custom.tap()
        custom.typeText("Soup")
        app.swipeUp()
        app.buttons["Add"].firstMatch.tap()
        custom.tap()
        custom.typeText("Rice")
        app.swipeUp()
        app.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Save"].isEnabled)
        app.buttons["Save"].tap()

        let open = app.buttons["Open \(name)"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.navigationBars["Make a choice"].waitForExistence(timeout: 5))
        app.buttons["Soup"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Soup")
        app.buttons["Something else"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Something else")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Choice board selection"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Back to full Speak board"].tap()
        XCTAssertTrue(app.navigationBars["Open Voice"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testChoiceBoardStepScanReachesChoicesAlternativesAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-choice-scan"]
        app.launch()
        app.buttons["Choice boards"].tap()
        let open = app.buttons["Open Choice scan test"]
        for _ in 0..<8 where !open.exists { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()

        let target = app.staticTexts["choice-scan-target"]
        let next = app.buttons["choice-scan-next"]
        let select = app.buttons["choice-scan-select"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Tea")
        next.tap()
        XCTAssertEqual(target.label, "Water")
        select.tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Water")
        XCTAssertEqual(target.label, "Add to message")
        XCTAssertTrue(app.buttons["Add to message"].isEnabled)
        select.tap()
        XCTAssertEqual(target.label, "Speak again")
        XCTAssertFalse(app.buttons["Add to message"].isEnabled)
        select.tap()

        next.tap()
        XCTAssertEqual(target.label, "Something else")
        select.tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Something else")
        XCTAssertEqual(target.label, "Add to message")
        next.tap()
        XCTAssertEqual(target.label, "Something else")
        next.tap()
        XCTAssertEqual(target.label, "No thanks")
        next.tap()
        XCTAssertEqual(target.label, "Back to full Speak board")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Choice board step scanning"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        select.tap()
        XCTAssertTrue(app.navigationBars["Open Voice"].waitForExistence(timeout: 5))

        app.buttons["Choice boards"].tap()
        for _ in 0..<8 where !open.exists { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        for _ in 0..<5 { next.tap() }
        XCTAssertEqual(target.label, "Done")
        select.tap()
        XCTAssertTrue(app.navigationBars["Choice boards"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testChoiceBoardAutoScanCanPauseAndResume() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-test-choice-scan-auto"]
        app.launch()
        app.buttons["Choice boards"].tap()
        let open = app.buttons["Open Choice scan test"]
        for _ in 0..<8 where !open.exists { app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()

        let target = app.staticTexts["choice-scan-target"]
        let pause = app.buttons["choice-scan-pause"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        pause.tap()
        let held = target.label
        Thread.sleep(forTimeInterval: 3.5)
        XCTAssertEqual(target.label, held)
        pause.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", held), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 6), .completed)
    }

    @MainActor
    func testChoiceBoardLargeFirstLayoutKeepsAllChoicesUsable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Choice boards"].tap()
        let name = "Layout \(UUID().uuidString.prefix(6))"
        let question = app.textFields["quick-choice-question"]
        question.tap()
        question.typeText(name)
        let choices = app.textFields["quick-choice-options"]
        choices.tap()
        choices.typeText("Tea, Coffee, Water")
        question.tap()
        let saveQuick = app.buttons["Save for later"]
        XCTAssertTrue(saveQuick.isEnabled)
        saveQuick.tap()
        XCTAssertEqual(app.staticTexts["quick-choice-feedback"].label, "Saved to My choice boards.")
        let menu = app.buttons["Options for \(name)"]
        for _ in 0..<24 where !menu.isHittable { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(menu.isHittable)
        menu.tap()
        app.buttons["Edit board"].tap()
        let layout = app.descendants(matching: .any)["choice-board-layout"]
        for _ in 0..<4 where !layout.isHittable { app.swipeDown() }
        XCTAssertTrue(layout.waitForExistence(timeout: 5))
        app.buttons["Large first"].tap()
        app.navigationBars["Edit choice board"].buttons["Save"].tap()

        let open = app.buttons["Open \(name)"]
        for _ in 0..<24 where !open.isHittable { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.navigationBars["Make a choice"].waitForExistence(timeout: 5))
        let first = app.buttons["Tea"]
        let second = app.buttons["Coffee"]
        let third = app.buttons["water"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(second.exists)
        XCTAssertGreaterThan(first.frame.height, second.frame.height + 40)
        XCTAssertLessThan(first.frame.maxY, second.frame.minY)
        second.tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Coffee")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Choice board large first layout"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        for _ in 0..<8 where !third.isHittable { app.swipeUp() }
        XCTAssertTrue(third.isHittable)
        third.tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "water")
    }

    @MainActor
    func testChoiceBoardColorsAndSharingControls() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Choice boards"].tap()
        let name = "Color choices \(UUID().uuidString.prefix(6))"
        let question = app.textFields["quick-choice-question"]
        question.tap()
        question.typeText(name)
        let choices = app.textFields["quick-choice-options"]
        choices.tap()
        choices.typeText("Soup, Rice")
        app.buttons["Save for later"].tap()
        let menu = app.buttons["Options for \(name)"]
        for _ in 0..<4 where !menu.exists { app.swipeUp() }
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.buttons["import-choice-board"].exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["import-choice-board"].exists)
        for _ in 0..<4 where !menu.exists { app.swipeDown() }
        menu.tap()
        app.buttons["Edit board"].tap()
        app.buttons["Colors for Soup"].tap()
        XCTAssertTrue(app.navigationBars["Soup"].waitForExistence(timeout: 5))
        let background = app.switches["Custom background"]
        if background.switches.firstMatch.exists { background.switches.firstMatch.tap() }
        else { background.tap() }
        XCTAssertEqual(String(describing: background.value ?? ""), "1")
        let border = app.switches["Custom border"]
        if !border.switches.firstMatch.exists { app.swipeUp() }
        if border.switches.firstMatch.exists { border.switches.firstMatch.tap() }
        else { border.tap() }
        XCTAssertEqual(String(describing: border.value ?? ""), "1")
        app.navigationBars["Soup"].buttons["Done"].tap()
        app.buttons["Save"].tap()
        let open = app.buttons["Open \(name)"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.buttons["Soup"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Colored choice board"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars["Make a choice"].buttons["Done"].tap()
        app.buttons["Options for \(name)"].tap()
        XCTAssertTrue(app.buttons["Export board file"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testChoiceBoardsCanBeFiledAndReordered() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Choice boards"].tap()
        let firstName = "Folder choice \(UUID().uuidString.prefix(6))"
        let secondName = firstName + " two"
        let folderName = "Meals \(UUID().uuidString.prefix(6))"
        let question = app.textFields["quick-choice-question"]
        question.tap()
        question.typeText(firstName)
        let choices = app.textFields["quick-choice-options"]
        choices.tap()
        choices.typeText("Tea, Coffee")
        question.tap()
        let saveQuick = app.buttons["Save for later"]
        XCTAssertTrue(saveQuick.isEnabled)
        saveQuick.tap()
        XCTAssertEqual(app.staticTexts["quick-choice-feedback"].label, "Saved to My choice boards.")
        for _ in 0..<6 where !question.exists { app.swipeDown() }
        question.tap()
        question.typeText(" two\n")
        saveQuick.tap()
        XCTAssertEqual(app.staticTexts["quick-choice-feedback"].label, "Saved to My choice boards.")

        let firstMenu = app.buttons["Options for \(firstName)"]
        for _ in 0..<5 where !firstMenu.exists { app.swipeUp() }
        for _ in 0..<8 where !firstMenu.exists { app.swipeDown() }
        XCTAssertTrue(firstMenu.waitForExistence(timeout: 5))
        firstMenu.tap()
        app.buttons["Edit board"].tap()
        let folder = app.textFields["choice-board-folder"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        folder.tap()
        folder.typeText(folderName + "\n")
        app.navigationBars["Edit choice board"].buttons["Save"].tap()

        let secondMenu = app.buttons["Options for \(secondName)"]
        for _ in 0..<5 where !secondMenu.exists { app.swipeUp() }
        XCTAssertTrue(secondMenu.waitForExistence(timeout: 5))
        secondMenu.tap()
        app.buttons["Edit board"].tap()
        let existingFolders = app.buttons["Use an existing folder"]
        if existingFolders.buttons.firstMatch.exists { existingFolders.buttons.firstMatch.tap() }
        else { existingFolders.tap() }
        XCTAssertTrue(app.buttons[folderName].waitForExistence(timeout: 5))
        app.buttons[folderName].tap()
        app.navigationBars["Edit choice board"].buttons["Save"].tap()

        let filter = app.descendants(matching: .any)["choice-board-folder-filter"]
        for _ in 0..<5 where !filter.exists { app.swipeUp() }
        for _ in 0..<10 where !filter.isHittable { app.swipeDown() }
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        XCTAssertTrue(filter.isHittable)
        filter.tap()
        app.buttons[folderName].tap()
        let first = app.buttons["Open \(firstName)"]
        let second = app.buttons["Open \(secondName)"]
        for _ in 0..<4 where !second.exists { app.swipeUp() }
        XCTAssertTrue(first.exists)
        XCTAssertTrue(second.exists)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)

        app.buttons["Options for \(secondName)"].tap()
        app.buttons["Move up"].tap()
        XCTAssertLessThan(second.frame.minY, first.frame.minY)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Choice board folder order"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testQuickChoicesCanBeOfferedAndSaved() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Choice boards"].tap()
        XCTAssertTrue(app.navigationBars["Choice boards"].waitForExistence(timeout: 5))

        let title = "Drinks \(UUID().uuidString.prefix(6))"
        let question = app.textFields["quick-choice-question"]
        question.tap()
        question.typeText(title)
        let options = app.textFields["quick-choice-options"]
        options.tap()
        options.typeText("Water, Juice, Milk")
        let show = app.buttons["show-quick-choices"]
        XCTAssertTrue(show.isEnabled)
        show.tap()
        XCTAssertTrue(app.navigationBars["Make a choice"].waitForExistence(timeout: 5))
        app.buttons["juice"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "juice")
        app.buttons["No thanks"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "No thanks")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Quick choices in use"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars["Make a choice"].buttons["Done"].tap()

        XCTAssertTrue(app.buttons["Save for later"].waitForExistence(timeout: 5))
        app.buttons["Save for later"].tap()
        let feedback = app.staticTexts["quick-choice-feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        XCTAssertEqual(feedback.label, "Saved to My choice boards.")
    }

    @MainActor
    func testReviewedSpokenChoicesBecomeChoiceButtons() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Choice boards"].tap()
        XCTAssertTrue(app.navigationBars["Choice boards"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["spoken-choice-record-toggle"].exists)

        let review = app.textFields["spoken-choice-review"]
        if !review.exists { app.swipeUp() }
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()
        review.typeText("Lemonade.\n")
        XCTAssertEqual(app.staticTexts["spoken-choice-count"].label, "1 of 8 choices ready")
        review.tap()
        review.typeText("Iced tea\n")
        XCTAssertEqual(app.staticTexts["spoken-choice-count"].label, "2 of 8 choices ready")
        let show = app.buttons["show-spoken-choices"]
        XCTAssertTrue(show.waitForExistence(timeout: 5))
        XCTAssertTrue(show.isEnabled)
        let composerScreenshot = XCTAttachment(screenshot: app.screenshot())
        composerScreenshot.name = "Spoken choice review and add controls"
        composerScreenshot.lifetime = .keepAlways
        add(composerScreenshot)
        show.tap()

        XCTAssertTrue(app.navigationBars["Make a choice"].waitForExistence(timeout: 5))
        app.buttons["Lemonade"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Lemonade")
        app.buttons["Iced tea"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Iced tea")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Reviewed choices in use"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testChoiceBoardEditingLockKeepsQuickCommunicationAvailable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let lock = app.switches["choice-board-edit-lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 5))
        let isLocked = { [lock] in
            ["1", "on", "true"].contains(String(describing: lock.value ?? "").lowercased())
        }
        if isLocked() { lock.switches.firstMatch.tap() }
        lock.switches.firstMatch.tap()
        XCTAssertTrue(isLocked())

        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Choice boards"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["choice-board-locked"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["New board"].isEnabled)

        let options = app.textFields["quick-choice-options"]
        options.tap()
        options.typeText("Lemonade, Iced tea")
        XCTAssertTrue(app.buttons["show-quick-choices"].isEnabled)
        XCTAssertFalse(app.buttons["Save for later"].isEnabled)
        app.buttons["show-quick-choices"].tap()
        XCTAssertTrue(app.navigationBars["Make a choice"].waitForExistence(timeout: 5))
        app.buttons["Lemonade"].tap()
        XCTAssertEqual(app.staticTexts["selected-choice"].label, "Lemonade")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Locked board editing, quick choices available"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.navigationBars["Make a choice"].buttons["Done"].tap()
        app.navigationBars["Choice boards"].buttons["Done"].tap()
        app.buttons["Settings"].firstMatch.tap()
        lock.switches.firstMatch.tap()
        XCTAssertFalse(isLocked())
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Choice boards"].tap()
        XCTAssertTrue(app.buttons["New board"].isEnabled)
    }

    @MainActor
    func testPictureWordFormCanChangeAndSurviveRelaunch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["board-language"].tap()
        app.buttons["English"].tap()
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Core"].tap()
        app.buttons["want"].firstMatch.tap()
        let forms = app.buttons["word-forms"]
        XCTAssertTrue(forms.isEnabled)
        forms.tap()
        XCTAssertTrue(app.buttons["word-form-past"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Preview wanted"].exists)
        let pickerScreenshot = XCTAttachment(screenshot: app.screenshot())
        pickerScreenshot.name = "English word form picker"
        pickerScreenshot.lifetime = .keepAlways
        add(pickerScreenshot)
        app.buttons["word-form-past"].tap()
        XCTAssertTrue(app.staticTexts["Message: wanted"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Message: wanted"].waitForExistence(timeout: 5))
        app.buttons["word-forms"].tap()
        XCTAssertTrue(app.buttons["word-form-ongoing"].waitForExistence(timeout: 5))
        app.buttons["word-form-ongoing"].tap()
        XCTAssertTrue(app.staticTexts["Message: wanting"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "English picture word form in message"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testBoardOnlyModeRequiresPINToReturnToEditing() {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["board-only-unlock"].exists {
            app.buttons["board-only-unlock"].tap()
            let existingPIN = app.secureTextFields["board-only-unlock-pin"]
            existingPIN.tap()
            existingPIN.typeText("4829")
            let existingDoneTyping = app.buttons["board-only-unlock-keyboard-done"]
            if existingDoneTyping.exists { existingDoneTyping.tap() }
            app.buttons["board-only-leave"].tap()
            XCTAssertTrue(app.buttons["Settings"].firstMatch.waitForExistence(timeout: 5))
        }
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["board-only-setup"].tap()
        let newPIN = app.secureTextFields["board-only-new-pin"]
        XCTAssertTrue(newPIN.waitForExistence(timeout: 5))
        newPIN.tap()
        newPIN.typeText("4829")
        let confirmation = app.secureTextFields["board-only-confirm-pin"]
        confirmation.tap()
        confirmation.typeText("4829")
        let doneTyping = app.buttons["board-only-keyboard-done"]
        if doneTyping.exists { doneTyping.tap() }
        app.buttons["board-only-start"].tap()

        let unlock = app.buttons["board-only-unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Settings"].exists)
        XCTAssertFalse(app.buttons["Customize"].exists)
        let clear = app.buttons["Clear message"]
        if clear.isEnabled { clear.tap() }
        app.buttons["Core"].tap()
        app.buttons["want"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Message: want"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Board-only communication mode"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Choice boards"].tap()
        XCTAssertFalse(app.buttons["New board"].isEnabled)
        app.navigationBars["Choice boards"].buttons["Done"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["board-only-unlock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Settings"].exists)
        app.buttons["board-only-unlock"].tap()
        let pin = app.secureTextFields["board-only-unlock-pin"]
        pin.tap()
        pin.typeText("0000")
        let unlockDoneTyping = app.buttons["board-only-unlock-keyboard-done"]
        if unlockDoneTyping.exists { unlockDoneTyping.tap() }
        app.buttons["board-only-leave"].tap()
        XCTAssertTrue(app.staticTexts["That PIN did not match. Try again."].waitForExistence(timeout: 5))
        pin.tap()
        pin.typeText("4829")
        if unlockDoneTyping.exists { unlockDoneTyping.tap() }
        app.buttons["board-only-leave"].tap()
        XCTAssertTrue(app.buttons["Settings"].firstMatch.waitForExistence(timeout: 5))
    }
    @MainActor
    func testSeveralButtonsCanBePreviewedAndAdded() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Add several buttons"].tap()

        XCTAssertTrue(app.navigationBars["Add several buttons"].waitForExistence(timeout: 5))
        let board = app.buttons["bulk-board"].label.replacingOccurrences(of: "Board, ", with: "")
        let input = app.textViews["bulk-words-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let suffix = UUID().uuidString.prefix(6)
        input.tap()
        input.typeText("Zuniper\(suffix), Zapper\(suffix), Zuniper\(suffix)")
        let add = app.buttons["bulk-add-buttons"]
        XCTAssertTrue(add.isEnabled)
        XCTAssertEqual(add.label, "Add 2")
        add.tap()
        XCTAssertTrue(app.alerts["2 buttons added to \(board)"].waitForExistence(timeout: 5))
        app.alerts.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Add several buttons"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testQuickBoardCanBeReviewedAndCreated() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let quick = app.buttons["board-quick-create"]
        for _ in 0..<8 where !quick.exists { app.swipeUp() }
        XCTAssertTrue(quick.waitForExistence(timeout: 5))
        quick.tap()
        XCTAssertTrue(app.navigationBars["Make a quick board"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["bulk-record-buttons"].exists)
        let suffix = UUID().uuidString.prefix(6)
        let name = "Quick needs \(suffix)"
        let boardName = app.textFields["bulk-new-board-name"]
        boardName.tap()
        boardName.typeText(name)
        let input = app.textViews["bulk-words-input"]
        input.tap()
        input.typeText("Water \(suffix)\nI need a break \(suffix)")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Quick board review"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let add = app.buttons["bulk-add-buttons"]
        XCTAssertTrue(add.isEnabled)
        XCTAssertEqual(add.label, "Add 2")
        add.tap()
        XCTAssertTrue(app.alerts["2 buttons added to \(name)"].waitForExistence(timeout: 5))
        app.alerts.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["board-appearance-\(name)"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPinnedBoardStaysAvailableWhileBrowsingBoards() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].waitForExistence(timeout: 5))
        let pin = app.buttons["pin-board-Needs"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        if pin.value as? String != "Pinned" { pin.tap() }
        XCTAssertEqual(pin.value as? String, "Pinned")
        app.navigationBars["Boards"].buttons["Done"].tap()

        let pinned = app.buttons["pinned-board-Needs"]
        XCTAssertTrue(pinned.waitForExistence(timeout: 5))
        app.scrollViews["board-tabs"].swipeLeft()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pinned board above scrolled board list"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        pinned.tap()
        if app.buttons["Explore all"].exists { app.buttons["Explore all"].tap() }
        XCTAssertTrue(app.buttons["water"].firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        XCTAssertTrue(app.buttons["pinned-board-Needs"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBoardIconAndVisibilityCanBeEdited() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        app.buttons["board-appearance-Needs"].tap()
        XCTAssertTrue(app.navigationBars["Needs"].waitForExistence(timeout: 5))
        let icon = app.textFields["board-icon-input"]
        icon.tap()
        icon.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "★")
        let visible = app.switches["board-visible-toggle"]
        let initialVisibility = String(describing: visible.value ?? "")
        visible.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertNotEqual(String(describing: visible.value ?? ""), initialVisibility)
        app.buttons["board-appearance-save"].tap()
        XCTAssertTrue(app.buttons["board-appearance-Needs"].label.contains("Hidden from board bar"))
        app.navigationBars["Boards"].buttons["Done"].tap()
        XCTAssertFalse(app.scrollViews["board-tabs"].buttons["Needs"].exists)
        XCTAssertFalse(app.buttons["pinned-board-Needs"].exists)

        app.buttons["open-word-finder"].tap()
        let query = app.textFields["finder-query"]
        query.tap()
        query.typeText("water")
        app.buttons["finder-result-Needs-water"].tap()
        XCTAssertTrue(app.staticTexts["Step 2: Select water"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["water"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["end-word-finder"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        app.buttons["board-appearance-Needs"].tap()
        XCTAssertEqual(app.textFields["board-icon-input"].value as? String, "★")
        app.switches["board-visible-toggle"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["board-appearance-save"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()
        XCTAssertTrue(app.scrollViews["board-tabs"].buttons["Needs"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBoardCanHidePictureLabelsWhileKeepingAccessibleNames() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let appearance = app.buttons["board-appearance-Core"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        appearance.tap()
        let labels = app.switches["board-tile-labels-toggle"]
        XCTAssertTrue(labels.waitForExistence(timeout: 5))
        if labels.value as? String != "0" {
            labels.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(labels.value as? String, "0")
        app.buttons["board-appearance-save"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()
        let core = app.scrollViews["board-tabs"].buttons["Core"]
        XCTAssertTrue(core.waitForExistence(timeout: 5))
        core.tap()
        let want = app.buttons["want"].firstMatch
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        XCTAssertEqual(want.label, "want")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Core board without visible picture labels"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.terminate()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let savedAppearance = app.buttons["board-appearance-Core"]
        XCTAssertTrue(savedAppearance.waitForExistence(timeout: 5))
        savedAppearance.tap()
        let savedLabels = app.switches["board-tile-labels-toggle"]
        XCTAssertEqual(savedLabels.value as? String, "0")
        savedLabels.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["board-appearance-save"].tap()
    }

    @MainActor
    func testBoardOrderCanBeChangedAndPersists() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        XCTAssertTrue(app.staticTexts["Boards in navigation order"].waitForExistence(timeout: 5))
        let core = app.buttons["board-appearance-Core"]
        let needs = app.buttons["board-appearance-Needs"]
        XCTAssertTrue(core.waitForExistence(timeout: 5))
        XCTAssertTrue(needs.waitForExistence(timeout: 5))
        let first = core.frame.minY < needs.frame.minY ? "Core" : "Needs"
        let second = first == "Core" ? "Needs" : "Core"
        app.buttons["board-options-\(second)"].tap()
        app.buttons["Move \(second) up"].tap()
        XCTAssertLessThan(app.buttons["board-appearance-\(second)"].frame.minY,
                          app.buttons["board-appearance-\(first)"].frame.minY)
        app.navigationBars["Boards"].buttons["Done"].tap()
        app.terminate()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        XCTAssertLessThan(app.buttons["board-appearance-\(second)"].frame.minY,
                          app.buttons["board-appearance-\(first)"].frame.minY)
        app.buttons["board-options-\(second)"].tap()
        app.buttons["Move \(second) down"].tap()
        XCTAssertLessThan(app.buttons["board-appearance-\(first)"].frame.minY,
                          app.buttons["board-appearance-\(second)"].frame.minY)
    }

    @MainActor
    func testPictureBoardFolderCanOpenItsBoardWithoutChangingBoardBar() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        app.buttons["add-board-folder"].tap()
        let name = app.alerts["New folder"].textFields["Folder name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Everyday")
        app.alerts["New folder"].buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Everyday"].waitForExistence(timeout: 5))
        let boardOptions = app.descendants(matching: .any)["board-options-Needs"].firstMatch
        for _ in 0..<6 where !boardOptions.exists { app.swipeUp() }
        XCTAssertTrue(boardOptions.waitForExistence(timeout: 5))
        boardOptions.tap()
        app.descendants(matching: .any)["assign-board-folder-Needs"].firstMatch.tap()
        app.buttons["Everyday"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()

        let boardBar = app.scrollViews["board-tabs"]
        XCTAssertTrue(boardBar.buttons["Needs"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["board-folder-navigation"].firstMatch.tap()
        app.buttons["Everyday"].tap()
        app.collectionViews.buttons["Needs"].firstMatch.tap()
        XCTAssertTrue(app.buttons["water"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPaintModeColorsSeveralButtonsWithoutSpeaking() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Paint buttons"].tap()
        XCTAssertTrue(app.navigationBars["Paint buttons"].waitForExistence(timeout: 5))
        let want = app.buttons["paint-button-Core-want"]
        let need = app.buttons["paint-button-Core-need"]
        XCTAssertTrue(want.waitForExistence(timeout: 5))
        XCTAssertTrue(need.waitForExistence(timeout: 5))
        let priorNeedColor = String(describing: need.value ?? "")
        let priorWantColor = String(describing: want.value ?? "")
        app.buttons["paint-board-Needs"].tap()
        let water = app.buttons["paint-button-Needs-water"]
        XCTAssertTrue(water.waitForExistence(timeout: 5))
        let priorWaterColor = String(describing: water.value ?? "")
        app.buttons["paint-board-Core"].tap()
        let currentColors = Set([priorWantColor, priorNeedColor, priorWaterColor])
        let palette = [("Mint", "#BFE9D1"), ("Coral", "#FFB7A8"),
                       ("Lavender", "#D9CBF5"), ("Sky", "#B7DFFD")]
        let paintColor = palette.first { !currentColors.contains($0.1) } ?? palette[0]
        app.buttons["paint-swatch-\(paintColor.0)"].tap()
        want.tap()
        need.tap()
        XCTAssertEqual(want.value as? String, paintColor.1)
        XCTAssertEqual(need.value as? String, paintColor.1)
        XCTAssertEqual(app.staticTexts["paint-count"].label, "2 changed")
        XCTAssertFalse(app.staticTexts["Message: want"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Paint mode with two colored words"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["paint-undo"].tap()
        XCTAssertEqual(String(describing: need.value ?? ""), priorNeedColor)
        XCTAssertEqual(app.staticTexts["paint-count"].label, "1 changed")
        app.buttons["paint-board-Needs"].tap()
        XCTAssertTrue(water.waitForExistence(timeout: 5))
        water.tap()
        XCTAssertEqual(water.value as? String, paintColor.1)
        app.navigationBars["Paint buttons"].buttons["Done"].tap()

        app.terminate()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Paint buttons"].tap()
        XCTAssertEqual(app.buttons["paint-button-Core-want"].value as? String, paintColor.1)
        app.buttons["paint-board-Needs"].tap()
        XCTAssertEqual(app.buttons["paint-button-Needs-water"].value as? String, paintColor.1)
        XCTAssertTrue(app.buttons["paint-swatch-default"].exists)
        XCTAssertTrue(app.buttons["paint-use-custom"].exists)
        app.buttons["paint-swatch-Mint"].press(forDuration: 1.2)
        app.buttons["Lighter Mint"].tap()
        XCTAssertEqual(app.staticTexts["paint-selected-color"].label, "Selected: Lighter Mint")
        app.buttons["paint-board-Core"].tap()
        app.buttons["paint-button-Core-need"].tap()
        XCTAssertEqual(app.buttons["paint-button-Core-need"].value as? String, "#DCF3E6")
    }

    @MainActor
    func testReadyMadePageCanBeAddedWithSpanishWords() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Switch profile"].tap()
        let profileName = "Library test \(UUID().uuidString.prefix(6))"
        app.buttons["Add profile"].tap()
        let profileField = app.alerts["New profile"].textFields["Profile name"]
        profileField.tap()
        profileField.typeText(profileName)
        app.alerts.buttons["Create"].tap()
        app.navigationBars["Profiles"].buttons["Done"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let browse = app.buttons["browse-board-library"]
        for _ in 0..<12 where !browse.isHittable { app.swipeUp() }
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        browse.tap()
        XCTAssertTrue(app.navigationBars["Page library"].waitForExistence(timeout: 5))
        let school = app.buttons["library-page-school"]
        for _ in 0..<8 where !school.isHittable { app.swipeUp() }
        XCTAssertTrue(school.waitForExistence(timeout: 5))
        school.tap()
        XCTAssertTrue(app.navigationBars["At school"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Necesito ayuda"].exists)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Ready-made school page preview"
        preview.lifetime = .keepAlways
        add(preview)
        let addPage = app.buttons["library-add-page"]
        XCTAssertTrue(addPage.isEnabled)
        addPage.tap()
        XCTAssertTrue(app.alerts["Page added"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Added 12 buttons to At school."].exists)
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(addPage.isEnabled)
        app.navigationBars["At school"].buttons.firstMatch.tap()
        app.navigationBars["Page library"].buttons["Done"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()

        app.buttons["board-language"].tap()
        app.buttons["Español"].tap()
        let search = app.searchFields["Find a word"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Necesito ayuda")
        XCTAssertTrue(app.buttons["Necesito ayuda"].firstMatch.waitForExistence(timeout: 5))
        let added = XCTAttachment(screenshot: app.screenshot())
        added.name = "Library word available in Spanish"
        added.lifetime = .keepAlways
        add(added)

        app.terminate()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let addedBoard = app.buttons["board-appearance-At school"]
        for _ in 0..<12 where !addedBoard.isHittable { app.swipeUp() }
        XCTAssertTrue(addedBoard.waitForExistence(timeout: 5))
        app.navigationBars["Boards"].buttons["Done"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Switch profile"].tap()
        app.buttons["Options for \(profileName)"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete profile"].tap()
        app.navigationBars["Profiles"].buttons["Done"].tap()
    }

    @MainActor
    func testNewSensoryPageIsReachableWithEnglishAndSpanishPreview() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let browse = app.buttons["browse-board-library"]
        for _ in 0..<12 where !browse.isHittable { app.swipeUp() }
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        browse.tap()
        XCTAssertTrue(app.navigationBars["Page library"].waitForExistence(timeout: 5))
        let search = app.searchFields["Find a page or phrase"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("La luz es demasiado fuerte")
        let sensory = app.buttons["library-page-sensory-needs"]
        XCTAssertTrue(sensory.waitForExistence(timeout: 5))
        sensory.tap()
        XCTAssertTrue(app.navigationBars["Sensory needs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["The light is too bright"].exists)
        XCTAssertTrue(app.staticTexts["La luz es demasiado fuerte"].exists)
        XCTAssertTrue(app.buttons["library-add-page"].exists)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Bilingual sensory needs page"
        preview.lifetime = .keepAlways
        add(preview)
    }

    @MainActor
    func testSetupTemplateCreatesSeparateProfileWithIncludedPages() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let browse = app.buttons["browse-board-library"]
        for _ in 0..<12 where !browse.isHittable { app.swipeUp() }
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        browse.tap()

        let template = app.buttons["library-template-school-day"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
        XCTAssertTrue(app.navigationBars["School day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["At school"].exists)
        XCTAssertTrue(app.staticTexts["Conversation"].exists)
        let nameField = app.textFields["library-template-profile-name"]
        nameField.tap()
        let suffix = String(UUID().uuidString.prefix(6))
        nameField.typeText(" \(suffix)")
        let profileName = nameField.value as? String ?? ""
        XCTAssertTrue(profileName.contains(suffix))
        app.buttons["library-create-template-profile"].tap()
        XCTAssertTrue(app.alerts["Profile created"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Added 4 pages and 48 buttons to \(profileName)."].exists)
        app.alerts.buttons["OK"].tap()
        app.navigationBars["Page library"].buttons["Done"].tap()
        let addedBoard = app.buttons["board-appearance-At school"]
        for _ in 0..<12 where !addedBoard.isHittable { app.swipeUp() }
        XCTAssertTrue(addedBoard.waitForExistence(timeout: 5))
        app.navigationBars["Boards"].buttons["Done"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Switch profile"].tap()
        XCTAssertTrue(app.staticTexts[profileName].waitForExistence(timeout: 5))
        app.buttons["Options for \(profileName)"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete profile"].tap()
        app.navigationBars["Profiles"].buttons["Done"].tap()
    }

    @MainActor
    func testTemplateCanKeepOrReplacePersonalBoardsWithBackups() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Switch profile"].tap()
        let profileName = "Apply template \(UUID().uuidString.prefix(6))"
        app.buttons["Add profile"].tap()
        let profileField = app.alerts["New profile"].textFields["Profile name"]
        profileField.tap()
        profileField.typeText(profileName)
        app.alerts.buttons["Create"].tap()
        app.navigationBars["Profiles"].buttons["Done"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        app.buttons["Add board"].tap()
        let boardName = "My template board"
        let boardField = app.alerts["New board"].textFields["Board name"]
        boardField.tap()
        boardField.typeText(boardName)
        app.alerts.buttons["Create"].tap()
        let browse = app.buttons["browse-board-library"]
        for _ in 0..<12 where !browse.isHittable { app.swipeUp() }
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        browse.tap()
        app.buttons["library-template-school-day"].tap()
        let apply = app.buttons["library-apply-template"]
        for _ in 0..<8 where !apply.isHittable { app.swipeUp() }
        apply.tap()
        XCTAssertTrue(app.buttons["Keep personal boards"].waitForExistence(timeout: 5))
        app.buttons["Keep personal boards"].tap()
        XCTAssertTrue(app.alerts["Template applied"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Removed 0 personal boards")).firstMatch.exists)
        app.alerts.buttons["OK"].tap()
        app.navigationBars["Page library"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["board-appearance-\(boardName)"].exists)

        for _ in 0..<12 where !browse.isHittable { app.swipeUp() }
        browse.tap()
        app.buttons["library-template-school-day"].tap()
        let applyAgain = app.buttons["library-apply-template"]
        for _ in 0..<8 where !applyAgain.isHittable { app.swipeUp() }
        applyAgain.tap()
        XCTAssertTrue(app.buttons["Replace personal boards"].waitForExistence(timeout: 5))
        app.buttons["Replace personal boards"].tap()
        XCTAssertTrue(app.alerts["Template applied"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Removed 5 personal boards")).firstMatch.exists)
        app.alerts.buttons["OK"].tap()
        app.navigationBars["Page library"].buttons["Done"].tap()
        XCTAssertFalse(app.buttons["board-appearance-\(boardName)"].exists)
        let schoolBoard = app.buttons["board-appearance-At school"]
        for _ in 0..<12 where !schoolBoard.exists { app.swipeDown() }
        XCTAssertTrue(schoolBoard.waitForExistence(timeout: 5))
        app.navigationBars["Boards"].buttons["Done"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Switch profile"].tap()
        app.buttons["Options for \(profileName)"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete profile"].tap()
        app.navigationBars["Profiles"].buttons["Done"].tap()
    }

    @MainActor
    func testPageQRCodeCanBeCopiedAndImportedToAnotherProfile() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let options = app.buttons["board-options-Needs"]
        for _ in 0..<12 where !options.isHittable { app.swipeUp() }
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        app.buttons["Share page QR"].tap()
        XCTAssertTrue(app.navigationBars["Share page QR"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["page-qr-image"].waitForExistence(timeout: 5))
        app.buttons["copy-page-qr-code"].tap()
        app.navigationBars["Share page QR"].buttons["Done"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Switch profile"].tap()
        let profileName = "QR test \(UUID().uuidString.prefix(6))"
        app.buttons["Add profile"].tap()
        let profileField = app.alerts["New profile"].textFields["Profile name"]
        profileField.tap()
        profileField.typeText(profileName)
        app.alerts.buttons["Create"].tap()
        app.navigationBars["Profiles"].buttons["Done"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let importQR = app.buttons["import-page-qr"]
        for _ in 0..<12 where !importQR.isHittable { app.swipeUp() }
        XCTAssertTrue(importQR.waitForExistence(timeout: 5))
        importQR.tap()
        XCTAssertTrue(app.navigationBars["Import page QR"].waitForExistence(timeout: 5))
        app.buttons["paste-page-qr-code"].tap()
        XCTAssertTrue(app.buttons["add-imported-qr-page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Board, Needs"].exists)
        app.buttons["add-imported-qr-page"].tap()
        XCTAssertTrue(app.alerts["Page added"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Added Needs (imported 2) to \(profileName)."].exists)
        app.alerts.buttons["OK"].tap()
        let copiedBoard = app.buttons["board-appearance-Needs (imported 2)"]
        for _ in 0..<12 where !copiedBoard.exists { app.swipeUp() }
        XCTAssertTrue(copiedBoard.waitForExistence(timeout: 5))
        app.navigationBars["Boards"].buttons["Done"].tap()

        app.buttons["Customize"].tap()
        app.buttons["Switch profile"].tap()
        app.buttons["Options for \(profileName)"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete profile"].tap()
        app.navigationBars["Profiles"].buttons["Done"].tap()
    }

    @MainActor
    func testPageQRImageCanBeSelectedFromPhotos() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Speak"].firstMatch.tap()
        app.buttons["Customize"].tap()
        app.buttons["Manage boards"].tap()
        let importQR = app.buttons["import-page-qr"]
        for _ in 0..<12 where !importQR.isHittable { app.swipeUp() }
        importQR.tap()
        app.buttons["import-page-qr-image"].tap()
        let firstPhoto = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 20))
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
        firstPhoto.tap()
        if app.navigationBars["Photos"].exists, app.buttons["Add"].exists {
            app.buttons["Add"].tap()
        }
        XCTAssertTrue(app.buttons["add-imported-qr-page"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Board, Needs"].exists)
        app.navigationBars["Import page QR"].buttons["Done"].tap()
        app.navigationBars["Boards"].buttons["Done"].tap()
    }

    @MainActor
    func testBackupImportEntryIsAvailableInSettings() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let importer = app.buttons["Import into current profile"]
        for _ in 0..<16 {
            if importer.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(importer.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Export current profile"].exists)
    }

    @MainActor
    func testLocalBackupCanAddSelectedBoard() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        let localBackups = app.buttons["open-local-backups"]
        for _ in 0..<16 {
            if localBackups.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(localBackups.waitForExistence(timeout: 5))
        localBackups.tap()
        XCTAssertTrue(app.navigationBars["Local backups"].waitForExistence(timeout: 5))
        app.buttons["create-local-backup"].tap()
        let alert = app.alerts["New local backup"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let name = alert.textFields["Backup name"]
        name.tap()
        name.typeText("Before import \(UUID().uuidString.prefix(6))")
        alert.buttons["Create"].tap()
        let saved = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "open-local-backup-")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertTrue(app.navigationBars["Import backup"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Local backup selected-board chooser"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let core = app.switches["backup-select-Core"]
        XCTAssertTrue(core.waitForExistence(timeout: 5))
        core.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Import backup"].exists)
        XCTAssertEqual(core.value as? String, "1")
        let addSelected = app.buttons["backup-add-selected"]
        XCTAssertTrue(addSelected.waitForExistence(timeout: 5))
        addSelected.tap()
        XCTAssertTrue(app.alerts["Added 1 boards"].waitForExistence(timeout: 5))
        app.alerts.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Local backups"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSavedPhraseCanOpenLinkedFolder() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Phrases"].firstMatch.tap()
        let unique = String(UUID().uuidString.prefix(6))
        let folder = "Linked \(unique)"
        let targetText = "Target \(unique)"
        let linkText = "Open linked \(unique)"
        let phraseField = app.descendants(matching: .any)["A phrase you use often"].firstMatch
        for _ in 0..<10 where !phraseField.isHittable { app.swipeUp() }
        XCTAssertTrue(phraseField.isHittable)
        phraseField.tap()
        phraseField.typeText(targetText)
        let folderField = app.textFields["Folder (optional)"]
        folderField.tap()
        folderField.typeText(folder)
        let save = app.buttons["Save phrase"]
        for _ in 0..<10 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()

        for _ in 0..<5 where !phraseField.isHittable { app.swipeDown() }
        phraseField.tap()
        phraseField.typeText(linkText)
        let picker = app.descendants(matching: .any)["new-phrase-folder-link"].firstMatch
        for _ in 0..<5 where !picker.isHittable { app.swipeUp() }
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        let destination = app.buttons[folder].firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()
        for _ in 0..<10 where !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isHittable)
        save.tap()

        let link = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", linkText)).firstMatch
        for _ in 0..<12 where !link.isHittable { app.swipeDown() }
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.navigationBars["Phrase cards"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["phrase-card-current-folder"].label, folder)
        XCTAssertTrue(app.buttons[targetText].exists)
    }

    @MainActor
    func testARASAACPictogramCanBeAddedToPersonalButton() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Customize"].tap()
        app.buttons["Add button"].tap()
        let label = app.textFields["Button label"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText("water")
        let search = app.buttons["button-search-arasaac"]
        for _ in 0..<10 where !search.isHittable { app.swipeUp() }
        XCTAssertTrue(search.isHittable)
        search.tap()
        XCTAssertTrue(app.navigationBars["ARASAAC pictograms"].waitForExistence(timeout: 5))
        let result = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "arasaac-result-")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        result.tap()
        let attribution = app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "Pictograms: Sergio Palao")).firstMatch
        XCTAssertTrue(attribution.waitForExistence(timeout: 20))
        app.buttons["Save"].tap()
        XCTAssertFalse(app.navigationBars["Add button"].waitForExistence(timeout: 3))
    }
}
