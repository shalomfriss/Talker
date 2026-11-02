import SwiftUI
import UIKit

@main
struct OpenVoiceApp: App {
    @UIApplicationDelegateAdaptor(RoutineReminderAppDelegate.self) private var reminderDelegate
    @StateObject private var store: CommunicationStore
    @StateObject private var nearbyChat: NearbyChatService
    @StateObject private var callAudio = CallAudioManager()

    init() {
        let initial = CommunicationStore()
#if DEBUG
        let largeBoardFixture = ProcessInfo.processInfo.arguments.contains("-ui-test-large-board-startup") ||
            ProcessInfo.processInfo.arguments.contains("-ui-test-large-board-scan")
        let largeBoardProfileName = "Large board UI test"
        if largeBoardFixture {
            if let profile = initial.profiles.first(where: { $0.name == largeBoardProfileName }) {
                _ = initial.switchProfile(to: profile.id)
            } else {
                _ = initial.addProfile(largeBoardProfileName)
            }
            if !initial.items.contains(where: { $0.label == "Load test word 1" }) {
                let entries = (1...1_000).map { index in
                    BulkVocabularyEntry(label: "Load test word \(index)", symbol: "💬", message: "Load test word \(index)")
                }
                _ = initial.addBulkItems(entries, to: "Core")
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-large-board-scan") {
            initial.settings.scanEnabled = true
            initial.settings.scanMode = .step
            initial.settings.scanCueMode = .off
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-large-board-cleanup") {
            for profile in initial.profiles where profile.name == largeBoardProfileName {
                _ = initial.deleteProfile(id: profile.id)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-reward-chart") {
            for chart in initial.rewardCharts { _ = initial.deleteRewardChart(id: chart.id) }
            for record in initial.rewardCollectibles { _ = initial.deleteRewardCollectible(id: record.id) }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-routine-reward") {
            for chart in initial.rewardCharts { _ = initial.deleteRewardChart(id: chart.id) }
            for template in initial.routineTemplates where template.name == "Reward routine test" {
                initial.deleteRoutineTemplate(id: template.id)
            }
            for step in initial.routines { initial.deleteRoutineStep(step) }
            initial.addRoutineStep("Finish a step", symbol: "✅")
            _ = initial.saveRoutineTemplate(name: "Reward routine test")
            _ = initial.addRewardChart(title: "Routine stars", reward: "Choose music", targetTokens: 2)
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-routine-choice") {
            initial.settings.choiceBoardEditingLocked = false
            for step in initial.routines { initial.deleteRoutineStep(step) }
            for template in initial.routineTemplates where template.name == "Choice routine test" {
                initial.deleteRoutineTemplate(id: template.id)
            }
            for board in initial.choiceBoards where board.title == "Bus choices" {
                initial.deleteChoiceBoard(id: board.id)
            }
            let board = ChoiceBoard(title: "Bus choices", options: [
                ChoiceOption(label: "Window seat", symbol: "🪟"),
                ChoiceOption(label: "Aisle seat", symbol: "🚌")
            ])
            _ = initial.saveChoiceBoard(board)
            _ = initial.saveRoutineStep(RoutineStep(title: "Choose a seat", symbol: "🚌",
                choiceBoardID: board.id))
            initial.addRoutineStep("Sit down", symbol: "🪑")
            _ = initial.saveRoutineTemplate(name: "Choice routine test")
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-choice-scan") ||
           ProcessInfo.processInfo.arguments.contains("-ui-test-choice-scan-auto") {
            initial.settings.scanEnabled = true
            initial.settings.scanMode = ProcessInfo.processInfo.arguments.contains("-ui-test-choice-scan-auto")
                ? .automatic : .step
            initial.settings.scanInterval = 3
            initial.settings.scanCueMode = .off
            for board in initial.choiceBoards where board.title == "Choice scan test" {
                initial.deleteChoiceBoard(id: board.id)
            }
            _ = initial.saveChoiceBoard(ChoiceBoard(title: "Choice scan test", options: [
                ChoiceOption(label: "Tea", symbol: "🫖"),
                ChoiceOption(label: "Water", symbol: "💧")
            ]))
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-bedside-scan") ||
           ProcessInfo.processInfo.arguments.contains("-ui-test-bedside-scan-auto") {
            initial.settings.communicationLanguage = "en"
            initial.settings.scanEnabled = true
            initial.settings.scanMode = ProcessInfo.processInfo.arguments.contains("-ui-test-bedside-scan-auto")
                ? .automatic : .step
            initial.settings.scanInterval = 3
            initial.settings.scanCueMode = .off
            initial.settings.setBedsideCards(BedsideCard.starterCards(language: "en"), language: "en")
        }
        let urgentBarProfileName = "Urgent bar UI test"
        if ProcessInfo.processInfo.arguments.contains("-ui-test-urgent-bar") ||
           ProcessInfo.processInfo.arguments.contains("-ui-test-urgent-bar-board-only") {
            if let profile = initial.profiles.first(where: { $0.name == urgentBarProfileName }) {
                _ = initial.switchProfile(to: profile.id)
            } else {
                _ = initial.addProfile(urgentBarProfileName)
            }
            initial.settings.communicationLanguage = "en"
            initial.settings.showUrgentBar = true
            initial.settings.saveHistory = true
            initial.clearHistory()
            initial.clearMessage()
            initial.settings.setBedsideCards([
                BedsideCard(symbol: "⭐", label: "My helper", message: "Please ask my helper."),
                BedsideCard(symbol: "🫁", label: "Breathing", message: "I am having trouble breathing.")
            ], language: "en")
            if ProcessInfo.processInfo.arguments.contains("-ui-test-urgent-bar-board-only") {
                try? initial.startBoardOnlyMode(pin: "1234")
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-urgent-bar-cleanup") {
            if initial.isBoardOnlyModeActive { initial.leaveBoardOnlyModeAfterDeviceAuthentication() }
            for profile in initial.profiles where profile.name == urgentBarProfileName {
                _ = initial.deleteProfile(id: profile.id)
            }
        }
        let recentPhraseProfileName = "Recent phrases UI test"
        if ProcessInfo.processInfo.arguments.contains("-ui-test-recent-phrases") {
            if let profile = initial.profiles.first(where: { $0.name == recentPhraseProfileName }) {
                _ = initial.switchProfile(to: profile.id)
            } else {
                _ = initial.addProfile(recentPhraseProfileName)
            }
            initial.settings.recentPhrasesEnabled = true
            initial.settings.phraseTapAction = .speak
            initial.clearRecentPhrases()
            initial.addPhrase("Please give me time.")
            initial.addPhrase("Could we talk later?", folder: "Social")
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-recent-phrases-cleanup") {
            for profile in initial.profiles where profile.name == recentPhraseProfileName {
                _ = initial.deleteProfile(id: profile.id)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-calm-scan") ||
           ProcessInfo.processInfo.arguments.contains("-ui-test-calm-scan-auto") {
            initial.settings.communicationLanguage = "en"
            initial.settings.scanEnabled = true
            initial.settings.scanMode = ProcessInfo.processInfo.arguments.contains("-ui-test-calm-scan-auto")
                ? .automatic : .step
            initial.settings.scanInterval = 3
            initial.settings.scanCueMode = .off
        }
        let painScanProfileName = "Pain scan UI test"
        if ProcessInfo.processInfo.arguments.contains("-ui-test-pain-scan") ||
           ProcessInfo.processInfo.arguments.contains("-ui-test-pain-scan-auto") {
            if let profile = initial.profiles.first(where: { $0.name == painScanProfileName }) {
                _ = initial.switchProfile(to: profile.id)
            } else {
                _ = initial.addProfile(painScanProfileName)
            }
            initial.settings.communicationLanguage = "en"
            initial.settings.scanEnabled = true
            initial.settings.scanMode = ProcessInfo.processInfo.arguments.contains("-ui-test-pain-scan-auto")
                ? .automatic : .step
            initial.settings.scanInterval = 3
            initial.settings.scanCueMode = .off
            initial.settings.painScaleMaximum = 5
            initial.settings.saveFeelingsLog = true
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-pain-scan-cleanup") {
            for profile in initial.profiles where profile.name == painScanProfileName {
                _ = initial.deleteProfile(id: profile.id)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-pain-touch") {
            initial.settings.saveFeelingsLog = false
            initial.settings.scanEnabled = false
        }
        let feelingScanProfileName = "Feeling scan UI test"
        if ProcessInfo.processInfo.arguments.contains("-ui-test-feeling-scan") ||
           ProcessInfo.processInfo.arguments.contains("-ui-test-feeling-scan-auto") {
            if let profile = initial.profiles.first(where: { $0.name == feelingScanProfileName }) {
                _ = initial.switchProfile(to: profile.id)
            } else {
                _ = initial.addProfile(feelingScanProfileName)
            }
            initial.settings.communicationLanguage = "en"
            initial.settings.scanEnabled = true
            initial.settings.scanMode = ProcessInfo.processInfo.arguments.contains("-ui-test-feeling-scan-auto")
                ? .automatic : .step
            initial.settings.scanInterval = 3
            initial.settings.scanCueMode = .off
            initial.settings.saveFeelingsLog = true
            initial.clearFeelingsLog()
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-feeling-scan-cleanup") {
            for profile in initial.profiles where profile.name == feelingScanProfileName {
                _ = initial.deleteProfile(id: profile.id)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-routine-video"),
           let url = Bundle.main.url(forResource: "SceneSample", withExtension: "mov"),
           let video = try? Data(contentsOf: url) {
            for step in initial.routines { initial.deleteRoutineStep(step) }
            for template in initial.routineTemplates where template.name == "Video routine test" {
                initial.deleteRoutineTemplate(id: template.id)
            }
            _ = initial.saveRoutineStep(RoutineStep(title: "Watch the bus", symbol: "🚌",
                videoData: video, videoPosterData: Self.literacyTestScene.imageData))
            initial.addRoutineStep("Get on the bus", symbol: "🚍")
            _ = initial.saveRoutineTemplate(name: "Video routine test")
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-story-video"),
           let url = Bundle.main.url(forResource: "SceneSample", withExtension: "mov"),
           let video = try? Data(contentsOf: url) {
            for story in initial.stories where story.title == "Story video test" {
                initial.deleteStory(id: story.id)
            }
            if let storyID = initial.addStory("Story video test") {
                initial.addStoryPage(storyID: storyID, text: "I can watch this happen.",
                                     symbol: "▶️", imageData: nil, videoData: video,
                                     videoPosterData: Self.literacyTestScene.imageData)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-story-photo-grid") {
            for story in initial.stories where story.title == "Photo grid story test" {
                initial.deleteStory(id: story.id)
            }
            func photo(_ color: UIColor) -> Data? {
                UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { context in
                    color.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
                }.jpegData(compressionQuality: 0.8)
            }
            if let storyID = initial.addStory("Photo grid story test"),
               let first = photo(.systemOrange), let second = photo(.systemBlue) {
                initial.addStoryPage(storyID: storyID, text: "I can show two places.",
                                     symbol: "🖼️", imageData: first,
                                     additionalImageData: [second])
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-story-background") {
            for story in initial.stories where story.title == "Background story test" {
                initial.deleteStory(id: story.id)
            }
            let backgroundPhoto = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 640))
                .image { context in
                    UIColor(red: 0.18, green: 0.48, blue: 0.56, alpha: 1).setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 480, height: 640))
                    UIColor(red: 0.97, green: 0.68, blue: 0.34, alpha: 1).setFill()
                    context.cgContext.fillEllipse(in: CGRect(x: 80, y: 90, width: 320, height: 320))
                }.jpegData(compressionQuality: 0.8)
            if let storyID = initial.addStory("Background story test") {
                initial.addStoryPage(storyID: storyID, text: "A gentle sky helps me feel calm.",
                                     symbol: "☁️", imageData: nil, backgroundStyle: .sky)
                initial.addStoryPage(storyID: storyID, text: "This is my quiet place.",
                                     symbol: "🌿", imageData: nil, backgroundStyle: .photo,
                                     backgroundPhotoData: backgroundPhoto)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-story-one-tap") {
            initial.settings.storyOneTapReading = false
            for story in initial.stories where story.title == "One tap story test" {
                initial.deleteStory(id: story.id)
            }
            if let storyID = initial.addStory("One tap story test") {
                initial.addStoryPage(storyID: storyID,
                                     text: "First I can tell my story about what happened today.",
                                     symbol: "📖", imageData: nil)
                initial.addStoryPage(storyID: storyID,
                                     text: "Then I can tell someone what happened next and how I feel.",
                                     symbol: "💬", imageData: nil)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-story-slideshow") {
            for story in initial.stories where story.title == "Slideshow story test" {
                initial.deleteStory(id: story.id)
            }
            if let storyID = initial.addStory("Slideshow story test"),
               let narration = ScanCueSound.wavData(for: .blip) {
                initial.addStoryPage(storyID: storyID, text: "This is the first page.",
                                     symbol: "📖", imageData: nil, audioData: narration)
                initial.addStoryPage(storyID: storyID, text: "This is the second page.",
                                     symbol: "💬", imageData: nil, audioData: narration)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-board-video"),
           let url = Bundle.main.url(forResource: "SceneSample", withExtension: "mov"),
           let video = try? Data(contentsOf: url) {
            initial.clearMessage()
            for item in initial.items where item.label == "Watch clip" && item.category == "Core" {
                initial.deleteItem(item)
            }
            initial.addItem(label: "Watch clip", symbol: "▶️", message: "Watch clip",
                            category: "Core", imageData: nil, videoData: video,
                            videoPosterData: Self.literacyTestScene.imageData, action: .playVideo)
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-scene-literacy"),
           !initial.sceneBoards.contains(where: { $0.title == Self.literacyTestScene.title }) {
            initial.saveSceneBoard(Self.literacyTestScene)
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-scene-hotspots") {
            initial.clearMessage()
            for scene in initial.sceneBoards where scene.title == "Hotspot test scene" {
                initial.deleteSceneBoard(id: scene.id)
            }
            initial.saveSceneBoard(VisualSceneBoard(title: "Hotspot test scene",
                imageData: Self.literacyTestScene.imageData,
                hotspots: [
                    SceneHotspot(option: ChoiceOption(label: "talk"), x: 0.25, y: 0.3,
                                 width: 0.3, height: 0.18, backgroundColorHex: "#315A78",
                                 behavior: .speakOnly, spokenText: "Hello there"),
                    SceneHotspot(option: ChoiceOption(label: "write"), x: 0.7, y: 0.65,
                                 showsLabel: false, behavior: .addOnly, spokenText: "Please write")
                ]))
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-video-scene"),
           let url = Bundle.main.url(forResource: "SceneSample", withExtension: "mov"),
           let video = try? Data(contentsOf: url) {
            for scene in initial.sceneBoards where scene.title == "Video test scene" {
                initial.deleteSceneBoard(id: scene.id)
            }
            initial.saveSceneBoard(VisualSceneBoard(title: "Video test scene",
                imageData: Self.literacyTestScene.imageData,
                hotspots: [SceneHotspot(option: ChoiceOption(label: "go"), x: 0.5, y: 0.5)],
                videoData: video))
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-hotspot-video"),
           let url = Bundle.main.url(forResource: "SceneSample", withExtension: "mov"),
           let video = try? Data(contentsOf: url) {
            for scene in initial.sceneBoards where scene.title == "Hotspot video test" {
                initial.deleteSceneBoard(id: scene.id)
            }
            initial.saveSceneBoard(VisualSceneBoard(title: "Hotspot video test",
                imageData: Self.literacyTestScene.imageData,
                hotspots: [SceneHotspot(option: ChoiceOption(label: "watch"), x: 0.5, y: 0.5,
                                        videoData: video,
                                        videoPosterData: Self.literacyTestScene.imageData)]))
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-hotspot-attach") {
            for scene in initial.sceneBoards where scene.title == "Attach video test" {
                initial.deleteSceneBoard(id: scene.id)
            }
            initial.saveSceneBoard(VisualSceneBoard(title: "Attach video test",
                imageData: Self.literacyTestScene.imageData,
                hotspots: [SceneHotspot(option: ChoiceOption(label: "watch"), x: 0.5, y: 0.5)]))
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-linked-scenes") {
            for scene in initial.sceneBoards where scene.title == "Linked test home" ||
                scene.title == "Linked test garden" {
                initial.deleteSceneBoard(id: scene.id)
            }
            let garden = VisualSceneBoard(title: "Linked test garden",
                                          imageData: Self.literacyTestScene.imageData,
                                          hotspots: [SceneHotspot(option: ChoiceOption(label: "flowers"),
                                                                  x: 0.45, y: 0.55)])
            let home = VisualSceneBoard(title: "Linked test home",
                                        imageData: Self.literacyTestScene.imageData,
                                        hotspots: [SceneHotspot(option: ChoiceOption(label: "garden"),
                                                                x: 0.35, y: 0.4,
                                                                destinationSceneID: garden.id)])
            initial.saveSceneBoard(garden)
            initial.saveSceneBoard(home)
        }
        let sceneScanProfileName = "Scene scan UI test"
        if ProcessInfo.processInfo.arguments.contains("-ui-test-scene-scan") ||
           ProcessInfo.processInfo.arguments.contains("-ui-test-scene-scan-auto") {
            if let profile = initial.profiles.first(where: { $0.name == sceneScanProfileName }) {
                _ = initial.switchProfile(to: profile.id)
            } else {
                _ = initial.addProfile(sceneScanProfileName)
            }
            initial.settings.communicationLanguage = "en"
            initial.settings.scanEnabled = true
            initial.settings.scanMode = ProcessInfo.processInfo.arguments.contains("-ui-test-scene-scan-auto")
                ? .automatic : .step
            initial.settings.scanInterval = 3
            initial.settings.scanCueMode = .off
            initial.settings.confirmSelection = false
            initial.clearMessage()
            for scene in initial.sceneBoards where ["Scan test home", "Scan test garden", "Scan test video"].contains(scene.title) {
                initial.deleteSceneBoard(id: scene.id)
            }
            let garden = VisualSceneBoard(title: "Scan test garden",
                imageData: Self.literacyTestScene.imageData,
                hotspots: [SceneHotspot(option: ChoiceOption(label: "flowers"), x: 0.5, y: 0.5)])
            let home = VisualSceneBoard(title: "Scan test home",
                imageData: Self.literacyTestScene.imageData,
                hotspots: [
                    SceneHotspot(option: ChoiceOption(label: "hello"), x: 0.25, y: 0.35),
                    SceneHotspot(option: ChoiceOption(label: "garden"), x: 0.7, y: 0.6,
                                 destinationSceneID: garden.id)
                ])
            initial.saveSceneBoard(garden)
            initial.saveSceneBoard(home)
            if let url = Bundle.main.url(forResource: "SceneSample", withExtension: "mov"),
               let video = try? Data(contentsOf: url) {
                initial.saveSceneBoard(VisualSceneBoard(title: "Scan test video",
                    imageData: Self.literacyTestScene.imageData,
                    hotspots: [SceneHotspot(option: ChoiceOption(label: "play"), x: 0.5, y: 0.5)],
                    videoData: video))
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-scene-scan-cleanup") {
            for profile in initial.profiles where profile.name == sceneScanProfileName {
                _ = initial.deleteProfile(id: profile.id)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-board-scene-keyboard") {
            for item in initial.items where ["Open tile scene", "Open tile keyboard"].contains(item.label) {
                initial.deleteItem(item)
            }
            for scene in initial.sceneBoards where scene.title == "Tile-linked scene" {
                initial.deleteSceneBoard(id: scene.id)
            }
            let scene = VisualSceneBoard(title: "Tile-linked scene",
                                         imageData: Self.literacyTestScene.imageData,
                                         hotspots: [SceneHotspot(option: ChoiceOption(label: "garden"),
                                                                 x: 0.5, y: 0.5)])
            if initial.saveSceneBoard(scene) {
                initial.addItem(label: "Open tile scene", symbol: "🖼️", message: "Open tile scene",
                                category: "Core", imageData: nil,
                                destinationSceneID: scene.id, action: .openScene)
            }
            initial.addItem(label: "Open tile keyboard", symbol: "⌨️", message: "Open tile keyboard",
                            category: "Core", imageData: nil, action: .openKeyboard)
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-reminder-target") {
            _ = initial.saveRoutineTemplate(name: "Reminder test board")
            if let template = initial.routineTemplates.first(where: { $0.name == "Reminder test board" }) {
                RoutineReminderNavigation.shared.target = RoutineReminderTarget(
                    profileID: initial.activeProfileID, templateID: template.id
                )
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-weekly-reminder-target") {
            let weekday = 2
            let title = "Weekly reminder test"
            if !initial.weeklyPlan.activities(on: weekday).contains(where: { $0.option.label == title }) {
                _ = initial.addWeeklyActivity(WeeklyActivity(option: ChoiceOption(label: title)), on: weekday)
            }
            if let activity = initial.weeklyPlan.activities(on: weekday).first(where: { $0.option.label == title }) {
                RoutineReminderNavigation.shared.weeklyTarget = WeeklyReminderTarget(
                    profileID: initial.activeProfileID, weekday: weekday, activityID: activity.id
                )
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-calendar-reminder-target") {
            let title = "Calendar reminder test"
            if !initial.visualCalendar.events.contains(where: { $0.option.label == title }) {
                _ = initial.addCalendarEvent(CalendarEvent(option: ChoiceOption(label: title, symbol: "📅"),
                    startDate: Calendar.current.startOfDay(for: Date())))
            }
            if let event = initial.visualCalendar.events.first(where: { $0.option.label == title }) {
                RoutineReminderNavigation.shared.calendarTarget = CalendarReminderTarget(
                    profileID: initial.activeProfileID, eventID: event.id, date: Date()
                )
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-calendar-weekly-completion") {
            let weekday = Calendar.current.component(.weekday, from: Date())
            let title = "Calendar weekly completion"
            if !initial.weeklyPlan.activities(on: weekday).contains(where: { $0.option.label == title }) {
                _ = initial.addWeeklyActivity(WeeklyActivity(option: ChoiceOption(label: title, symbol: "📚")),
                                              on: weekday)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-weekly-plan-edit-lock") {
            let weekday = Calendar.current.component(.weekday, from: Date())
            let title = "Locked weekly activity"
            if !initial.weeklyPlan.activities(on: weekday).contains(where: { $0.option.label == title }) {
                if initial.calendarEditingBlocked { _ = initial.unlockCalendarEditing(pin: "4826") }
                _ = initial.addWeeklyActivity(WeeklyActivity(option: ChoiceOption(label: title, symbol: "📚")),
                                              on: weekday)
            }
            if !initial.calendarEditingBlocked {
                try? initial.enableCalendarEditingLock(pin: "4826")
            }
            initial.lockCalendarEditing()
        }
#endif
        _store = StateObject(wrappedValue: initial)
        _nearbyChat = StateObject(wrappedValue: NearbyChatService(store: initial))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(nearbyChat)
                .environmentObject(callAudio)
                .onChange(of: store.activeProfileID) { _, _ in nearbyChat.stop() }
        }
    }

#if DEBUG
    private static let literacyTestScene: VisualSceneBoard = {
        let imageData = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).pngData { context in
            UIColor(red: 0.84, green: 0.92, blue: 0.88, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            UIColor(red: 0.24, green: 0.43, blue: 0.36, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 90, y: 80, width: 150, height: 150)).fill()
        }
        return VisualSceneBoard(title: "Literacy scene", imageData: imageData,
                                hotspots: [SceneHotspot(option: ChoiceOption(label: "books"), x: 0.25, y: 0.3)])
    }()
#endif
}
