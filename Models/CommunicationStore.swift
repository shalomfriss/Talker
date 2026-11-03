import AVFoundation
import Foundation

private final class SpeechVoiceResolver: @unchecked Sendable {
    static let shared = SpeechVoiceResolver()

    private let lock = NSLock()
    private var voices: [String: AVSpeechSynthesisVoice] = [:]
    private var requested: Set<String> = []

    func language(_ code: String) -> AVSpeechSynthesisVoice? {
        cachedOrRequest("language:\(code)") { AVSpeechSynthesisVoice(language: code) }
    }

    func identifier(_ identifier: String) -> AVSpeechSynthesisVoice? {
        cachedOrRequest("identifier:\(identifier)") { AVSpeechSynthesisVoice(identifier: identifier) }
    }

    private func cachedOrRequest(_ key: String,
                                 resolve: @escaping @Sendable () -> AVSpeechSynthesisVoice?) -> AVSpeechSynthesisVoice? {
        lock.lock()
        let cached = voices[key]
        let needsRequest = cached == nil && requested.insert(key).inserted
        lock.unlock()
        if needsRequest {
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let voice = resolve()
                lock.lock()
                if let voice { voices[key] = voice }
                lock.unlock()
            }
        }
        return cached
    }
}

private final class SpeechCommandQueue: @unchecked Sendable {
    static let shared = SpeechCommandQueue()
    private let queue = DispatchQueue(label: "org.openvoice.speech-playback", qos: .userInitiated)

    func speak(_ utterance: AVSpeechUtterance, with synthesizer: AVSpeechSynthesizer,
               language: String, preferredVoiceIdentifier: String = "") {
        queue.async {
            if utterance.voice == nil {
                let selected = preferredVoiceIdentifier.isEmpty
                    ? nil : AVSpeechSynthesisVoice(identifier: preferredVoiceIdentifier)
                utterance.voice = selected?.language.hasPrefix(language) == true
                    ? selected : AVSpeechSynthesisVoice(language: language)
            }
            synthesizer.speak(utterance)
        }
    }

    func stop(_ synthesizer: AVSpeechSynthesizer) {
        queue.async { _ = synthesizer.stopSpeaking(at: .immediate) }
    }

    func pause(_ synthesizer: AVSpeechSynthesizer) {
        queue.async { _ = synthesizer.pauseSpeaking(at: .immediate) }
    }

    func resume(_ synthesizer: AVSpeechSynthesizer) {
        queue.async { _ = synthesizer.continueSpeaking() }
    }
}

struct PictureMessageToken: Equatable {
    var text: String
    var symbol: String?
    var imageData: Data?
    var arasaacPictogramID: Int? = nil
}

private struct ReminderRestorePlans: @unchecked Sendable {
    var routines: [RoutineReminderPlan] = []
    var weekly: [WeeklyReminderPlan] = []
    var calendar: [CalendarReminderPlan] = []

    mutating func append(_ other: ReminderRestorePlans) {
        routines.append(contentsOf: other.routines)
        weekly.append(contentsOf: other.weekly)
        calendar.append(contentsOf: other.calendar)
    }
}

struct ReminderProfileSnapshot: Decodable {
    let routineTemplates: [RoutineTemplate]
    let routineReminders: [RoutineReminder]
    let weeklyPlan: WeeklyPlan
    let visualCalendar: VisualCalendar

    private enum CodingKeys: String, CodingKey {
        case routineTemplates, routineReminders, weeklyPlan, visualCalendar
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        routineTemplates = try values.decodeIfPresent([RoutineTemplate].self, forKey: .routineTemplates) ?? []
        routineReminders = try values.decodeIfPresent([RoutineReminder].self, forKey: .routineReminders) ?? []
        weeklyPlan = try values.decodeIfPresent(WeeklyPlan.self, forKey: .weeklyPlan) ?? .init()
        visualCalendar = try values.decodeIfPresent(VisualCalendar.self, forKey: .visualCalendar) ?? .init()
    }
}

private struct WordSuggestionCacheKey: Equatable {
    let profileID: UUID
    let text: String
    let itemsRevision: Int
    let translationsRevision: Int
    let contentRevision: Int
    let language: String
    let saveHistory: Bool
    let learnPrediction: Bool
}

private struct WordSuggestionItemsKey: Equatable {
    let profileID: UUID
    let itemsRevision: Int
    let translationsRevision: Int
    let language: String
}

private struct SentenceSuggestionCacheKey: Equatable {
    let profileID: UUID
    let text: String
    let contentRevision: Int
    let language: String
    let saveHistory: Bool
    let learnPrediction: Bool
}

private struct BoardVoiceCacheKey: Equatable {
    let profileID: UUID
    let itemsRevision: Int
    let assignments: [String: String]
    let identifiers: [String: String]
}

private struct ProfileSaveSnapshot: @unchecked Sendable {
    let data: StoredData
}

private final class ProfilePersistenceWriter: @unchecked Sendable {
    static let shared = ProfilePersistenceWriter()

    private let queue = DispatchQueue(label: "org.openvoice.aac.profile-persistence", qos: .utility)
    private let lock = NSLock()
    private var pending: [URL: ProfileSaveSnapshot] = [:]
    private var drainScheduled = false

    func enqueue(_ data: StoredData, to url: URL) {
        let snapshot = ProfileSaveSnapshot(data: data)
        lock.lock()
        pending[url] = snapshot
        let shouldSchedule = !drainScheduled
        if shouldSchedule { drainScheduled = true }
        lock.unlock()
        if shouldSchedule {
            queue.asyncAfter(deadline: .now() + .milliseconds(150)) { [self] in drain() }
        }
    }

    func flush() {
        queue.sync { drain() }
    }

    private func drain() {
        lock.lock()
        let writes = pending
        pending.removeAll()
        drainScheduled = false
        lock.unlock()
        for (url, snapshot) in writes {
            guard let encoded = try? JSONEncoder().encode(snapshot.data) else { continue }
            try? encoded.write(to: url, options: .atomic)
        }
    }
}

enum PictureLibraryError: LocalizedError {
    case invalidPicture
    case invalidTitle
    case limitReached
    case busy
    case profileChanged

    var errorDescription: String? {
        switch self {
        case .invalidPicture: "Choose a valid picture under 2 MB."
        case .invalidTitle: "Give the picture a name."
        case .limitReached: "The picture library can hold up to 100 pictures."
        case .busy: "Finish saving the current picture first."
        case .profileChanged: "The active profile changed. Open its picture library and try again."
        }
    }
}

private enum PictureLibraryDiskStore {
    static let maximumCount = 100
    static let maximumPictureBytes = 2 * 1_048_576

    private static func url(for profileID: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent("picture-library-\(profileID.uuidString).json")
    }

    static func load(for profileID: UUID, in directory: URL) throws -> [PersonalPicture] {
        let file = url(for: profileID, in: directory)
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let pictures = try JSONDecoder().decode([PersonalPicture].self, from: Data(contentsOf: file))
        try validate(pictures)
        return pictures
    }

    static func save(_ pictures: [PersonalPicture], for profileID: UUID, in directory: URL) throws {
        try validate(pictures)
        try JSONEncoder().encode(pictures).write(to: url(for: profileID, in: directory), options: .atomic)
    }

    static func delete(for profileID: UUID, in directory: URL) {
        try? FileManager.default.removeItem(at: url(for: profileID, in: directory))
    }

    private static func validate(_ pictures: [PersonalPicture]) throws {
        guard pictures.count <= maximumCount else { throw PictureLibraryError.limitReached }
        guard pictures.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.imageData.isEmpty && $0.imageData.count <= maximumPictureBytes }) else {
            throw PictureLibraryError.invalidPicture
        }
    }
}

enum LifeNotebookError: LocalizedError {
    case invalidPost
    case invalidReply
    case limitReached
    case replyLimitReached
    case busy
    case profileChanged
    case postMissing

    var errorDescription: String? {
        switch self {
        case .invalidPost: "Add a title and valid words or media. Photos can be up to 2 MB, videos up to 8 MB, and picture words up to 512 KB each."
        case .invalidReply: "Write a reply of up to 500 characters."
        case .limitReached: "The life notebook can hold 100 posts, eight picture words per post, up to 20 MB of photos, and 30 MB of media in total."
        case .replyLimitReached: "This moment can hold up to 40 conversation turns."
        case .busy: "Finish saving the current notebook post first."
        case .profileChanged: "The active profile changed. Open its notebook and try again."
        case .postMissing: "This moment is no longer in the active notebook."
        }
    }
}

private enum LifeNotebookDiskStore {
    static let maximumPosts = 100
    static let maximumPhotoBytes = 2 * 1_048_576
    static let maximumTotalPhotoBytes = 20 * 1_048_576
    static let maximumVideoBytes = 8 * 1_048_576
    static let maximumPictograms = 8
    static let maximumPictogramBytes = 512 * 1_024
    static let maximumReplies = 40
    static let maximumTotalMediaBytes = 30 * 1_048_576

    private static func url(for profileID: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent("life-notebook-\(profileID.uuidString).json")
    }

    static func load(for profileID: UUID, in directory: URL) throws -> [LifeNotebookPost] {
        let file = url(for: profileID, in: directory)
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let posts = try JSONDecoder().decode([LifeNotebookPost].self, from: Data(contentsOf: file))
        try validate(posts)
        return posts
    }

    static func save(_ posts: [LifeNotebookPost], for profileID: UUID, in directory: URL) throws {
        try validate(posts)
        try JSONEncoder().encode(posts.sorted { $0.occurredAt > $1.occurredAt })
            .write(to: url(for: profileID, in: directory), options: .atomic)
    }

    static func delete(for profileID: UUID, in directory: URL) {
        try? FileManager.default.removeItem(at: url(for: profileID, in: directory))
    }

    static func validate(_ posts: [LifeNotebookPost]) throws {
        guard posts.count <= maximumPosts else { throw LifeNotebookError.limitReached }
        var photoBytes = 0
        var mediaBytes = 0
        var seenIDs = Set<UUID>()
        for post in posts {
            guard seenIDs.insert(post.id).inserted,
                  !post.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  post.title.count <= 80, post.topic.count <= 40, post.text.count <= 1_000,
                  !post.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                  post.photoData != nil || !(post.pictograms ?? []).isEmpty else {
                throw LifeNotebookError.invalidPost
            }
            let pictograms = post.pictograms ?? []
            guard pictograms.count <= maximumPictograms else { throw LifeNotebookError.limitReached }
            var pictogramIDs = Set<UUID>()
            for pictogram in pictograms {
                guard pictogramIDs.insert(pictogram.id).inserted,
                      !pictogram.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      pictogram.label.count <= 40, pictogram.symbol.count <= 12,
                      pictogram.arasaacPictogramID == nil || pictogram.imageData != nil else {
                    throw LifeNotebookError.invalidPost
                }
                if let image = pictogram.imageData {
                    guard !image.isEmpty, image.count <= maximumPictogramBytes else {
                        throw LifeNotebookError.invalidPost
                    }
                    mediaBytes += image.count
                }
            }
            let replies = post.replies ?? []
            guard replies.count <= maximumReplies else { throw LifeNotebookError.replyLimitReached }
            var replyIDs = Set<UUID>()
            for reply in replies {
                guard replyIDs.insert(reply.id).inserted,
                      !reply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      reply.text.count <= 500 else { throw LifeNotebookError.invalidReply }
            }
            if let photo = post.photoData {
                guard !photo.isEmpty, photo.count <= maximumPhotoBytes else {
                    throw LifeNotebookError.invalidPost
                }
                photoBytes += photo.count
                mediaBytes += photo.count
                guard photoBytes <= maximumTotalPhotoBytes else { throw LifeNotebookError.limitReached }
            }
            if let video = post.videoData {
                guard !video.isEmpty, video.count <= maximumVideoBytes,
                      post.photoData != nil else { throw LifeNotebookError.invalidPost }
                mediaBytes += video.count
            }
            guard mediaBytes <= maximumTotalMediaBytes else { throw LifeNotebookError.limitReached }
        }
    }
}

enum LifeNotebookTransferError: LocalizedError {
    case tooLarge
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .tooLarge: "This moment file is too large. Choose one under 24 MB."
        case .unsupportedFormat: "This is not a supported Open Voice moment file."
        }
    }
}

struct LifeNotebookTransfer: Codable {
    static let maxImportBytes = 24 * 1_048_576
    private static let formatName = "org.openvoice.life-notebook-post"

    let format: String
    let version: Int
    let post: LifeNotebookPost

    static func exportData(_ post: LifeNotebookPost) throws -> Data {
        try LifeNotebookDiskStore.validate([post])
        let data = try JSONEncoder().encode(Self(format: formatName, version: 1, post: post))
        guard data.count <= maxImportBytes else { throw LifeNotebookTransferError.tooLarge }
        return data
    }

    static func importPost(_ data: Data) throws -> LifeNotebookPost {
        guard data.count <= maxImportBytes else { throw LifeNotebookTransferError.tooLarge }
        let transfer: Self
        do {
            transfer = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw LifeNotebookTransferError.unsupportedFormat
        }
        guard transfer.format == formatName, transfer.version == 1 else {
            throw LifeNotebookTransferError.unsupportedFormat
        }
        try LifeNotebookDiskStore.validate([transfer.post])
        var copy = transfer.post
        copy.id = UUID()
        copy.createdAt = .now
        copy.updatedAt = .now
        copy.pictograms = copy.pictograms?.map { picture in
            var copy = picture
            copy.id = UUID()
            return copy
        }
        copy.replies = copy.replies?.map { reply in
            var copy = reply
            copy.id = UUID()
            return copy
        }
        return copy
    }
}

@MainActor
final class CommunicationStore: ObservableObject {
    @Published private(set) var items: [CommunicationItem] {
        didSet { itemsRevision &+= 1 }
    }
    private(set) var itemsRevision = 0
    @Published private(set) var categories: [String]
    @Published private(set) var routines: [RoutineStep]
    @Published private(set) var routineHistory: [RoutineRun]
    @Published private(set) var routineTemplates: [RoutineTemplate]
    @Published private(set) var routineReminders: [RoutineReminder]
    @Published private(set) var phrases: [SavedPhrase] {
        didSet { predictionInputRevision &+= 1 }
    }
    @Published private(set) var jokes: [Joke]
    @Published private(set) var history: [SpokenMessage] {
        didSet { predictionInputRevision &+= 1 }
    }
    @Published private(set) var usageEvents: [CommunicationUsageEvent]
    @Published private(set) var notes: [CommunicationNote]
    @Published private(set) var savedReadingDocuments: [SavedReadingDocument]
    @Published private(set) var pictureLibrary: [PersonalPicture] = []
    private var loadedPictureLibraryProfileID: UUID?
    private var isSavingPictureLibrary = false
    @Published private(set) var lifeNotebookPosts: [LifeNotebookPost] = []
    private var loadedLifeNotebookProfileID: UUID?
    private var isSavingLifeNotebook = false
    @Published private(set) var learnedPrediction: LearnedPredictionModel {
        didSet { predictionInputRevision &+= 1 }
    }
    @Published private(set) var feelingsLog: [FeelingLogEntry]
    @Published private(set) var stories: [VisualStory]
    @Published private(set) var choiceBoards: [ChoiceBoard]
    var choiceBoardFolders: [String] {
        var seen = Set<String>()
        return choiceBoards.compactMap(\.folder).filter { folder in
            seen.insert(folder.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted
        }
    }
    @Published private(set) var sceneBoards: [VisualSceneBoard]
    @Published private(set) var weeklyPlan: WeeklyPlan
    @Published private(set) var visualCalendar: VisualCalendar
    @Published private(set) var rewardCharts: [RewardChart]
    @Published private(set) var rewardCollectibles: [RewardCollectible]
    @Published private(set) var passport: CommunicationPassport
    @Published private(set) var wordTranslations: [String: [String: WordTranslation]] {
        didSet { wordTranslationsRevision &+= 1 }
    }
    private(set) var wordTranslationsRevision = 0
    @Published private(set) var profiles: [CommunicationProfile]
    @Published private(set) var activeProfileID: UUID
    @Published private(set) var conversations: [ConversationDraft]
    @Published private(set) var activeConversationID: UUID
    @Published private var privateConversation: ConversationDraft? = nil
    @Published private(set) var drawingStrokes: [DrawingStroke]
    @Published private(set) var speechTopics: [SpeechTopic]
    @Published private(set) var nearbyMessages: [NearbyChatMessage]
    @Published private(set) var nearbyChatSavingEnabled: Bool
    @Published private(set) var isBoardOnlyModeActive = false
    @Published private(set) var isCalendarEditingUnlocked = false
    @Published var settings: AppSettings { didSet {
        if !isLoadingConversation {
            if settings.quickResponses != oldValue.quickResponses {
                predictionInputRevision &+= 1
            }
            if settings.speechMuted && !oldValue.speechMuted {
                Task { @MainActor in
                    if self.settings.speechMuted { self.stopSpeaking() }
                }
            }
            if settings.speechVolume != oldValue.speechVolume || settings.speechMuted != oldValue.speechMuted {
                audioPlayer?.volume = settings.speechPlaybackVolume
                scanCuePlayer?.volume = settings.speechPlaybackVolume
            }
            if !settings.autoClearAfterSpeaking {
                for index in conversations.indices { conversations[index].clearOnNextSelection = false }
                privateConversation?.clearOnNextSelection = false
            }
            save()
        }
    } }
    @Published private(set) var messageParts: [String] = []
    private(set) var messagePartLanguages: [String] = []
    private(set) var messagePartBases: [String] = []
    private(set) var messagePartItemIDs: [UUID?] = []
    private var messagePartPictureOverrides: [MessagePictureOverride?] = []
    @Published var typedMessage = "" { didSet {
        if let pendingPhrasePrefix, !typedMessage.hasSuffix(pendingPhrasePrefix) {
            self.pendingPhrasePrefix = nil
        }
        if !isLoadingConversation { updateActiveConversation(immediately: false) }
    } }
    @Published var typedCursorOffset: Int? { didSet {
        if !isLoadingConversation { updateActiveConversation(immediately: false) }
    } }
    private var pendingPhrasePrefix: String?
    @Published private(set) var speechHighlight: SpeechHighlightState?
    @Published private(set) var messagePlaybackState: MessagePlaybackState?
    @Published private(set) var activeStoryPlaybackID: UUID?
    @Published private(set) var completedStoryPlaybackID: UUID?

    private var speaker: AVSpeechSynthesizer?
    private var activeSpeechUtterances: Set<ObjectIdentifier> = []
    private let speechHighlightDelegate = SpeechHighlightDelegate()
    private let recordedPlaybackDelegate = RecordedPlaybackDelegate()
    private var speechHighlightSegments: [ObjectIdentifier: SpeechHighlightSegment] = [:]
    private var pendingMessageUtterances: Set<ObjectIdentifier> = []
    private var pendingMessageSource: SpeechHighlightSource?
    private var messagePlaybackUsesRecording = false
    private var scanCueSpeaker: AVSpeechSynthesizer?
    private var scanCuePlayer: AVAudioPlayer?
    private var scanCueRequestID = UUID()
    private var typingPreviewActive = false
    private var audioPlayer: AVAudioPlayer?
    private var playbackRequestID = UUID()
    private let baseURL: URL
    private let profilesURL: URL
    private var fileURL: URL
    private var isLoadingConversation = false
    private var draftSaveTask: Task<Void, Never>?
    private var saveTransactionDepth = 0
    private var saveRequested = false
    private(set) var predictionContentRevision = 0
    private var predictionInputRevision = 0
    private var wordSuggestionCacheKey: WordSuggestionCacheKey?
    private var wordSuggestionCache: [Int: [String]] = [:]
    private var wordSuggestionItemsKey: WordSuggestionItemsKey?
    private var wordSuggestionItems: [CommunicationItem] = []
    private var sentenceSuggestionCacheKey: SentenceSuggestionCacheKey?
    private var sentenceSuggestionCache: [Int: [String]] = [:]
    private var boardVoiceCacheKey: BoardVoiceCacheKey?
    private var boardVoiceByItemID: [UUID: String] = [:]
#if DEBUG
    private(set) var wordSuggestionComputationCount = 0
    private(set) var wordSuggestionItemPreparationCount = 0
    private(set) var sentenceSuggestionComputationCount = 0
    private(set) var persistenceWriteCount = 0
    var speechEnginesInitialized: (primary: Bool, cue: Bool) {
        (speaker != nil, scanCueSpeaker != nil)
    }
#endif

    func beginSettingsAdjustment() { saveTransactionDepth += 1 }

    func endSettingsAdjustment() { finishSaveTransaction() }

    init(storageURL: URL? = nil) {
        let directory = storageURL?.deletingLastPathComponent()
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let startingURL = storageURL ?? directory.appendingPathComponent("open-voice-data.json")
        let profileIndexURL = startingURL.deletingPathExtension().appendingPathExtension("profiles.json")
        let savedDirectory = (try? Data(contentsOf: profileIndexURL))
            .flatMap { try? JSONDecoder().decode(ProfileDirectory.self, from: $0) }
        let defaultProfile = CommunicationProfile(id: UUID(), name: "My Voice", fileName: startingURL.lastPathComponent)
        let validProfiles = savedDirectory?.profiles.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.fileName.contains("/") && !$0.fileName.contains("\\")
        } ?? []
        let loadedProfiles = validProfiles.isEmpty ? [defaultProfile] : validProfiles
        let selectedID = loadedProfiles.first(where: { $0.id == savedDirectory?.activeProfileID })?.id ?? loadedProfiles[0].id
        let directoryNeedsSave = savedDirectory.map {
            $0.profiles != loadedProfiles || $0.activeProfileID != selectedID
        } ?? true
        let activeFileName = loadedProfiles.first(where: { $0.id == selectedID })!.fileName
        let activeURL = directory.appendingPathComponent(activeFileName)
        let stored = Self.readData(from: activeURL)
        baseURL = startingURL
        profilesURL = profileIndexURL
        fileURL = activeURL
        profiles = loadedProfiles
        activeProfileID = selectedID
        items = Self.cleanedItems(stored.items)
        categories = stored.categories
        routines = stored.routines
        routineHistory = stored.routineHistory
        routineTemplates = stored.routineTemplates
        routineReminders = stored.routineReminders
        phrases = stored.phrases
        jokes = stored.jokes
        history = stored.history
        usageEvents = stored.usageEvents
        notes = stored.notes
        savedReadingDocuments = stored.savedReadingDocuments
        learnedPrediction = stored.learnedPrediction
        feelingsLog = stored.feelingsLog
        stories = stored.stories
        choiceBoards = stored.choiceBoards
        sceneBoards = stored.sceneBoards
        var loadedWeeklyPlan = stored.weeklyPlan
        loadedWeeklyPlan.removeMissingRewardCharts(validIDs: Set(stored.rewardCharts.map(\.id)))
        weeklyPlan = loadedWeeklyPlan
        var loadedVisualCalendar = stored.visualCalendar
        loadedVisualCalendar.removeMissingRewardCharts(validIDs: Set(stored.rewardCharts.map(\.id)))
        visualCalendar = loadedVisualCalendar
        rewardCharts = stored.rewardCharts
        rewardCollectibles = stored.rewardCollectibles
        passport = stored.passport
        wordTranslations = stored.wordTranslations
        settings = stored.settings
        conversations = stored.conversations
        activeConversationID = stored.activeConversationID
        drawingStrokes = stored.drawingStrokes
        speechTopics = stored.speechTopics
        nearbyMessages = stored.nearbyMessages
        nearbyChatSavingEnabled = stored.nearbyChatSavingEnabled
        let activeDraft = stored.conversations.first(where: { $0.id == stored.activeConversationID })!
        messageParts = activeDraft.messageParts
        messagePartLanguages = Self.languages(for: activeDraft, fallback: stored.settings.communicationLanguage)
        messagePartBases = Self.bases(for: activeDraft)
        messagePartItemIDs = Self.itemIDs(for: activeDraft)
        messagePartPictureOverrides = Self.pictureOverrides(for: activeDraft)
        typedMessage = activeDraft.typedMessage
        typedCursorOffset = activeDraft.typedCursorOffset
        pendingPhrasePrefix = activeDraft.pendingPhrasePrefix
        if settings.boardOnlyModeActive && BoardOnlyPINStore.isMissing(for: activeProfileID) {
            settings.boardOnlyModeActive = false
        }
        isBoardOnlyModeActive = settings.boardOnlyModeActive
        speechHighlightDelegate.store = self
        recordedPlaybackDelegate.store = self
        if visualCalendar.isEditingLocked && CalendarEditingPINStore.isMissing(for: activeProfileID) {
            visualCalendar.editingLocked = false
            save()
        }
        if directoryNeedsSave { try? saveProfileDirectory() }
        _ = SpeechVoiceResolver.shared.language(settings.communicationLanguage == "es" ? "es-ES" : "en-US")
        if !settings.voiceIdentifier.isEmpty {
            _ = SpeechVoiceResolver.shared.identifier(settings.voiceIdentifier)
        }
    }

    var activeProfileName: String {
        profiles.first(where: { $0.id == activeProfileID })?.name ?? "My Voice"
    }

    func startBoardOnlyMode(pin: String) throws {
        try BoardOnlyPINStore.save(pin, for: activeProfileID)
        settings.boardOnlyModeActive = true
        isBoardOnlyModeActive = true
    }

    @discardableResult
    func leaveBoardOnlyMode(pin: String) -> Bool {
        guard isBoardOnlyModeActive, BoardOnlyPINStore.matches(pin, for: activeProfileID) else { return false }
        finishLeavingBoardOnlyMode()
        return true
    }

    func leaveBoardOnlyModeAfterDeviceAuthentication() {
        guard isBoardOnlyModeActive else { return }
        finishLeavingBoardOnlyMode()
    }

    private func finishLeavingBoardOnlyMode() {
        settings.boardOnlyModeActive = false
        isBoardOnlyModeActive = false
    }

    var singleButtonPhrase: SavedPhrase? {
        phrases.first {
            $0.id == settings.singleButtonPhraseID && PhraseTemplate.fields(in: $0.text).isEmpty
        }
    }

    func selectSingleButtonPhrase(_ phrase: SavedPhrase) {
        guard phrases.contains(where: { $0.id == phrase.id && PhraseTemplate.fields(in: $0.text).isEmpty }) else { return }
        settings.singleButtonPhraseID = phrase.id
    }

    var activeConversationName: String {
        if isPrivateConversationActive { return "Private conversation" }
        return conversations.first(where: { $0.id == activeConversationID })?.name ?? "Conversation"
    }

    var isPrivateConversationActive: Bool { privateConversation != nil }

    func beginPrivateConversation() {
        guard !isBoardOnlyModeActive, !isPrivateConversationActive else { return }
        updateActiveConversation(immediately: true)
        stopSpeaking()
        isLoadingConversation = true
        privateConversation = ConversationDraft(name: "Private conversation")
        messageParts = []
        messagePartLanguages = []
        messagePartBases = []
        messagePartItemIDs = []
        messagePartPictureOverrides = []
        typedMessage = ""
        typedCursorOffset = nil
        pendingPhrasePrefix = nil
        isLoadingConversation = false
    }

    func endPrivateConversation() {
        guard isPrivateConversationActive,
              let draft = conversations.first(where: { $0.id == activeConversationID }) else { return }
        stopSpeaking()
        isLoadingConversation = true
        privateConversation = nil
        messageParts = draft.messageParts
        messagePartLanguages = Self.languages(for: draft, fallback: settings.communicationLanguage)
        messagePartBases = Self.bases(for: draft)
        messagePartItemIDs = Self.itemIDs(for: draft)
        messagePartPictureOverrides = Self.pictureOverrides(for: draft)
        typedMessage = draft.typedMessage
        typedCursorOffset = draft.typedCursorOffset
        pendingPhrasePrefix = draft.pendingPhrasePrefix
        isLoadingConversation = false
    }

    @discardableResult
    func addConversation(_ name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              !conversations.contains(where: { $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        updateActiveConversation(immediately: true)
        let draft = ConversationDraft(name: clean)
        conversations.append(draft)
        return switchConversation(to: draft.id)
    }

    @discardableResult
    func switchConversation(to id: UUID) -> Bool {
        guard let draft = conversations.first(where: { $0.id == id }) else { return false }
        if isPrivateConversationActive { endPrivateConversation() }
        guard id != activeConversationID else { return true }
        updateActiveConversation(immediately: true)
        draftSaveTask?.cancel()
        stopSpeaking()
        isLoadingConversation = true
        activeConversationID = id
        messageParts = draft.messageParts
        messagePartLanguages = Self.languages(for: draft, fallback: settings.communicationLanguage)
        messagePartBases = Self.bases(for: draft)
        messagePartItemIDs = Self.itemIDs(for: draft)
        messagePartPictureOverrides = Self.pictureOverrides(for: draft)
        typedMessage = draft.typedMessage
        typedCursorOffset = draft.typedCursorOffset
        pendingPhrasePrefix = draft.pendingPhrasePrefix
        isLoadingConversation = false
        save()
        return true
    }

    @discardableResult
    func renameConversation(id: UUID, to name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = conversations.firstIndex(where: { $0.id == id }),
              !conversations.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        conversations[index].name = clean
        save()
        return true
    }

    @discardableResult
    func deleteConversation(id: UUID) -> Bool {
        guard conversations.count > 1, conversations.contains(where: { $0.id == id }) else { return false }
        if id == activeConversationID,
           let next = conversations.first(where: { $0.id != id }) { _ = switchConversation(to: next.id) }
        conversations.removeAll { $0.id == id }
        save()
        return true
    }

    func flushConversationDraft() {
        updateActiveConversation(immediately: true)
    }

    func flushPersistence() {
        ProfilePersistenceWriter.shared.flush()
    }

    @discardableResult
    func addProfile(_ name: String) -> Bool {
        guard !isBoardOnlyModeActive else { return false }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              !profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        let id = UUID()
        let prefix = baseURL.deletingPathExtension().lastPathComponent
        let profile = CommunicationProfile(id: id, name: clean, fileName: "\(prefix)-profile-\(id.uuidString).json")
        let newURL = baseURL.deletingLastPathComponent().appendingPathComponent(profile.fileName)
        do {
            try JSONEncoder().encode(Self.starterData()).write(to: newURL, options: .atomic)
            profiles.append(profile)
            try saveProfileDirectory()
            return switchProfile(to: id)
        } catch {
            profiles.removeAll { $0.id == id }
            try? FileManager.default.removeItem(at: newURL)
            return false
        }
    }

    @discardableResult
    func switchProfile(to id: UUID) -> Bool {
        guard !isBoardOnlyModeActive else { return false }
        guard let profile = profiles.first(where: { $0.id == id }) else { return false }
        guard id != activeProfileID else { return true }
        if isPrivateConversationActive { endPrivateConversation() }
        updateActiveConversation(immediately: true)
        draftSaveTask?.cancel()
        stopSpeaking()
        isLoadingConversation = true
        fileURL = baseURL.deletingLastPathComponent().appendingPathComponent(profile.fileName)
        activeProfileID = id
        pictureLibrary = []
        loadedPictureLibraryProfileID = nil
        lifeNotebookPosts = []
        loadedLifeNotebookProfileID = nil
        let stored = Self.readData(from: fileURL)
        items = Self.cleanedItems(stored.items)
        categories = stored.categories
        routines = stored.routines
        routineHistory = stored.routineHistory
        routineTemplates = stored.routineTemplates
        routineReminders = stored.routineReminders
        phrases = stored.phrases
        jokes = stored.jokes
        history = stored.history
        usageEvents = stored.usageEvents
        notes = stored.notes
        savedReadingDocuments = stored.savedReadingDocuments
        learnedPrediction = stored.learnedPrediction
        feelingsLog = stored.feelingsLog
        stories = stored.stories
        choiceBoards = stored.choiceBoards
        sceneBoards = stored.sceneBoards
        weeklyPlan = stored.weeklyPlan
        visualCalendar = stored.visualCalendar
        rewardCharts = stored.rewardCharts
        weeklyPlan.removeMissingRewardCharts(validIDs: Set(rewardCharts.map(\.id)))
        visualCalendar.removeMissingRewardCharts(validIDs: Set(rewardCharts.map(\.id)))
        rewardCollectibles = stored.rewardCollectibles
        isCalendarEditingUnlocked = false
        passport = stored.passport
        wordTranslations = stored.wordTranslations
        settings = stored.settings
        conversations = stored.conversations
        activeConversationID = stored.activeConversationID
        drawingStrokes = stored.drawingStrokes
        speechTopics = stored.speechTopics
        nearbyMessages = stored.nearbyMessages
        nearbyChatSavingEnabled = stored.nearbyChatSavingEnabled
        let activeDraft = stored.conversations.first(where: { $0.id == stored.activeConversationID })!
        messageParts = activeDraft.messageParts
        messagePartLanguages = Self.languages(for: activeDraft, fallback: stored.settings.communicationLanguage)
        messagePartBases = Self.bases(for: activeDraft)
        messagePartItemIDs = Self.itemIDs(for: activeDraft)
        messagePartPictureOverrides = Self.pictureOverrides(for: activeDraft)
        typedMessage = activeDraft.typedMessage
        typedCursorOffset = activeDraft.typedCursorOffset
        pendingPhrasePrefix = activeDraft.pendingPhrasePrefix
        let missingBoardOnlyPIN = settings.boardOnlyModeActive && BoardOnlyPINStore.isMissing(for: activeProfileID)
        let missingCalendarPIN = visualCalendar.isEditingLocked && CalendarEditingPINStore.isMissing(for: activeProfileID)
        if missingBoardOnlyPIN {
            settings.boardOnlyModeActive = false
        }
        if missingCalendarPIN { visualCalendar.editingLocked = false }
        isBoardOnlyModeActive = settings.boardOnlyModeActive
        isLoadingConversation = false
        if missingBoardOnlyPIN || missingCalendarPIN { save() }
        try? saveProfileDirectory()
        return true
    }

    @discardableResult
    func renameProfile(id: UUID, to name: String) -> Bool {
        guard !isBoardOnlyModeActive else { return false }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = profiles.firstIndex(where: { $0.id == id }),
              !profiles.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        let oldName = profiles[index].name
        profiles[index].name = clean
        do {
            try saveProfileDirectory()
            Task { await restoreRoutineReminders() }
            Task { await restoreWeeklyReminders() }
            return true
        }
        catch { profiles[index].name = oldName; return false }
    }

    @discardableResult
    func deleteProfile(id: UUID) -> Bool {
        guard !isBoardOnlyModeActive, !isSavingPictureLibrary, !isSavingLifeNotebook else { return false }
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else { return false }
        let profile = profiles[index]
        let savedData = Self.readData(from: baseURL.deletingLastPathComponent().appendingPathComponent(profile.fileName))
        let remindersToCancel = savedData.routineReminders
        let weeklyRemindersToCancel = savedData.weeklyPlan.reminders
        let calendarRemindersToCancel = savedData.visualCalendar.events.filter { $0.reminder != nil }
        if id == activeProfileID,
           let next = profiles.first(where: { $0.id != id }) { _ = switchProfile(to: next.id) }
        profiles.removeAll { $0.id == id }
        do {
            try saveProfileDirectory()
            try? FileManager.default.removeItem(at: baseURL.deletingLastPathComponent().appendingPathComponent(profile.fileName))
            PictureLibraryDiskStore.delete(for: id, in: baseURL.deletingLastPathComponent())
            LifeNotebookDiskStore.delete(for: id, in: baseURL.deletingLastPathComponent())
            BoardOnlyPINStore.delete(for: id)
            CalendarEditingPINStore.delete(for: id)
            for reminder in remindersToCancel { RoutineReminderManager.cancel(reminder, profileID: id) }
            for reminder in weeklyRemindersToCancel { WeeklyReminderManager.cancel(reminder, profileID: id) }
            for event in calendarRemindersToCancel { CalendarReminderManager.cancel(event, profileID: id) }
            return true
        } catch {
            profiles.insert(profile, at: min(index, profiles.count))
            return false
        }
    }

    func loadPersonalPictures() async throws {
        let profileID = activeProfileID
        guard loadedPictureLibraryProfileID != profileID else { return }
        let directory = baseURL.deletingLastPathComponent()
        let pictures = try await Task.detached(priority: .userInitiated) {
            try PictureLibraryDiskStore.load(for: profileID, in: directory)
        }.value
        guard activeProfileID == profileID else { throw PictureLibraryError.profileChanged }
        pictureLibrary = pictures
        loadedPictureLibraryProfileID = profileID
    }

    @discardableResult
    func addPersonalPicture(_ data: Data, title: String) async throws -> UUID {
        try await loadPersonalPictures()
        let profileID = activeProfileID
        guard pictureLibrary.count < PictureLibraryDiskStore.maximumCount else {
            throw PictureLibraryError.limitReached
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw PictureLibraryError.invalidTitle }
        let prepared = await PhotoProcessing.preparedDataAsync(from: data)
        guard activeProfileID == profileID else { throw PictureLibraryError.profileChanged }
        guard pictureLibrary.count < PictureLibraryDiskStore.maximumCount else {
            throw PictureLibraryError.limitReached
        }
        guard let prepared,
              !prepared.isEmpty, prepared.count <= PictureLibraryDiskStore.maximumPictureBytes else {
            throw PictureLibraryError.invalidPicture
        }
        let picture = PersonalPicture(title: String(cleanTitle.prefix(80)), imageData: prepared)
        try await persistPersonalPictures(pictureLibrary + [picture])
        return picture.id
    }

    func renamePersonalPicture(_ id: UUID, title: String) async throws {
        try await loadPersonalPictures()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw PictureLibraryError.invalidTitle }
        guard let index = pictureLibrary.firstIndex(where: { $0.id == id }) else { return }
        var updated = pictureLibrary
        updated[index].title = String(cleanTitle.prefix(80))
        try await persistPersonalPictures(updated)
    }

    func deletePersonalPicture(_ id: UUID) async throws {
        try await loadPersonalPictures()
        let updated = pictureLibrary.filter { $0.id != id }
        guard updated.count != pictureLibrary.count else { return }
        try await persistPersonalPictures(updated)
    }

    private func persistPersonalPictures(_ updated: [PersonalPicture]) async throws {
        guard !isSavingPictureLibrary else { throw PictureLibraryError.busy }
        isSavingPictureLibrary = true
        defer { isSavingPictureLibrary = false }
        let profileID = activeProfileID
        let directory = baseURL.deletingLastPathComponent()
        try await Task.detached(priority: .utility) {
            try PictureLibraryDiskStore.save(updated, for: profileID, in: directory)
        }.value
        guard activeProfileID == profileID else { throw PictureLibraryError.profileChanged }
        pictureLibrary = updated
        loadedPictureLibraryProfileID = profileID
    }

    func loadLifeNotebook() async throws {
        let profileID = activeProfileID
        guard loadedLifeNotebookProfileID != profileID else { return }
        let directory = baseURL.deletingLastPathComponent()
        let posts = try await Task.detached(priority: .userInitiated) {
            try LifeNotebookDiskStore.load(for: profileID, in: directory)
        }.value
        guard activeProfileID == profileID else { throw LifeNotebookError.profileChanged }
        lifeNotebookPosts = posts.sorted { $0.occurredAt > $1.occurredAt }
        loadedLifeNotebookProfileID = profileID
    }

    func saveLifeNotebookPost(_ post: LifeNotebookPost) async throws {
        guard !isBoardOnlyModeActive else { throw LifeNotebookError.busy }
        try await loadLifeNotebook()
        var clean = post
        clean.title = post.title.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.topic = post.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.text = post.text.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.pictograms = post.pictograms?.map { pictogram in
            var cleanPictogram = pictogram
            cleanPictogram.label = pictogram.label.trimmingCharacters(in: .whitespacesAndNewlines)
            cleanPictogram.symbol = pictogram.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanPictogram
        }
        clean.updatedAt = .now
        var updated = lifeNotebookPosts
        if let index = updated.firstIndex(where: { $0.id == clean.id }) {
            clean.createdAt = updated[index].createdAt
            updated[index] = clean
        } else {
            updated.insert(clean, at: 0)
        }
        try await persistLifeNotebook(updated)
    }

    func deleteLifeNotebookPost(id: UUID) async throws {
        guard !isBoardOnlyModeActive else { throw LifeNotebookError.busy }
        try await loadLifeNotebook()
        let updated = lifeNotebookPosts.filter { $0.id != id }
        guard updated.count != lifeNotebookPosts.count else { return }
        try await persistLifeNotebook(updated)
    }

    func exportLifeNotebookPost(id: UUID) async throws -> Data {
        try await loadLifeNotebook()
        guard let post = lifeNotebookPosts.first(where: { $0.id == id }) else {
            throw LifeNotebookError.invalidPost
        }
        return try await Task.detached(priority: .userInitiated) {
            try LifeNotebookTransfer.exportData(post)
        }.value
    }

    @discardableResult
    func importLifeNotebookPost(_ data: Data) async throws -> LifeNotebookPost {
        guard !isBoardOnlyModeActive else { throw LifeNotebookError.busy }
        let profileID = activeProfileID
        let post = try await Task.detached(priority: .userInitiated) {
            try LifeNotebookTransfer.importPost(data)
        }.value
        guard activeProfileID == profileID else { throw LifeNotebookError.profileChanged }
        try await saveLifeNotebookPost(post)
        return post
    }

    @discardableResult
    func addLifeNotebookReply(postID: UUID, speaker: LifeNotebookSpeaker,
                              text: String) async throws -> LifeNotebookReply {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 500 else { throw LifeNotebookError.invalidReply }
        try await loadLifeNotebook()
        guard let index = lifeNotebookPosts.firstIndex(where: { $0.id == postID }) else {
            throw LifeNotebookError.postMissing
        }
        var updated = lifeNotebookPosts
        var replies = updated[index].replies ?? []
        guard replies.count < LifeNotebookDiskStore.maximumReplies else {
            throw LifeNotebookError.replyLimitReached
        }
        let reply = LifeNotebookReply(speaker: speaker, text: clean)
        replies.append(reply)
        updated[index].replies = replies
        updated[index].updatedAt = .now
        try await persistLifeNotebook(updated)
        return reply
    }

    func deleteLifeNotebookReply(postID: UUID, replyID: UUID) async throws {
        guard !isBoardOnlyModeActive else { throw LifeNotebookError.busy }
        try await loadLifeNotebook()
        guard let index = lifeNotebookPosts.firstIndex(where: { $0.id == postID }) else {
            throw LifeNotebookError.postMissing
        }
        var updated = lifeNotebookPosts
        var replies = updated[index].replies ?? []
        let previousCount = replies.count
        replies.removeAll { $0.id == replyID }
        guard replies.count != previousCount else { return }
        updated[index].replies = replies
        updated[index].updatedAt = .now
        try await persistLifeNotebook(updated)
    }

    private func persistLifeNotebook(_ updated: [LifeNotebookPost]) async throws {
        guard !isSavingLifeNotebook else { throw LifeNotebookError.busy }
        isSavingLifeNotebook = true
        defer { isSavingLifeNotebook = false }
        let profileID = activeProfileID
        let directory = baseURL.deletingLastPathComponent()
        try await Task.detached(priority: .utility) {
            try LifeNotebookDiskStore.save(updated, for: profileID, in: directory)
        }.value
        guard activeProfileID == profileID else { throw LifeNotebookError.profileChanged }
        lifeNotebookPosts = updated.sorted { $0.occurredAt > $1.occurredAt }
        loadedLifeNotebookProfileID = profileID
    }

    var composedMessage: String {
        messageParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var pictureMessageTokens: [PictureMessageToken] {
        messageParts.enumerated().map { index, text in
            if messagePartPictureOverrides.indices.contains(index),
               let picture = messagePartPictureOverrides[index] {
                return PictureMessageToken(text: text, imageData: picture.imageData,
                                           arasaacPictogramID: picture.arasaacPictogramID)
            }
            let item = messagePartItemIDs.indices.contains(index)
                ? items.first(where: { $0.id == messagePartItemIDs[index] }) : nil
            return PictureMessageToken(text: text, symbol: item?.symbol, imageData: item?.imageData,
                                       arasaacPictogramID: item?.arasaacPictogramID)
        }
    }

    func visualMessageParts(for text: String,
                            pictureSelections: [Int: VisualMessagePictureSelection] = [:]) -> [VisualMessagePart] {
        VisualMessageConversion.convert(text, items: items,
                                        label: { displayLabel(for: $0) },
                                        message: { displayMessage(for: $0) },
                                        pictureSelections: pictureSelections)
    }

    @discardableResult
    func appendVisualMessage(_ text: String,
                             pictureSelections: [Int: VisualMessagePictureSelection] = [:]) -> Bool {
        let parts = visualMessageParts(for: text, pictureSelections: pictureSelections)
        guard !parts.isEmpty else { return false }
        clearSpokenMessageBeforeSelection()
        for part in parts {
            messageParts.append(part.text)
            messagePartLanguages.append(settings.communicationLanguage)
            messagePartBases.append(part.text)
            messagePartItemIDs.append(part.itemID)
            if let imageData = part.imageData, let id = part.arasaacPictogramID,
               part.itemID == nil {
                messagePartPictureOverrides.append(MessagePictureOverride(imageData: imageData,
                                                                           arasaacPictogramID: id))
            } else {
                messagePartPictureOverrides.append(nil)
            }
        }
        updateActiveConversation(immediately: true)
        return true
    }

    var canUndoClearMessage: Bool {
        guard messageParts.isEmpty else { return false }
        if isPrivateConversationActive { return privateConversation?.clearedPictureMessage != nil }
        return conversations.first(where: { $0.id == activeConversationID })?.clearedPictureMessage != nil
    }

    func translation(for item: CommunicationItem, language: String = "es") -> WordTranslation? {
        wordTranslations[item.id.uuidString]?[language]
    }

    func displayLabel(for item: CommunicationItem) -> String {
        if item.effectiveAction == .completeTypedPrediction {
            return typedPrediction(for: item) ?? item.label
        }
        return translation(for: item, language: settings.communicationLanguage)?.label ?? item.label
    }

    func wordSuggestions(limit: Int = 5) -> [String] {
        guard limit > 0 else { return [] }
        let key = WordSuggestionCacheKey(
            profileID: activeProfileID, text: typedMessage,
            itemsRevision: itemsRevision, translationsRevision: wordTranslationsRevision,
            contentRevision: predictionInputRevision, language: settings.communicationLanguage,
            saveHistory: settings.saveHistory, learnPrediction: settings.learnPrediction)
        if wordSuggestionCacheKey != key {
            wordSuggestionCacheKey = key
            wordSuggestionCache.removeAll(keepingCapacity: true)
        }
        if let cached = wordSuggestionCache[limit] { return cached }
        let itemsKey = WordSuggestionItemsKey(
            profileID: activeProfileID, itemsRevision: itemsRevision,
            translationsRevision: wordTranslationsRevision,
            language: settings.communicationLanguage)
        if wordSuggestionItemsKey != itemsKey {
            wordSuggestionItems = localizedItems(excludingPredictionKeys: true)
            wordSuggestionItemsKey = itemsKey
#if DEBUG
            wordSuggestionItemPreparationCount += 1
#endif
        }
#if DEBUG
        wordSuggestionComputationCount += 1
#endif
        let suggestions = WordPrediction.suggestions(
            for: typedMessage, items: wordSuggestionItems, phrases: phrases,
            history: settings.saveHistory ? history : [],
            learned: settings.learnPrediction ? learnedPrediction : nil,
            language: settings.communicationLanguage, limit: limit)
        wordSuggestionCache[limit] = suggestions
        return suggestions
    }

    func sentenceSuggestions(limit: Int = 4) -> [String] {
        guard limit > 0 else { return [] }
        let key = SentenceSuggestionCacheKey(
            profileID: activeProfileID, text: typedMessage,
            contentRevision: predictionInputRevision,
            language: settings.communicationLanguage,
            saveHistory: settings.saveHistory, learnPrediction: settings.learnPrediction)
        if sentenceSuggestionCacheKey != key {
            sentenceSuggestionCacheKey = key
            sentenceSuggestionCache.removeAll(keepingCapacity: true)
        }
        if let cached = sentenceSuggestionCache[limit] { return cached }
#if DEBUG
        sentenceSuggestionComputationCount += 1
#endif
        let suggestions = SentencePrediction.suggestions(
            for: typedMessage, phrases: phrases,
            quickResponses: settings.quickResponses,
            history: settings.saveHistory ? history : [],
            learned: settings.learnPrediction ? learnedPrediction : nil,
            language: settings.communicationLanguage, limit: limit)
        sentenceSuggestionCache[limit] = suggestions
        return suggestions
    }

    func typedPrediction(for item: CommunicationItem) -> String? {
        guard item.effectiveAction == .completeTypedPrediction,
              let slot = Int(item.message), (0..<3).contains(slot),
              (typedCursorOffset ?? typedMessage.count) == typedMessage.count else { return nil }
        let suggestions = wordSuggestions(limit: 3)
        return suggestions.indices.contains(slot) ? suggestions[slot] : nil
    }

    func displayMessage(for item: CommunicationItem) -> String {
        translation(for: item, language: settings.communicationLanguage)?.message ?? item.message
    }

    func select(_ item: CommunicationItem) {
        select(item, speakFeedback: true, messageOverride: nil)
    }

    func select(_ item: CommunicationItem, speakFeedback: Bool) {
        select(item, speakFeedback: speakFeedback, messageOverride: nil)
    }

    func select(_ item: CommunicationItem, speakFeedback: Bool, messageOverride: String?) {
        saveTransactionDepth += 1
        defer { finishSaveTransaction() }
        switch item.effectiveAction {
        case .addToMessage:
            recordPictureUse(item)
            recordRecentPictureWord(item.id)
            let message = messageOverride ?? displayMessage(for: item)
            clearSpokenMessageBeforeSelection()
            messageParts.append(message)
            messagePartLanguages.append(settings.communicationLanguage)
            messagePartBases.append(message)
            messagePartItemIDs.append(item.id)
            messagePartPictureOverrides.append(nil)
            updateActiveConversation(immediately: true)
            if speakFeedback {
                if let audioData = item.audioData { playRecorded(audioData) }
                else if settings.speakOnTap {
                    speak(message, voiceIdentifier: boardFolderVoiceIdentifier(for: item))
                }
            }
        case .speakImmediately:
            recordPictureUse(item)
            recordRecentPictureWord(item.id)
            let message = displayMessage(for: item)
            if let audioData = item.audioData { playRecorded(audioData) }
            else { speak(message, voiceIdentifier: boardFolderVoiceIdentifier(for: item)) }
            saveSpokenMessage(message, inputMode: .picture)
        case .speakCurrentTime:
            speak(SpokenClock.message(at: Date(), language: settings.communicationLanguage),
                  language: settings.communicationLanguage,
                  voiceIdentifier: boardFolderVoiceIdentifier(for: item))
        case .speakMessage:
            speakMessage()
        case .clearMessage:
            clearMessage()
        case .undoClearMessage:
            undoClearMessage()
        case .deleteLastEntry:
            removeLast()
        case .stopSpeaking:
            stopSpeaking()
        case .typeText:
            let previous = typedMessage
            let offset = min(max(typedCursorOffset ?? previous.count, 0), previous.count)
            let before = String(previous.prefix(offset))
            let after = String(previous.dropFirst(offset))
            let insertion = item.message.isEmpty ? item.label : item.message
            let text: String
            if insertion.count == 1, insertion.first?.isLetter == true,
               (before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || ".?!".contains(before.trimmingCharacters(in: .whitespacesAndNewlines).last ?? " ")) {
                text = insertion.uppercased()
            } else {
                text = insertion
            }
            typedMessage = before + text + after
            typedCursorOffset = offset + text.count
            previewTypedSpeech(previous: previous, current: typedMessage)
        case .typeSpace:
            let offset = min(max(typedCursorOffset ?? typedMessage.count, 0), typedMessage.count)
            let before = String(typedMessage.prefix(offset))
            let after = String(typedMessage.dropFirst(offset))
            if !before.isEmpty, before.last?.isWhitespace != true,
               after.first?.isWhitespace != true {
                let previous = typedMessage
                typedMessage = before + " " + after
                typedCursorOffset = offset + 1
                previewTypedSpeech(previous: previous, current: typedMessage)
            }
        case .deleteTypedCharacter:
            let offset = min(max(typedCursorOffset ?? typedMessage.count, 0), typedMessage.count)
            if offset > 0 {
                typedMessage = String(typedMessage.prefix(offset).dropLast())
                    + String(typedMessage.dropFirst(offset))
                typedCursorOffset = offset - 1
            }
        case .moveTypedCursorLeft:
            let offset = min(max(typedCursorOffset ?? typedMessage.count, 0), typedMessage.count)
            typedCursorOffset = max(0, offset - 1)
        case .moveTypedCursorRight:
            let offset = min(max(typedCursorOffset ?? typedMessage.count, 0), typedMessage.count)
            typedCursorOffset = min(typedMessage.count, offset + 1)
        case .completeTypedPrediction:
            if let word = typedPrediction(for: item) {
                let previous = typedMessage
                typedMessage = WordPrediction.completing(previous, with: word)
                typedCursorOffset = typedMessage.count
                previewTypedSpeech(previous: previous, current: typedMessage)
            }
        case .speakTypedMessage:
            speak(typedMessage, saveToHistory: true, followAlong: .typed)
        case .clearTypedMessage:
            stopSpeaking()
            typedMessage = ""
            typedCursorOffset = 0
        case .playVideo, .openWebPage, .openKeyboard, .openScene:
            break
        case .openBoard, .visitBoard, .backBoard, .homeBoard:
            break
        }
    }

    func selectPhrase(_ phrase: CardPhrase, from itemID: UUID? = nil, audioData: Data? = nil) {
        let selection = phrase.resolved(for: settings.communicationLanguage)
        guard !selection.text.isEmpty else { return }
        saveTransactionDepth += 1
        defer { finishSaveTransaction() }
        if let itemID { recordRecentPictureWord(itemID) }
        recordCommunicationUse(kind: .picturePhrase, label: selection.text,
                               itemID: itemID)
        clearSpokenMessageBeforeSelection()
        messageParts.append(selection.text)
        messagePartLanguages.append(selection.language)
        messagePartBases.append(selection.text)
        messagePartItemIDs.append(itemID)
        messagePartPictureOverrides.append(nil)
        updateActiveConversation(immediately: true)
        if let audioData, (try? AVAudioPlayer(data: audioData)) != nil {
            playRecorded(audioData)
        } else {
            speak(selection.text, language: selection.language)
        }
        saveSpokenMessage(selection.text, inputMode: .picture)
    }

    var recentPictureItems: [CommunicationItem] {
        guard settings.recentPictureWordsEnabled else { return [] }
        return settings.recentPictureWordIDs.compactMap { id in
            items.first { $0.id == id && $0.isBoardSelectable(dimmedButtonsActive: settings.dimmedButtonsActive) }
        }
    }

    var recentPictureHighlightIDs: Set<UUID> {
        guard settings.highlightRecentPictureWords else { return [] }
        return Set(settings.recentPictureWordIDs.prefix(3))
    }

    func timeOfDayHighlightIDs(for board: String, hour: Int = Calendar.current.component(.hour, from: Date())) -> Set<UUID> {
        guard settings.highlightWordsForTimeOfDay,
              categories.contains(board), TimeOfDayWordUse.bucket(for: hour) != nil else { return [] }
        let counts = Dictionary(uniqueKeysWithValues: settings.timeOfDayWordUses.map {
            ($0.itemID, $0.count(at: hour))
        })
        var first: (id: UUID, count: Int)?
        var second: (id: UUID, count: Int)?
        for item in items where item.category == board &&
            item.isBoardSelectable(dimmedButtonsActive: settings.dimmedButtonsActive) &&
            (item.effectiveAction == .addToMessage || item.effectiveAction == .speakImmediately) {
            let count = counts[item.id] ?? 0
            guard count >= 2 else { continue }
            if first == nil || count > first!.count {
                second = first
                first = (item.id, count)
            } else if second == nil || count > second!.count {
                second = (item.id, count)
            }
        }
        return Set([first?.id, second?.id].compactMap { $0 })
    }

    func clearRecentPictureWords() {
        settings.recentPictureWordIDs = []
    }

    func clearTimeOfDayWordUses() {
        settings.timeOfDayWordUses = []
    }

    private func recordRecentPictureWord(_ id: UUID) {
        guard !isPrivateConversationActive,
              settings.recentPictureWordsEnabled || settings.highlightRecentPictureWords
                || settings.highlightWordsForTimeOfDay,
              items.contains(where: { $0.id == id }) else { return }
        var updated = settings
        if updated.recentPictureWordsEnabled || updated.highlightRecentPictureWords {
            updated.recentPictureWordIDs = Array(([id] + updated.recentPictureWordIDs.filter { $0 != id }).prefix(12))
        }
        if updated.highlightWordsForTimeOfDay {
            updated.timeOfDayWordUses = TimeOfDayWordUse.recording(id,
                at: Calendar.current.component(.hour, from: Date()), in: updated.timeOfDayWordUses)
        }
        settings = updated
    }

    func appendCompletedPhrase(_ text: String, languageCode: String? = nil) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        clearSpokenMessageBeforeSelection()
        messageParts.append(clean)
        messagePartLanguages.append(PhraseLanguage.normalized(languageCode) ?? settings.communicationLanguage)
        messagePartBases.append(clean)
        messagePartItemIDs.append(nil)
        messagePartPictureOverrides.append(nil)
        updateActiveConversation(immediately: true)
    }

    @discardableResult
    func appendTypedPhrase(_ text: String, joinBehavior: PhraseJoinBehavior = .normal) -> Bool {
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return false }
        let joinsPrevious = joinBehavior == .suffix ||
            (pendingPhrasePrefix.map { typedMessage.hasSuffix($0) } ?? false)
        let separator = typedMessage.isEmpty || typedMessage.last?.isWhitespace == true || joinsPrevious ? "" : " "
        typedMessage += separator + phrase
        pendingPhrasePrefix = joinBehavior == .prefix ? phrase : nil
        updateActiveConversation(immediately: true)
        return true
    }

    @discardableResult
    func appendTypedPhrase(_ phrase: SavedPhrase) -> Bool {
        withSaveTransaction {
            guard appendTypedPhrase(phrase.text, joinBehavior: phrase.joinBehavior) else { return false }
            recordRecentPhrase(phrase)
            return true
        }
    }

    func removeLast() {
        if !messageParts.isEmpty {
            cancelPendingAutoClear()
            messageParts.removeLast()
            messagePartLanguages.removeLast()
            messagePartBases.removeLast()
            messagePartItemIDs.removeLast()
            messagePartPictureOverrides.removeLast()
            updateActiveConversation(immediately: true)
        }
    }

    func clearMessage() {
        guard !messageParts.isEmpty else { return }
        cancelPendingAutoClear()
        if isPrivateConversationActive {
            privateConversation?.clearedPictureMessage = ClearedPictureMessage(
                parts: messageParts, languages: messagePartLanguages, bases: messagePartBases,
                itemIDs: messagePartItemIDs, pictureOverrides: messagePartPictureOverrides)
        } else if let index = conversations.firstIndex(where: { $0.id == activeConversationID }) {
            conversations[index].clearedPictureMessage = ClearedPictureMessage(
                parts: messageParts, languages: messagePartLanguages, bases: messagePartBases,
                itemIDs: messagePartItemIDs, pictureOverrides: messagePartPictureOverrides)
        }
        messageParts.removeAll()
        messagePartLanguages.removeAll()
        messagePartBases.removeAll()
        messagePartItemIDs.removeAll()
        messagePartPictureOverrides.removeAll()
        updateActiveConversation(immediately: true)
    }

    func undoClearMessage() {
        guard messageParts.isEmpty else { return }
        let index = conversations.firstIndex(where: { $0.id == activeConversationID })
        let cleared = isPrivateConversationActive ? privateConversation?.clearedPictureMessage
            : index.flatMap({ conversations[$0].clearedPictureMessage })
        guard let cleared else { return }
        messageParts = cleared.parts
        messagePartLanguages = cleared.languages.count == cleared.parts.count
            ? cleared.languages : Array(repeating: settings.communicationLanguage, count: cleared.parts.count)
        messagePartBases = cleared.bases.count == cleared.parts.count ? cleared.bases : cleared.parts
        let clearedIDs = cleared.itemIDs ?? []
        messagePartItemIDs = clearedIDs.count == cleared.parts.count
            ? clearedIDs : Array(repeating: nil, count: cleared.parts.count)
        let clearedPictures = cleared.pictureOverrides ?? []
        messagePartPictureOverrides = clearedPictures.count == cleared.parts.count
            ? clearedPictures : Array(repeating: nil, count: cleared.parts.count)
        if isPrivateConversationActive { privateConversation?.clearedPictureMessage = nil }
        else if let index { conversations[index].clearedPictureMessage = nil }
        cancelPendingAutoClear()
        updateActiveConversation(immediately: true)
    }

    private func clearSpokenMessageBeforeSelection() {
        if isPrivateConversationActive {
            privateConversation?.clearedPictureMessage = nil
            guard privateConversation?.clearOnNextSelection == true else { return }
            privateConversation?.clearOnNextSelection = false
            guard settings.autoClearAfterSpeaking else { return }
            messageParts.removeAll()
            messagePartLanguages.removeAll()
            messagePartBases.removeAll()
            messagePartItemIDs.removeAll()
            messagePartPictureOverrides.removeAll()
            return
        }
        if let index = conversations.firstIndex(where: { $0.id == activeConversationID }) {
            conversations[index].clearedPictureMessage = nil
        }
        guard let index = conversations.firstIndex(where: { $0.id == activeConversationID }),
              conversations[index].clearOnNextSelection == true else { return }
        conversations[index].clearOnNextSelection = false
        guard settings.autoClearAfterSpeaking else { return }
        messageParts.removeAll()
        messagePartLanguages.removeAll()
        messagePartBases.removeAll()
        messagePartItemIDs.removeAll()
        messagePartPictureOverrides.removeAll()
    }

    private func cancelPendingAutoClear() {
        if isPrivateConversationActive {
            privateConversation?.clearOnNextSelection = false
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == activeConversationID }) else { return }
        conversations[index].clearOnNextSelection = false
    }

    var lastWordFormOptions: [EnglishWordForms.Option] {
        guard let language = messagePartLanguages.last, let base = messagePartBases.last else { return [] }
        if language == "en" { return EnglishWordForms.options(for: base) }
        guard language == "es" else { return [] }
        let category = messagePartItemIDs.last.flatMap { id in
            items.first(where: { $0.id == id }).flatMap { GrammarColorCoding.category(for: $0) }
        }
        let role: SpanishWordForms.Role
        switch category {
        case .verbs: role = .verb
        case .things, .places, .describing: role = .noun
        default: return []
        }
        return SpanishWordForms.options(for: base, role: role)
    }

    @discardableResult
    func changeLastWordForm(to kind: EnglishWordForms.Kind) -> Bool {
        guard let option = lastWordFormOptions.first(where: { $0.kind == kind }),
              !messageParts.isEmpty else { return false }
        cancelPendingAutoClear()
        messageParts[messageParts.count - 1] = option.text
        updateActiveConversation(immediately: true)
        return true
    }

    func updateDrawing(_ strokes: [DrawingStroke]) {
        drawingStrokes = strokes
        save()
    }

    @discardableResult
    func addSpeechTopic(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !speechTopics.contains(where: {
            $0.text.localizedCaseInsensitiveCompare(clean) == .orderedSame
        }) else { return false }
        speechTopics.append(SpeechTopic(text: clean))
        save()
        return true
    }

    @discardableResult
    func renameSpeechTopic(id: UUID, to text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = speechTopics.firstIndex(where: { $0.id == id }),
              !speechTopics.contains(where: {
                  $0.id != id && $0.text.localizedCaseInsensitiveCompare(clean) == .orderedSame
              }) else { return false }
        speechTopics[index].text = clean
        save()
        return true
    }

    func deleteSpeechTopic(id: UUID) {
        speechTopics.removeAll { $0.id == id }
        save()
    }

    func moveSpeechTopics(from source: IndexSet, to destination: Int) {
        guard destination >= 0, destination <= speechTopics.count,
              source.allSatisfy({ speechTopics.indices.contains($0) }) else { return }
        let moved = source.map { speechTopics[$0] }
        for index in source.sorted(by: >) { speechTopics.remove(at: index) }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        speechTopics.insert(contentsOf: moved, at: adjustedDestination)
        save()
    }

    func messageSpeechSegments() -> [MessageSpeechSegment] {
        guard !settings.boardFolderVoiceIdentifiers.isEmpty else {
            return MessageSpeechPlanner.segments(parts: messageParts, languages: messagePartLanguages,
                                                 fallbackLanguage: settings.communicationLanguage)
        }
        let voicesByItemID = cachedBoardVoicesByItemID()
        let voiceIdentifiers = messageParts.indices.map { index in
            guard messagePartItemIDs.indices.contains(index),
                  let itemID = messagePartItemIDs[index] else { return "" }
            return voicesByItemID[itemID] ?? ""
        }
        return MessageSpeechPlanner.segments(parts: messageParts, languages: messagePartLanguages,
                                             fallbackLanguage: settings.communicationLanguage,
                                             voiceIdentifiers: voiceIdentifiers)
    }

    private func cachedBoardVoicesByItemID() -> [UUID: String] {
        let key = BoardVoiceCacheKey(profileID: activeProfileID, itemsRevision: itemsRevision,
                                     assignments: settings.boardFolderAssignments,
                                     identifiers: settings.boardFolderVoiceIdentifiers)
        if boardVoiceCacheKey != key {
            boardVoiceCacheKey = key
            boardVoiceByItemID = items.reduce(into: [UUID: String]()) { result, item in
                let identifier = boardFolderVoiceIdentifier(for: item)
                if !identifier.isEmpty { result[item.id] = identifier }
            }
        }
        return boardVoiceByItemID
    }

    func setNearbyChatSavingEnabled(_ enabled: Bool, including messages: [NearbyChatMessage] = []) {
        nearbyChatSavingEnabled = enabled
        if enabled {
            for message in messages where !nearbyMessages.contains(where: { $0.id == message.id }) {
                nearbyMessages.append(message)
            }
            if nearbyMessages.count > 200 { nearbyMessages.removeFirst(nearbyMessages.count - 200) }
        }
        save()
    }

    func appendNearbyMessage(_ message: NearbyChatMessage) {
        guard !isPrivateConversationActive, nearbyChatSavingEnabled,
              !nearbyMessages.contains(where: { $0.id == message.id }) else { return }
        nearbyMessages.append(message)
        if nearbyMessages.count > 200 { nearbyMessages.removeFirst(nearbyMessages.count - 200) }
        save()
    }

    func clearNearbyMessages() {
        nearbyMessages = []
        save()
    }

    func exportMessageAudio(_ text: String, isPictureMessage: Bool) async throws -> URL {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { throw SpokenAudioExportError.emptyMessage }
        let segments = isPictureMessage
            ? messageSpeechSegments()
            : [MessageSpeechSegment(text: message, language: settings.communicationLanguage)]
        let recording = bankedRecording(matching: message)
        if recording == nil { await warmExportVoices(for: segments) }
        let utterances = segments.map {
            makeUtterance($0.text, language: $0.language, voiceIdentifier: $0.voiceIdentifier)
        }
        return try await SpokenAudioExporter.export(
            utterances: utterances, recordingData: recording)
    }

    private func warmExportVoices(for segments: [MessageSpeechSegment]) async {
        let identifiers = Set(segments.map {
            $0.voiceIdentifier.isEmpty ? settings.voiceIdentifier : $0.voiceIdentifier
        }.filter { !$0.isEmpty })
        guard !identifiers.isEmpty else { return }
        for identifier in identifiers { _ = SpeechVoiceResolver.shared.identifier(identifier) }
        for _ in 0..<15 {
            if identifiers.allSatisfy({ SpeechVoiceResolver.shared.identifier($0) != nil }) { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func exportPhraseAudio(_ phrase: SavedPhrase) async throws -> URL {
        guard let current = phrases.first(where: { $0.id == phrase.id }) else {
            throw SpokenAudioExportError.phraseUnavailable
        }
        guard PhraseTemplate.fields(in: current.text).isEmpty else {
            throw SpokenAudioExportError.unfinishedPhrase
        }
        let utterance = makeUtterance(current.text,
                                     language: current.languageCode ?? settings.communicationLanguage)
        return try await SpokenAudioExporter.export(
            utterances: [utterance],
            recordingData: current.audioData ?? bankedRecording(matching: current.text))
    }

    func speakMessage() {
        let segments = messageSpeechSegments()
        guard !segments.isEmpty else { return }
        if isPrivateConversationActive {
            privateConversation?.clearOnNextSelection = settings.autoClearAfterSpeaking
        } else if let index = conversations.firstIndex(where: { $0.id == activeConversationID }) {
            conversations[index].clearOnNextSelection = settings.autoClearAfterSpeaking
            save()
        }
        if let recording = bankedRecording(matching: composedMessage) {
            playRecorded(recording, messageSource: .picture)
            saveSpokenMessage(composedMessage, inputMode: .picture)
            return
        }
        let utterances = segments.map {
            makeUtterance($0.text, language: $0.language, voiceIdentifier: $0.voiceIdentifier)
        }
        beginSpeechPlayback()
        beginSpeechHighlight(utterances, source: .picture)
        pendingMessageUtterances = Set(utterances.map(ObjectIdentifier.init))
        pendingMessageSource = .picture
        let voice = speechSynthesizer
        for (index, utterance) in utterances.enumerated() {
            queueSpeech(utterance, with: voice, language: segments[index].language,
                        voiceIdentifier: segments[index].voiceIdentifier)
        }
        saveSpokenMessage(composedMessage, inputMode: .picture)
    }

    func speak(_ text: String, saveToHistory: Bool = false,
               followAlong: SpeechHighlightSource? = nil, languageCode: String? = nil,
               inputMode: SpokenMessageInputMode? = nil, voiceIdentifier: String? = nil) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        let historyMode = inputMode ?? (followAlong == .typed ? .typed :
                                        followAlong == .picture ? .picture : .other)
        if saveToHistory, let recording = bankedRecording(matching: message) {
            playRecorded(recording, messageSource: followAlong)
            saveSpokenMessage(message, inputMode: historyMode)
            return
        }
        beginSpeechPlayback()
        let utterance = makeUtterance(message, language: languageCode ?? settings.communicationLanguage,
                                     voiceIdentifier: voiceIdentifier)
        if let followAlong {
            beginSpeechHighlight([utterance], source: followAlong)
            pendingMessageUtterances = [ObjectIdentifier(utterance)]
            pendingMessageSource = followAlong
        }
        queueSpeech(utterance, with: speechSynthesizer,
                    language: languageCode ?? settings.communicationLanguage,
                    voiceIdentifier: voiceIdentifier)
        if saveToHistory { saveSpokenMessage(message, inputMode: historyMode) }
    }

    func speakStandaloneMessage(_ text: String, audioData: Data? = nil,
                                voiceIdentifier: String? = nil) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        if let audioData, (try? AVAudioPlayer(data: audioData)) != nil {
            playRecorded(audioData)
            saveSpokenMessage(message, inputMode: .quickMessage)
        } else {
            speak(message, saveToHistory: true, inputMode: .quickMessage,
                  voiceIdentifier: voiceIdentifier)
        }
    }

    func previewTypedSpeech(previous: String, current: String) {
        let previews = TypedSpeechPreview.previews(previous: previous, current: current, settings: settings)
        guard !previews.isEmpty else { return }
        if !typingPreviewActive {
            beginSpeechPlayback()
            typingPreviewActive = true
        }
        let voice = speechSynthesizer
        for preview in previews {
            queueSpeech(makeUtterance(preview, language: settings.communicationLanguage),
                        with: voice, language: settings.communicationLanguage)
        }
    }

    func speak(_ text: String, language: String, voiceIdentifier: String? = nil) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        beginSpeechPlayback()
        let code = language == "es" ? "es" : "en"
        queueSpeech(makeUtterance(message, language: code, voiceIdentifier: voiceIdentifier),
                    with: speechSynthesizer, language: code, voiceIdentifier: voiceIdentifier)
    }

    private func queueSpeech(_ utterance: AVSpeechUtterance, with synthesizer: AVSpeechSynthesizer,
                             language: String, voiceIdentifier: String? = nil) {
        activeSpeechUtterances.insert(ObjectIdentifier(utterance))
        let voiceLanguage = language == "es" ? "es-ES" : (language == "en" ? "en-US" : language)
        SpeechCommandQueue.shared.speak(utterance, with: synthesizer,
                                        language: voiceLanguage,
                                        preferredVoiceIdentifier: (voiceIdentifier?.isEmpty == false
                                            ? voiceIdentifier : nil) ?? settings.voiceIdentifier)
    }

    func speechUtteranceDidEnd(_ identifier: ObjectIdentifier) {
        activeSpeechUtterances.remove(identifier)
    }

    private var speechSynthesizer: AVSpeechSynthesizer {
        if let speaker { return speaker }
        let newSpeaker = AVSpeechSynthesizer()
        newSpeaker.delegate = speechHighlightDelegate
        speaker = newSpeaker
        return newSpeaker
    }

    private var cueSynthesizer: AVSpeechSynthesizer {
        if let scanCueSpeaker { return scanCueSpeaker }
        let newSpeaker = AVSpeechSynthesizer()
        scanCueSpeaker = newSpeaker
        return newSpeaker
    }

    private func beginSpeechPlayback() {
        cancelStoryPlayback()
        clearSpeechHighlight()
        pendingMessageUtterances.removeAll()
        pendingMessageSource = nil
        messagePlaybackState = nil
        messagePlaybackUsesRecording = false
        if let speaker { SpeechCommandQueue.shared.stop(speaker) }
        activeSpeechUtterances.removeAll()
        stopScanCue()
        typingPreviewActive = false
        playbackRequestID = UUID()
        audioPlayer?.stop()
        audioPlayer = nil
    }

    func beginSpeechHighlight(_ utterances: [AVSpeechUtterance], source: SpeechHighlightSource) {
        guard !utterances.isEmpty else { return }
        var text = ""
        var locations: [ObjectIdentifier: SpeechHighlightSegment] = [:]
        for (index, utterance) in utterances.enumerated() {
            if index > 0 { text += " " }
            let offset = (text as NSString).length
            text += utterance.speechString
            locations[ObjectIdentifier(utterance)] = SpeechHighlightSegment(
                offset: offset, length: (utterance.speechString as NSString).length,
                isLast: index == utterances.count - 1)
        }
        speechHighlightSegments = locations
        speechHighlight = SpeechHighlightState(source: source, text: text, range: nil)
    }

    func updateSpeechHighlight(for id: ObjectIdentifier, range: NSRange) {
        guard let segment = speechHighlightSegments[id],
              range.location != NSNotFound, range.location >= 0, range.length > 0,
              range.location <= segment.length,
              range.length <= segment.length - range.location,
              var current = speechHighlight else { return }
        current.range = NSRange(location: segment.offset + range.location, length: range.length)
        speechHighlight = current
    }

    func finishSpeechHighlight(for id: ObjectIdentifier) {
        guard let segment = speechHighlightSegments[id] else { return }
        speechHighlightSegments[id] = nil
        if segment.isLast {
            if case .story = speechHighlight?.source, let playbackID = activeStoryPlaybackID {
                completedStoryPlaybackID = playbackID
                activeStoryPlaybackID = nil
            }
            clearSpeechHighlight()
        }
    }

    func cancelSpeechHighlight(for id: ObjectIdentifier) {
        guard speechHighlightSegments[id] != nil else { return }
        cancelStoryPlayback()
        clearSpeechHighlight()
    }

    func finishMessagePlayback(for id: ObjectIdentifier) {
        guard pendingMessageUtterances.remove(id) != nil else { return }
        if pendingMessageUtterances.isEmpty {
            pendingMessageSource = nil
            messagePlaybackState = nil
        }
    }

    func startMessagePlayback(for id: ObjectIdentifier) {
        guard pendingMessageUtterances.contains(id),
              let pendingMessageSource, messagePlaybackState == nil else { return }
        messagePlaybackState = .playing(pendingMessageSource)
    }

    private func cancelStoryPlayback() {
        activeStoryPlaybackID = nil
        completedStoryPlaybackID = nil
    }

    private func clearSpeechHighlight() {
        speechHighlightSegments.removeAll()
        speechHighlight = nil
    }

    func makeUtterance(_ text: String, language: String,
                       voiceIdentifier: String? = nil) -> AVSpeechUtterance {
        let spokenText = PronunciationDictionary.applying(
            text, language: language, rules: settings.pronunciationRules)
        let utterance = AVSpeechUtterance(string: spokenText)
        utterance.rate = settings.speechRate
        utterance.pitchMultiplier = settings.speechPitch
        utterance.volume = settings.speechPlaybackVolume
        let preferredVoiceIdentifier = (voiceIdentifier?.isEmpty == false
                                        ? voiceIdentifier : nil) ?? settings.voiceIdentifier
        let selectedVoice = preferredVoiceIdentifier.isEmpty
            ? nil
            : SpeechVoiceResolver.shared.identifier(preferredVoiceIdentifier)
        let requestedLanguage = language == "es" ? "es-ES" : (language == "en" ? "en-US" : language)
        if selectedVoice?.language.hasPrefix(language) == true {
            utterance.voice = selectedVoice
        } else if preferredVoiceIdentifier.isEmpty || selectedVoice != nil {
            utterance.voice = SpeechVoiceResolver.shared.language(requestedLanguage)
        }
        return utterance
    }

    @discardableResult
    func savePronunciationRule(_ rule: PronunciationRule) -> Bool {
        guard let clean = PronunciationDictionary.cleaned(rule, existing: settings.pronunciationRules) else { return false }
        if let index = settings.pronunciationRules.firstIndex(where: { $0.id == clean.id }) {
            settings.pronunciationRules[index] = clean
        } else {
            guard settings.pronunciationRules.count < 100 else { return false }
            settings.pronunciationRules.append(clean)
        }
        return true
    }

    func deletePronunciationRule(_ rule: PronunciationRule) {
        settings.pronunciationRules.removeAll { $0.id == rule.id }
    }

    private func saveSpokenMessage(_ message: String, inputMode: SpokenMessageInputMode) {
        guard !isPrivateConversationActive else { return }
        var changed = false
        if settings.saveHistory && !settings.historyPaused {
            history.insert(.init(text: message, speaker: .communicator, inputMode: inputMode), at: 0)
            if history.count > 50 { history.removeLast(history.count - 50) }
            changed = true
        }
        if settings.learnPrediction && !settings.historyPaused {
            learnedPrediction.learn(message, language: settings.communicationLanguage)
            changed = true
        }
        if changed { save() }
    }

    private func recordPictureUse(_ item: CommunicationItem) {
        guard settings.recordCommunicationUse, !isPrivateConversationActive else { return }
        recordCommunicationUse(kind: .pictureButton, label: displayLabel(for: item),
                               board: item.category, itemID: item.id)
    }

    private func recordCommunicationUse(kind: CommunicationUsageEvent.Kind, label: String,
                                        board: String? = nil, itemID: UUID? = nil) {
        guard settings.recordCommunicationUse, !isPrivateConversationActive else { return }
        let event = CommunicationUsageEvent(kind: kind, label: label, board: board, itemID: itemID)
        guard !event.label.isEmpty else { return }
        usageEvents.insert(event, at: 0)
        if usageEvents.count > CommunicationUsageEvent.maximumCount {
            usageEvents.removeLast(usageEvents.count - CommunicationUsageEvent.maximumCount)
        }
        save()
    }

    func clearCommunicationUse() {
        guard !usageEvents.isEmpty else { return }
        usageEvents = []
        save()
    }

    func stopSpeaking() {
        beginSpeechPlayback()
    }

    var isSpeechOutputActive: Bool {
        !activeSpeechUtterances.isEmpty || audioPlayer?.isPlaying == true
    }

    @discardableResult
    func pauseMessageSpeech() -> Bool {
        guard case .playing(let source) = messagePlaybackState else { return false }
        if messagePlaybackUsesRecording {
            guard let audioPlayer, audioPlayer.isPlaying else { return false }
            audioPlayer.pause()
        } else {
            guard let speaker, !activeSpeechUtterances.isEmpty else { return false }
            SpeechCommandQueue.shared.pause(speaker)
        }
        messagePlaybackState = .paused(source)
        return true
    }

    @discardableResult
    func resumeMessageSpeech() -> Bool {
        guard case .paused(let source) = messagePlaybackState else { return false }
        if messagePlaybackUsesRecording {
            guard let audioPlayer, audioPlayer.play() else { return false }
        } else {
            guard let speaker, !activeSpeechUtterances.isEmpty else { return false }
            SpeechCommandQueue.shared.resume(speaker)
        }
        messagePlaybackState = .playing(source)
        return true
    }

    func stopScanCue() {
        scanCueRequestID = UUID()
        if let scanCueSpeaker { SpeechCommandQueue.shared.stop(scanCueSpeaker) }
        scanCuePlayer?.stop()
    }

    func previewScanCue(_ cue: ScanCue) {
        stopScanCue()
        let mode = settings.scanCueMode
        guard settings.scanEnabled, mode != .off,
              !settings.speechMuted,
              activeSpeechUtterances.isEmpty, audioPlayer?.isPlaying != true else { return }
        if mode == .blip || mode == .woodblock {
            playScanCueSound(mode)
            return
        }
        let text = cue.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: PronunciationDictionary.applying(
            text, language: cue.language, rules: settings.pronunciationRules))
        utterance.rate = min(0.62, max(0.52, settings.speechRate + 0.06))
        utterance.pitchMultiplier = 1.15
        utterance.volume = settings.speechPlaybackVolume * 0.75
        let selectedVoice = SpeechVoiceResolver.shared.identifier(settings.scanCueVoiceIdentifier)
        utterance.voice = selectedVoice?.language.hasPrefix(cue.language) == true
            ? selectedVoice
            : SpeechVoiceResolver.shared.language(cue.language == "es" ? "es-ES" : "en-US")
        SpeechCommandQueue.shared.speak(utterance, with: cueSynthesizer,
                                        language: cue.language == "es" ? "es-ES" : "en-US",
                                        preferredVoiceIdentifier: settings.scanCueVoiceIdentifier)
    }

    private func playScanCueSound(_ mode: ScanCueMode) {
        guard let data = ScanCueSound.wavData(for: mode) else { return }
        let requestID = scanCueRequestID
        Task {
            guard (try? await AudioSessionManager.shared.activatePlayback()) != nil,
                  scanCueRequestID == requestID,
                  settings.scanEnabled, settings.scanCueMode == mode,
                  activeSpeechUtterances.isEmpty, audioPlayer?.isPlaying != true else { return }
            scanCuePlayer = try? AVAudioPlayer(data: data)
            scanCuePlayer?.volume = settings.speechPlaybackVolume
            scanCuePlayer?.prepareToPlay()
            scanCuePlayer?.play()
        }
    }

    func playRecorded(_ data: Data, storyPlaybackID: UUID? = nil,
                      messageSource: SpeechHighlightSource? = nil) {
        beginSpeechPlayback()
        let requestID = UUID()
        playbackRequestID = requestID
        activeStoryPlaybackID = storyPlaybackID
        Task {
            let activated = (try? await AudioSessionManager.shared.activatePlayback()) != nil
            guard playbackRequestID == requestID else { return }
            guard activated, let player = try? AVAudioPlayer(data: data) else {
                cancelStoryPlayback()
                return
            }
            audioPlayer = player
            player.delegate = recordedPlaybackDelegate
            player.volume = settings.speechPlaybackVolume
            player.prepareToPlay()
            if player.play() {
                if let messageSource {
                    messagePlaybackUsesRecording = true
                    messagePlaybackState = .playing(messageSource)
                }
            } else {
                audioPlayer = nil
                cancelStoryPlayback()
            }
        }
    }

    func finishRecordedStoryPlayback(for player: AVAudioPlayer, successfully: Bool) {
        guard audioPlayer === player else { return }
        audioPlayer = nil
        messagePlaybackUsesRecording = false
        messagePlaybackState = nil
        guard let playbackID = activeStoryPlaybackID else { return }
        activeStoryPlaybackID = nil
        if successfully { completedStoryPlaybackID = playbackID }
    }

    func bankedRecording(matching text: String) -> Data? {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty,
              let data = phrases.first(where: {
                  $0.audioData != nil && $0.text.localizedCaseInsensitiveCompare(message) == .orderedSame
              })?.audioData,
              (try? AVAudioPlayer(data: data)) != nil else { return nil }
        return data
    }

    func addItem(label: String, symbol: String, message: String, category: String,
                 imageData: Data?, arasaacPictogramID: Int? = nil, audioData: Data? = nil,
                 videoData: Data? = nil, videoPosterData: Data? = nil,
                 webURL: String? = nil,
                 destinationBoard: String? = nil, linkBehavior: BoardLinkBehavior? = nil,
                 destinationSceneID: UUID? = nil,
                 action: ButtonAction = .addToMessage,
                 spanishLabel: String = "", spanishMessage: String = "",
                 phraseOptions: [CardPhrase] = [], visibility: ButtonVisibility = .shown,
                 backgroundColorHex: String? = nil, borderColorHex: String? = nil,
                 grammarCategory: GrammarCategory? = nil,
                 labelFontSize: Int? = nil, contentPadding: Int? = nil) {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLabel.isEmpty else { return }
        let board = categories.contains(category) ? category : "Core"
        let destination = validDestination(destinationBoard, from: board)
        let normalizedWebURL = ButtonWebLink.normalized(webURL)
        guard action != .playVideo ||
            CommunicationItem(label: cleanLabel, symbol: symbol, message: message, category: board,
                              videoData: videoData, videoPosterData: videoPosterData).hasValidVideoMedia &&
            videoData != nil else { return }
        guard action != .openWebPage || normalizedWebURL != nil else { return }
        guard action != .openScene ||
            (destinationSceneID != nil && sceneBoards.contains { $0.id == destinationSceneID }) else { return }
        let item = CommunicationItem(label: cleanLabel, symbol: symbol.isEmpty ? "💬" : symbol,
                                     message: message.isEmpty ? cleanLabel : message,
                                     category: board, imageData: imageData,
                                     arasaacPictogramID: imageData == nil ? nil : arasaacPictogramID,
                                     audioData: destination == nil && action.allowsRecording ? audioData : nil,
                                     videoData: destination == nil && action == .playVideo ? videoData : nil,
                                     videoPosterData: destination == nil && action == .playVideo ? videoPosterData : nil,
                                     webURL: destination == nil && action == .openWebPage ? normalizedWebURL : nil,
                                     destinationBoard: destination,
                                     destinationSceneID: destination == nil && action == .openScene
                                         ? destinationSceneID : nil,
                                     linkBehavior: destination == nil ? nil : (linkBehavior ?? .navigate),
                                     isCustom: true,
                                     phraseOptions: destination == nil && action.allowsPhraseOptions
                                         ? CardPhrase.cleaned(phraseOptions) : nil,
                                     visibility: visibility == .shown ? nil : visibility,
                                     action: destination == nil && !action.requiresDestination && action != .addToMessage
                                         ? action : nil,
                                     backgroundColorHex: backgroundColorHex.flatMap { ButtonColorValue(text: $0)?.hex },
                                     borderColorHex: borderColorHex.flatMap { ButtonColorValue(text: $0)?.hex },
                                     grammarCategory: grammarCategory,
                                     labelFontSize: CommunicationItem.normalizedLabelFontSize(labelFontSize),
                                     contentPadding: CommunicationItem.normalizedContentPadding(contentPadding))
        items.append(item)
        setSpanishTranslation(for: item.id, label: spanishLabel, message: spanishMessage, saveAfter: false)
        save()
    }

    @discardableResult
    func addBulkItems(_ entries: [BulkVocabularyEntry], to board: String,
                      backgroundColorHex: String? = nil) -> Int {
        guard categories.contains(board), entries.count <= BulkVocabulary.maximumEntries else { return 0 }
        var seen = Set(items.filter { $0.category == board }.map { BulkVocabulary.key(for: $0.label) })
        let color = backgroundColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
        var additions: [CommunicationItem] = []
        additions.reserveCapacity(entries.count)
        for entry in entries {
            let label = entry.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let symbol = entry.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = entry.message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, label.count <= 80, symbol.count <= 8, message.count <= 400,
                  seen.insert(BulkVocabulary.key(for: label)).inserted else { continue }
            additions.append(CommunicationItem(label: label, symbol: symbol.isEmpty ? "💬" : symbol,
                                               message: message.isEmpty ? label : message,
                                               category: board, isCustom: true,
                                               backgroundColorHex: color))
        }
        guard !additions.isEmpty else { return 0 }
        items.append(contentsOf: additions)
        save()
        return additions.count
    }

    @discardableResult
    func addBulkBoard(_ name: String, entries: [BulkVocabularyEntry],
                      backgroundColorHex: String? = nil) -> Int {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.localizedCaseInsensitiveCompare("Favorites") != .orderedSame,
              !categories.contains(where: { $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }),
              !entries.isEmpty, entries.count <= BulkVocabulary.maximumEntries else { return 0 }
        categories.append(clean)
        let count = addBulkItems(entries, to: clean, backgroundColorHex: backgroundColorHex)
        if count == 0 { categories.removeLast() }
        return count
    }

    func updateSpanishTranslation(for itemID: UUID, label: String, message: String) {
        guard items.contains(where: { $0.id == itemID }) else { return }
        setSpanishTranslation(for: itemID, label: label, message: message, saveAfter: true)
    }

    private func setSpanishTranslation(for itemID: UUID, label: String, message: String, saveAfter: Bool) {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = itemID.uuidString
        if cleanLabel.isEmpty {
            wordTranslations[key]?["es"] = nil
            if wordTranslations[key]?.isEmpty == true { wordTranslations[key] = nil }
        } else {
            wordTranslations[key, default: [:]]["es"] = WordTranslation(
                label: cleanLabel, message: cleanMessage.isEmpty ? cleanLabel : cleanMessage)
        }
        if saveAfter { save() }
    }

    @discardableResult
    func addBoard(_ name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.localizedCaseInsensitiveCompare("Favorites") != .orderedSame,
              !categories.contains(where: { $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        categories.append(clean)
        save()
        return true
    }

    @discardableResult
    func addSpellingBoard(layout: SpellingBoardLayout = .alphabetical) -> String? {
        guard !isBoardOnlyModeActive else { return nil }
        let base = layout == .qwerty ? "QWERTY" :
            (settings.communicationLanguage == "es" ? "Deletrear" : "Spelling")
        var name = base
        var suffix = 2
        while categories.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            name = "\(base) \(suffix)"
            suffix += 1
        }
        categories.append(name)
        items.append(contentsOf: SpellingBoardFactory.items(board: name, layout: layout))
        var updated = settings
        updated.boardIcons[name] = "⌨️"
        settings = updated
        return name
    }

    func missingLibraryWordCount(for page: VocabularyLibraryPage) -> Int {
        guard let board = categories.first(where: {
            $0.localizedCaseInsensitiveCompare(page.title) == .orderedSame
        }) else { return page.words.count }
        let existing = Set(items.filter { $0.category == board }.map {
            $0.label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        })
        return page.words.filter {
            !existing.contains($0.label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        }.count
    }

    @discardableResult
    func addLibraryPage(id: String) -> LibraryPageAddResult? {
        guard !isBoardOnlyModeActive, let page = VocabularyLibrary.page(id: id) else { return nil }
        let existingBoard = categories.first {
            $0.localizedCaseInsensitiveCompare(page.title) == .orderedSame
        }
        let board = existingBoard ?? page.title
        if existingBoard == nil { categories.append(board) }
        var existingLabels = Set(items.filter { $0.category == board }.map {
            $0.label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        })
        var addedCount = 0
        for word in page.words {
            let key = word.label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard existingLabels.insert(key).inserted else { continue }
            let item = CommunicationItem(label: word.label, symbol: word.symbol,
                                         message: word.label, category: board, isCustom: true)
            items.append(item)
            wordTranslations[item.id.uuidString] = [
                "es": WordTranslation(label: word.spanishLabel, message: word.spanishLabel)
            ]
            addedCount += 1
        }
        if settings.boardIcons[board] == nil { settings.boardIcons[board] = page.icon }
        if existingBoard == nil || addedCount > 0 { save() }
        return LibraryPageAddResult(boardName: board, addedCount: addedCount,
                                    createdBoard: existingBoard == nil)
    }

    @discardableResult
    func createProfileFromLibraryTemplate(id: String, named name: String) -> LibraryTemplateAddResult? {
        guard !isBoardOnlyModeActive,
              let template = VocabularyLibrary.template(id: id),
              template.pageIDs.allSatisfy({ VocabularyLibrary.page(id: $0) != nil }) else { return nil }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard addProfile(cleanName) else { return nil }
        var buttonCount = 0
        for pageID in template.pageIDs {
            buttonCount += addLibraryPage(id: pageID)?.addedCount ?? 0
        }
        return LibraryTemplateAddResult(profileName: cleanName,
                                        pageCount: template.pageIDs.count,
                                        buttonCount: buttonCount)
    }

    @discardableResult
    func applyLibraryTemplate(id: String, mode: LibraryTemplateApplyMode) throws -> LibraryTemplateApplyResult {
        guard !isBoardOnlyModeActive,
              let template = VocabularyLibrary.template(id: id),
              template.pageIDs.allSatisfy({ VocabularyLibrary.page(id: $0) != nil }) else {
            throw LibraryTemplateApplyError.unavailable
        }

        updateActiveConversation(immediately: true)
        let backup = try createLocalBackup(named: "Before \(template.title) \(UUID().uuidString.prefix(8))")
        var removedBoardCount = 0
        if mode == .replacePersonalBoards {
            let removedBoards = Set(categories.filter { !StarterVocabulary.categories.contains($0) })
            removedBoardCount = removedBoards.count
            categories.removeAll { removedBoards.contains($0) }
            items.removeAll { item in
                removedBoards.contains(item.category) ||
                item.destinationBoard.map { removedBoards.contains($0) } == true
            }
            let remainingIDs = Set(items.map(\.id))
            let remainingKeys = Set(items.map { $0.id.uuidString })
            wordTranslations = wordTranslations.filter { remainingKeys.contains($0.key) }
            var updatedSettings = settings
            updatedSettings.boardTileSizes = updatedSettings.boardTileSizes.filter { !removedBoards.contains($0.key) }
            updatedSettings.boardGridLayouts = updatedSettings.boardGridLayouts.filter { !removedBoards.contains($0.key) }
            updatedSettings.boardIcons = updatedSettings.boardIcons.filter { !removedBoards.contains($0.key) }
            updatedSettings.hiddenBoards.removeAll { removedBoards.contains($0) }
            updatedSettings.boardsWithoutTileLabels.removeAll { removedBoards.contains($0) }
            updatedSettings.pinnedBoards.removeAll { removedBoards.contains($0) }
            updatedSettings.boardFolderAssignments = updatedSettings.boardFolderAssignments.filter {
                !removedBoards.contains($0.key)
            }
            updatedSettings.focusWordIDs.removeAll { !remainingIDs.contains($0) }
            updatedSettings.recentPictureWordIDs.removeAll { !remainingIDs.contains($0) }
            updatedSettings.timeOfDayWordUses.removeAll { !remainingIDs.contains($0.itemID) }
            settings = updatedSettings
        }

        var selectedBoards: [String] = []
        var buttonCount = 0
        for pageID in template.pageIDs {
            guard let added = addLibraryPage(id: pageID) else { continue }
            selectedBoards.append(added.boardName)
            buttonCount += added.addedCount
        }
        categories.removeAll { $0 == "Core" || selectedBoards.contains($0) }
        categories.insert(contentsOf: ["Core"] + selectedBoards, at: 0)
        var updatedSettings = settings
        updatedSettings.hiddenBoards.removeAll { selectedBoards.contains($0) }
        settings = updatedSettings
        save()
        return LibraryTemplateApplyResult(pageCount: selectedBoards.count,
                                          buttonCount: buttonCount,
                                          removedBoardCount: removedBoardCount,
                                          backupID: backup.id, backupName: backup.name)
    }

    func tileSize(for board: String) -> TileSize {
        guard categories.contains(board) else { return settings.tileSize }
        return settings.boardTileSizes[board] ?? settings.tileSize
    }

    func boardTileLabelsVisible(for board: String) -> Bool {
        !settings.boardsWithoutTileLabels.contains(board)
    }

    @discardableResult
    func setBoardTileLabelsVisible(_ visible: Bool, for board: String) -> Bool {
        guard categories.contains(board) else { return false }
        if visible {
            settings.boardsWithoutTileLabels.removeAll { $0 == board }
        } else if !settings.boardsWithoutTileLabels.contains(board) {
            settings.boardsWithoutTileLabels.append(board)
        }
        return true
    }

    func setTileSize(_ size: TileSize?, for board: String) {
        guard categories.contains(board) else { return }
        settings.boardTileSizes[board] = size
    }

    func gridLayout(for board: String) -> BoardGridLayout? {
        guard categories.contains(board) else { return nil }
        return settings.boardGridLayouts[board] ?? settings.defaultBoardGridLayout
    }

    func emptyGridPositions(in board: String) -> Set<Int> {
        Set(settings.boardEmptySlots[board] ?? [])
    }

    func gridSlots(in board: String, minimumCount: Int = 0) -> [CommunicationItem?] {
        BoardSlotLayout.slots(for: items.filter { $0.category == board },
                              emptyPositions: emptyGridPositions(in: board),
                              minimumCount: minimumCount)
    }

    @discardableResult
    func moveItem(_ itemID: UUID, in board: String, toEmptyGridPosition target: Int) -> Bool {
        guard categories.contains(board), (0..<BoardSlotLayout.maximumEditablePosition).contains(target) else {
            return false
        }
        let boardPositions = items.indices.filter { items[$0].category == board }
        var slots = BoardSlotLayout.slots(for: boardPositions.map { items[$0] },
                                          emptyPositions: emptyGridPositions(in: board),
                                          minimumCount: target + 1)
        guard slots[target] == nil,
              let source = slots.firstIndex(where: { $0?.id == itemID }),
              let moved = slots[source] else { return false }
        slots[source] = nil
        slots[target] = moved
        let ordered = slots.compactMap { $0 }
        for (position, item) in zip(boardPositions, ordered) { items[position] = item }
        let lastOccupied = slots.lastIndex(where: { $0 != nil }) ?? 0
        settings.boardEmptySlots[board] = (0...lastOccupied).filter { slots[$0] == nil }
        save()
        return true
    }

    func setDefaultGridLayout(_ layout: BoardGridLayout?) {
        settings.defaultBoardGridLayout = layout.map { BoardGridLayout(columns: $0.columns, rows: $0.rows) }
    }

    func setPhraseCardGridLayout(_ layout: BoardGridLayout?, for scope: String) {
        guard scope == "all" || scope == "quick" || scope.hasPrefix("folder:") else { return }
        settings.phraseCardGridLayouts[scope] = layout.map {
            BoardGridLayout(columns: $0.columns, rows: $0.rows)
        }
    }

    @discardableResult
    func movePhraseCard(_ phrase: SavedPhrase, to position: Int, in scope: String) -> Bool {
        guard (0..<BoardSlotLayout.maximumEditablePosition).contains(position),
              settings.phraseCardGridLayouts[scope] != nil else { return false }
        let matching: [Int]
        switch scope {
        case "all": matching = Array(phrases.indices)
        case "quick": matching = phrases.indices.filter { phrases[$0].folder == nil }
        default:
            guard scope.hasPrefix("folder:") else { return false }
            let folder = String(scope.dropFirst("folder:".count))
            matching = phrases.indices.filter { phrases[$0].folder == folder }
        }
        let scopedPhrases = matching.map { phrases[$0] }
        guard scopedPhrases.contains(where: { $0.id == phrase.id }) else { return false }
        var slots = PhraseCardSlotLayout.slots(for: scopedPhrases,
            emptyPositions: Set(settings.phraseCardEmptySlots[scope] ?? []),
            minimumCount: position + 1)
        guard let source = slots.firstIndex(where: { $0?.id == phrase.id }) else { return false }
        guard source != position else { return true }
        slots.swapAt(source, position)
        let ordered = slots.compactMap { $0 }
        var updated = phrases
        for (index, phrase) in zip(matching, ordered) { updated[index] = phrase }
        phrases = updated
        let lastOccupied = slots.lastIndex(where: { $0 != nil }) ?? 0
        settings.phraseCardEmptySlots[scope] = (0...lastOccupied).filter { slots[$0] == nil }
        save()
        return true
    }

    func setGridLayout(_ layout: BoardGridLayout?, for board: String) {
        guard categories.contains(board) else { return }
        settings.boardGridLayouts[board] = layout.map { BoardGridLayout(columns: $0.columns, rows: $0.rows) }
    }

    var visibleBoards: [String] {
        categories.filter { !settings.hiddenBoards.contains($0) }
    }

    var homeBoard: String {
        HomeBoard.resolved(settings.homeBoardName, categories: categories,
                           hiddenBoards: settings.hiddenBoards)
    }

    @discardableResult
    func setHomeBoard(_ name: String) -> Bool {
        guard visibleBoards.contains(name) else { return false }
        settings.homeBoardName = name
        return true
    }

    func boardIcon(for board: String) -> String? {
        guard categories.contains(board) else { return nil }
        return settings.boardIcons[board]
    }

    @discardableResult
    func setBoardIcon(_ icon: String?, for board: String) -> Bool {
        guard categories.contains(board) else { return false }
        let clean = icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard clean.count <= 4 else { return false }
        settings.boardIcons[board] = clean.isEmpty ? nil : clean
        return true
    }

    @discardableResult
    func setBoardVisible(_ visible: Bool, for board: String) -> Bool {
        guard categories.contains(board) else { return false }
        if visible {
            settings.hiddenBoards.removeAll { $0 == board }
        } else {
            guard visibleBoards.count > 1 || !visibleBoards.contains(board) else { return false }
            if !settings.hiddenBoards.contains(board) { settings.hiddenBoards.append(board) }
            if settings.homeBoardName == board {
                settings.homeBoardName = homeBoard
            }
        }
        return true
    }

    var pinnedBoards: [String] {
        visibleBoards.filter { settings.pinnedBoards.contains($0) }
    }

    func boardFolder(for board: String) -> String? {
        guard categories.contains(board), let folder = settings.boardFolderAssignments[board],
              settings.boardFolders.contains(folder) else { return nil }
        return folder
    }

    func boardFolderVoiceIdentifier(for item: CommunicationItem) -> String {
        guard let folder = settings.boardFolderAssignments[item.category] else { return "" }
        return settings.boardFolderVoiceIdentifiers[folder] ?? ""
    }

    @discardableResult
    func setBoardFolderVoiceIdentifier(_ identifier: String?, for folder: String) -> Bool {
        guard settings.boardFolders.contains(folder) else { return false }
        let clean = identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard clean.count <= 256 else { return false }
        settings.boardFolderVoiceIdentifiers[folder] = clean.isEmpty ? nil : clean
        return true
    }

    func visibleBoards(in folder: String) -> [String] {
        visibleBoards.filter { boardFolder(for: $0) == folder }
    }

    var boardFoldersWithVisibleBoards: [String] {
        settings.boardFolders.filter { !visibleBoards(in: $0).isEmpty }
    }

    @discardableResult
    func addBoardFolder(_ name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 40,
              !settings.boardFolders.contains(where: {
                  $0.localizedCaseInsensitiveCompare(clean) == .orderedSame
              }) else { return false }
        settings.boardFolders.append(clean)
        return true
    }

    @discardableResult
    func moveBoardFolder(_ name: String, by distance: Int) -> Bool {
        guard abs(distance) == 1, let index = settings.boardFolders.firstIndex(of: name),
              settings.boardFolders.indices.contains(index + distance) else { return false }
        settings.boardFolders.swapAt(index, index + distance)
        return true
    }

    @discardableResult
    func renameBoardFolder(_ name: String, to newName: String) -> Bool {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = settings.boardFolders.firstIndex(of: name),
              !clean.isEmpty, clean.count <= 40,
              !settings.boardFolders.contains(where: {
                  $0 != name && $0.localizedCaseInsensitiveCompare(clean) == .orderedSame
              }) else { return false }
        settings.boardFolders[index] = clean
        settings.boardFolderAssignments = settings.boardFolderAssignments.mapValues {
            $0 == name ? clean : $0
        }
        if let voice = settings.boardFolderVoiceIdentifiers.removeValue(forKey: name) {
            settings.boardFolderVoiceIdentifiers[clean] = voice
        }
        return true
    }

    @discardableResult
    func deleteBoardFolder(_ name: String) -> Bool {
        guard settings.boardFolders.contains(name) else { return false }
        settings.boardFolders.removeAll { $0 == name }
        settings.boardFolderAssignments = settings.boardFolderAssignments.filter { $0.value != name }
        settings.boardFolderVoiceIdentifiers[name] = nil
        return true
    }

    @discardableResult
    func setBoardFolder(_ folder: String?, for board: String) -> Bool {
        guard categories.contains(board) else { return false }
        if let folder, !settings.boardFolders.contains(folder) { return false }
        settings.boardFolderAssignments[board] = folder
        return true
    }

    @discardableResult
    func moveBoard(_ board: String, by distance: Int) -> Bool {
        guard abs(distance) == 1, let index = categories.firstIndex(of: board),
              categories.indices.contains(index + distance) else { return false }
        categories.swapAt(index, index + distance)
        save()
        return true
    }

    func setBoardPinned(_ pinned: Bool, board: String) {
        guard categories.contains(board) else { return }
        if pinned {
            guard !settings.pinnedBoards.contains(board) else { return }
            settings.pinnedBoards.append(board)
        } else {
            settings.pinnedBoards.removeAll { $0 == board }
        }
    }

    @discardableResult
    func renameBoard(_ oldName: String, to newName: String) -> Bool {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !StarterVocabulary.categories.contains(oldName),
              let index = categories.firstIndex(of: oldName), !clean.isEmpty,
              clean.localizedCaseInsensitiveCompare("Favorites") != .orderedSame,
              !categories.contains(where: { $0 != oldName && $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        categories[index] = clean
        if let size = settings.boardTileSizes.removeValue(forKey: oldName) {
            settings.boardTileSizes[clean] = size
        }
        if let layout = settings.boardGridLayouts.removeValue(forKey: oldName) {
            settings.boardGridLayouts[clean] = layout
        }
        if let emptySlots = settings.boardEmptySlots.removeValue(forKey: oldName) {
            settings.boardEmptySlots[clean] = emptySlots
        }
        if let icon = settings.boardIcons.removeValue(forKey: oldName) {
            settings.boardIcons[clean] = icon
        }
        if let folder = settings.boardFolderAssignments.removeValue(forKey: oldName) {
            settings.boardFolderAssignments[clean] = folder
        }
        settings.hiddenBoards = settings.hiddenBoards.map { $0 == oldName ? clean : $0 }
        settings.boardsWithoutTileLabels = settings.boardsWithoutTileLabels.map { $0 == oldName ? clean : $0 }
        settings.pinnedBoards = settings.pinnedBoards.map { $0 == oldName ? clean : $0 }
        if settings.homeBoardName == oldName { settings.homeBoardName = clean }
        for itemIndex in items.indices where items[itemIndex].category == oldName {
            items[itemIndex].category = clean
        }
        for itemIndex in items.indices where items[itemIndex].destinationBoard == oldName {
            items[itemIndex].destinationBoard = clean
        }
        save()
        return true
    }

    @discardableResult
    func deleteBoard(_ name: String) -> Bool {
        guard !StarterVocabulary.categories.contains(name),
              !items.contains(where: { $0.category == name }),
              !items.contains(where: { $0.destinationBoard == name }),
              let index = categories.firstIndex(of: name) else { return false }
        categories.remove(at: index)
        settings.boardTileSizes.removeValue(forKey: name)
        settings.boardGridLayouts.removeValue(forKey: name)
        settings.boardEmptySlots.removeValue(forKey: name)
        settings.boardIcons.removeValue(forKey: name)
        settings.boardFolderAssignments.removeValue(forKey: name)
        settings.hiddenBoards.removeAll { $0 == name }
        settings.boardsWithoutTileLabels.removeAll { $0 == name }
        settings.pinnedBoards.removeAll { $0 == name }
        if settings.homeBoardName == name { settings.homeBoardName = homeBoard }
        save()
        return true
    }

    func updateItem(_ updated: CommunicationItem) {
        guard let index = items.firstIndex(where: { $0.id == updated.id }) else { return }
        var cleaned = updated
        cleaned.category = categories.contains(updated.category) ? updated.category : "Core"
        cleaned.destinationBoard = validDestination(updated.destinationBoard, from: cleaned.category)
        cleaned.destinationSceneID = cleaned.destinationBoard == nil && updated.action == .openScene &&
            sceneBoards.contains(where: { $0.id == updated.destinationSceneID })
            ? updated.destinationSceneID : nil
        cleaned.linkBehavior = cleaned.destinationBoard == nil ? nil : (updated.linkBehavior ?? .navigate)
        cleaned.action = cleaned.destinationBoard == nil && updated.action?.requiresDestination == false
            ? updated.action : nil
        cleaned.webURL = cleaned.effectiveAction == .openWebPage
            ? ButtonWebLink.normalized(updated.webURL) : nil
        if cleaned.effectiveAction == .openWebPage && cleaned.webURL == nil { return }
        if updated.action == .openScene && cleaned.destinationSceneID == nil { return }
        cleaned.backgroundColorHex = updated.backgroundColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
        if cleaned.imageData == nil { cleaned.arasaacPictogramID = nil }
        cleaned.borderColorHex = updated.borderColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
        cleaned.labelFontSize = CommunicationItem.normalizedLabelFontSize(updated.labelFontSize)
        cleaned.contentPadding = CommunicationItem.normalizedContentPadding(updated.contentPadding)
        cleaned.phraseOptions = cleaned.destinationBoard == nil && cleaned.effectiveAction.allowsPhraseOptions
            ? CardPhrase.cleaned(updated.phraseOptions ?? []) : nil
        if !cleaned.effectiveAction.allowsRecording { cleaned.audioData = nil }
        if cleaned.effectiveAction == .playVideo {
            guard cleaned.videoData != nil && cleaned.hasValidVideoMedia else { return }
        } else {
            cleaned.videoData = nil
            cleaned.videoPosterData = nil
        }
        items[index] = cleaned
        save()
    }

    @discardableResult
    func copyItem(_ id: UUID, to board: String) -> UUID? {
        guard !isBoardOnlyModeActive, categories.contains(board),
              let source = items.first(where: { $0.id == id }),
              canTransferItem(source, to: board) else { return nil }
        var copy = source
        copy.id = UUID()
        copy.category = board
        copy.isCustom = true
        copy.isFavorite = false
        items.append(copy)
        wordTranslations[copy.id.uuidString] = wordTranslations[source.id.uuidString]
        save()
        return copy.id
    }

    @discardableResult
    func moveItem(_ id: UUID, to board: String) -> Bool {
        guard !isBoardOnlyModeActive, categories.contains(board),
              let index = items.firstIndex(where: { $0.id == id }),
              items[index].category != board,
              canTransferItem(items[index], to: board) else { return false }
        var moved = items.remove(at: index)
        moved.category = board
        items.append(moved)
        save()
        return true
    }

    private func canTransferItem(_ item: CommunicationItem, to board: String) -> Bool {
        guard let destination = item.destinationBoard else { return true }
        return validDestination(destination, from: board) == destination
    }

    @discardableResult
    func setButtonBackgroundColor(_ colorHex: String?, for itemID: UUID) -> Bool {
        guard !isBoardOnlyModeActive, let index = items.firstIndex(where: { $0.id == itemID }) else { return false }
        let normalized: String?
        if let colorHex {
            guard let value = ButtonColorValue(text: colorHex) else { return false }
            normalized = value.hex
        } else {
            normalized = nil
        }
        guard items[index].backgroundColorHex != normalized else { return false }
        items[index].backgroundColorHex = normalized
        save()
        return true
    }

    @discardableResult
    func storeMessageOnButton(_ text: String, itemID: UUID, language: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBoardOnlyModeActive, !clean.isEmpty, ["en", "es"].contains(language),
              let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].effectiveAction.usesOwnMessage else { return false }
        let item = items[index]
        items[index].audioData = nil
        items[index].phraseOptions = nil
        if language == "es" {
            let label = translation(for: item, language: "es")?.label ?? item.label
            setSpanishTranslation(for: itemID, label: label, message: clean, saveAfter: false)
        } else {
            items[index].message = clean
        }
        save()
        return true
    }

    @discardableResult
    func moveItem(_ id: UUID, in board: String, by steps: Int) -> Bool {
        guard abs(steps) == 1 else { return false }
        let boardItems = items.filter { $0.category == board }
        guard let index = boardItems.firstIndex(where: { $0.id == id }),
              boardItems.indices.contains(index + steps) else { return false }
        return moveItems(in: board, fromOffsets: IndexSet(integer: index),
                         toOffset: steps < 0 ? index - 1 : index + 2)
    }

    @discardableResult
    func swapItems(_ firstID: UUID, with secondID: UUID, in board: String) -> Bool {
        guard firstID != secondID, categories.contains(board),
              let firstIndex = items.firstIndex(where: { $0.id == firstID && $0.category == board }),
              let secondIndex = items.firstIndex(where: { $0.id == secondID && $0.category == board }) else {
            return false
        }
        items.swapAt(firstIndex, secondIndex)
        save()
        return true
    }

    @discardableResult
    func alphabetizeItems(in board: String, selectedIDs: Set<UUID>) -> Bool {
        guard categories.contains(board), selectedIDs.count > 1 else { return false }
        let positions = items.indices.filter {
            items[$0].category == board && selectedIDs.contains(items[$0].id)
        }
        guard positions.count == selectedIDs.count else { return false }

        let original = positions.map { items[$0] }
        let locale = Locale(identifier: settings.communicationLanguage == "es" ? "es" : "en")
        let sorted = original.enumerated().sorted { first, second in
            let result = displayLabel(for: first.element).compare(
                displayLabel(for: second.element),
                options: [.caseInsensitive, .diacriticInsensitive, .numeric],
                locale: locale)
            return result == .orderedSame ? first.offset < second.offset : result == .orderedAscending
        }.map(\.element)
        guard sorted.map(\.id) != original.map(\.id) else { return false }

        for (position, item) in zip(positions, sorted) { items[position] = item }
        save()
        return true
    }

    @discardableResult
    func moveItems(in board: String, fromOffsets: IndexSet, toOffset: Int) -> Bool {
        guard categories.contains(board) else { return false }
        let positions = items.indices.filter { items[$0].category == board }
        guard !fromOffsets.isEmpty, (0...positions.count).contains(toOffset),
              fromOffsets.allSatisfy({ positions.indices.contains($0) }) else { return false }

        var boardItems = positions.map { items[$0] }
        let previousIDs = boardItems.map(\.id)
        let moving = fromOffsets.sorted().map { boardItems[$0] }
        for index in fromOffsets.sorted(by: >) { boardItems.remove(at: index) }
        let insertionIndex = toOffset - fromOffsets.filter { $0 < toOffset }.count
        boardItems.insert(contentsOf: moving, at: insertionIndex)
        guard boardItems.map(\.id) != previousIDs else { return false }

        for (position, item) in zip(positions, boardItems) { items[position] = item }
        save()
        return true
    }

    func deleteItem(_ item: CommunicationItem) {
        items.removeAll { $0.id == item.id && $0.isCustom }
        if item.isCustom {
            wordTranslations[item.id.uuidString] = nil
            settings.recentPictureWordIDs.removeAll { $0 == item.id }
            settings.timeOfDayWordUses.removeAll { $0.itemID == item.id }
        }
        save()
    }

    func toggleFavorite(_ item: CommunicationItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isFavorite.toggle()
        save()
    }

    @discardableResult
    func addPhrase(_ text: String, folder: String? = nil, shortcut: String? = nil,
                   label: String? = nil, languageCode: String? = nil,
                   tapActionOverride: PhraseTapAction? = nil,
                   joinBehavior: PhraseJoinBehavior = .normal,
                   folderLink: PhraseFolderLink? = nil) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = PhraseShortcut.normalized(shortcut)
        let hasShortcut = !(shortcut?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard !clean.isEmpty, (cleanLabel?.count ?? 0) <= 40,
              !phrases.contains(where: { $0.text == clean }),
              !hasShortcut || normalized != nil,
              normalized == nil || !phrases.contains(where: { $0.shortcut == normalized }) else { return false }
        guard languageCode == nil || PhraseLanguage.normalized(languageCode) != nil,
              folderLink == nil || normalizedPhraseFolderLink(folderLink) != nil else { return false }
        phrases.append(.init(text: clean, label: cleanLabel?.isEmpty == false ? cleanLabel : nil,
                             folder: normalizedPhraseFolder(folder), shortcut: normalized,
                             languageCode: languageCode, tapActionOverride: tapActionOverride,
                             joinBehavior: joinBehavior,
                             folderLink: normalizedPhraseFolderLink(folderLink)))
        save()
        return true
    }

    @discardableResult
    func importBankedMessages(_ batch: MessageBankImportBatch) -> (imported: Int, skipped: Int) {
        guard !isBoardOnlyModeActive else { return (0, batch.messages.count + batch.skipped) }
        var known = Set(phrases.map { $0.text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) })
        var imported = 0
        var skipped = batch.skipped
        for message in batch.messages {
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !text.isEmpty, !message.audioData.isEmpty, known.insert(key).inserted else {
                skipped += 1
                continue
            }
            phrases.append(.init(text: text, audioData: message.audioData, folder: "Message bank"))
            imported += 1
        }
        if imported > 0 { save() }
        return (imported, skipped)
    }

    @discardableResult
    func importPhraseCollection(_ collection: PhraseCollectionTransfer,
                                mode: PhraseCollectionMergeMode) -> PhraseCollectionImportResult {
        let matchingIndices = Dictionary(phrases.indices.map {
            (PhraseCollectionTransfer.key(for: phrases[$0].text), $0)
        }, uniquingKeysWith: { first, _ in first })
        let updatedIndices: Set<Int> = mode == .updateMatching
            ? Set(collection.phrases.compactMap { matchingIndices[PhraseCollectionTransfer.key(for: $0.text)] })
            : []
        var usedShortcuts = Set(phrases.indices.filter { !updatedIndices.contains($0) }
            .compactMap { phrases[$0].shortcut })
        var seen = Set<String>()
        var added = 0
        var updated = 0
        var skipped = 0
        var clearedShortcuts = 0
        var omittedPictures = 0
        var omittedRecordings = 0

        for incoming in collection.phrases {
            let text = incoming.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = PhraseCollectionTransfer.key(for: text)
            guard seen.insert(key).inserted else { skipped += 1; continue }
            let match = matchingIndices[key]
            if match != nil && mode == .addMissing { skipped += 1; continue }

            var shortcut = PhraseShortcut.normalized(incoming.shortcut)
            if let value = shortcut, !usedShortcuts.insert(value).inserted {
                shortcut = nil
                clearedShortcuts += 1
            }
            let imageData = incoming.imageData.flatMap { PhotoProcessing.preparedData(from: $0) }
            if incoming.imageData != nil && imageData == nil { omittedPictures += 1 }
            let audioData: Data?
            if let recording = incoming.audioData, !recording.isEmpty {
                audioData = (try? AVAudioPlayer(data: recording)) == nil ? nil : recording
                if audioData == nil { omittedRecordings += 1 }
            } else {
                audioData = nil
            }
            let folder = normalizedPhraseFolder(incoming.folder)
            let label = incoming.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            let color = incoming.colorHex.flatMap { ButtonColorValue(text: $0)?.hex }
            let languageCode = PhraseLanguage.normalized(incoming.languageCode)
            if let match {
                let id = phrases[match].id
                phrases[match] = SavedPhrase(id: id, text: text,
                                            label: label?.isEmpty == false ? label : nil,
                                            audioData: audioData, imageData: imageData,
                                            arasaacPictogramID: imageData == nil ? nil : incoming.arasaacPictogramID,
                                            colorHex: color,
                                            folder: folder, shortcut: shortcut,
                                            languageCode: languageCode,
                                            tapActionOverride: incoming.tapActionOverride,
                                            joinBehavior: incoming.joinBehavior,
                                            folderLink: incoming.folderLink)
                if settings.singleButtonPhraseID == id && !PhraseTemplate.fields(in: text).isEmpty {
                    settings.singleButtonPhraseID = nil
                }
                updated += 1
            } else {
                phrases.append(SavedPhrase(text: text,
                                           label: label?.isEmpty == false ? label : nil,
                                           audioData: audioData, imageData: imageData,
                                           arasaacPictogramID: imageData == nil ? nil : incoming.arasaacPictogramID,
                                           colorHex: color,
                                           folder: folder, shortcut: shortcut,
                                           languageCode: languageCode,
                                           tapActionOverride: incoming.tapActionOverride,
                                           joinBehavior: incoming.joinBehavior,
                                           folderLink: incoming.folderLink))
                added += 1
            }
        }
        if added + updated > 0 {
            removeDanglingPhraseFolderLinks()
            save()
        }
        return PhraseCollectionImportResult(added: added, updated: updated, skipped: skipped,
                                            clearedShortcuts: clearedShortcuts,
                                            omittedPictures: omittedPictures,
                                            omittedRecordings: omittedRecordings)
    }

    @discardableResult
    func updatePhraseText(_ phrase: SavedPhrase, to text: String) -> Bool {
        updatePhraseDetails(phrase, text: text, shortcut: phrase.shortcut)
    }

    @discardableResult
    func updatePhraseDetails(_ phrase: SavedPhrase, text: String, shortcut: String?) -> Bool {
        let currentLabel = phrases.first(where: { $0.id == phrase.id })?.label
        return updatePhraseDetails(phrase, text: text, shortcut: shortcut, label: currentLabel)
    }

    @discardableResult
    func updatePhraseDetails(_ phrase: SavedPhrase, text: String, shortcut: String?, label: String?) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = PhraseShortcut.normalized(shortcut)
        let hasShortcut = !(shortcut?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        guard !clean.isEmpty, (cleanLabel?.count ?? 0) <= 40,
              let index = phrases.firstIndex(where: { $0.id == phrase.id }),
              !phrases.contains(where: { $0.id != phrase.id && $0.text == clean }),
              !hasShortcut || normalized != nil,
              normalized == nil || !phrases.contains(where: { $0.id != phrase.id && $0.shortcut == normalized }) else { return false }
        if phrases[index].text != clean {
            phrases[index].text = clean
            phrases[index].audioData = nil
        }
        phrases[index].shortcut = normalized
        phrases[index].label = cleanLabel?.isEmpty == false ? cleanLabel : nil
        if settings.singleButtonPhraseID == phrase.id && !PhraseTemplate.fields(in: clean).isEmpty {
            settings.singleButtonPhraseID = nil
        }
        save()
        return true
    }

    @discardableResult
    func updatePhraseLanguage(_ phrase: SavedPhrase, languageCode: String?) -> Bool {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }),
              languageCode == nil || PhraseLanguage.normalized(languageCode) != nil else { return false }
        phrases[index].languageCode = PhraseLanguage.normalized(languageCode)
        save()
        return true
    }

    @discardableResult
    func updatePhraseTapAction(_ phrase: SavedPhrase, override action: PhraseTapAction?) -> Bool {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return false }
        phrases[index].tapActionOverride = action
        save()
        return true
    }

    @discardableResult
    func updatePhraseJoinBehavior(_ phrase: SavedPhrase, behavior: PhraseJoinBehavior) -> Bool {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return false }
        phrases[index].joinBehavior = behavior
        save()
        return true
    }

    @discardableResult
    func updatePhraseFolderLink(_ phrase: SavedPhrase, to link: PhraseFolderLink?) -> Bool {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }),
              link == nil || normalizedPhraseFolderLink(link) != nil else { return false }
        phrases[index].folderLink = normalizedPhraseFolderLink(link)
        save()
        return true
    }

    @discardableResult
    func setPhraseAppearance(_ phrase: SavedPhrase, imageData: Data?, colorHex: String?,
                             arasaacPictogramID: Int? = nil) -> Bool {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return false }
        let preparedImage: Data?
        if let imageData {
            guard let prepared = PhotoProcessing.preparedData(from: imageData) else { return false }
            preparedImage = prepared
        } else {
            preparedImage = nil
        }
        let normalizedColor = colorHex.flatMap { ButtonColorValue(text: $0)?.hex }
        guard colorHex == nil || normalizedColor != nil else { return false }
        phrases[index].imageData = preparedImage
        phrases[index].arasaacPictogramID = preparedImage == nil ? nil : arasaacPictogramID
        phrases[index].colorHex = normalizedColor
        save()
        return true
    }

    func movePhrase(_ phrase: SavedPhrase, to folder: String?) {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        phrases[index].folder = normalizedPhraseFolder(folder)
        removeDanglingPhraseFolderLinks()
        save()
    }

    func canMovePhrase(_ phrase: SavedPhrase, by distance: Int) -> Bool {
        phraseMoveIndices(for: phrase, by: distance) != nil
    }

    @discardableResult
    func movePhrase(_ phrase: SavedPhrase, by distance: Int) -> Bool {
        guard let (source, destination) = phraseMoveIndices(for: phrase, by: distance) else { return false }
        phrases.swapAt(source, destination)
        save()
        return true
    }

    private func phraseMoveIndices(for phrase: SavedPhrase, by distance: Int) -> (Int, Int)? {
        guard abs(distance) == 1, let source = phrases.firstIndex(where: { $0.id == phrase.id }) else {
            return nil
        }
        let folder = phrases[source].folder
        let positions = phrases.indices.filter { phrases[$0].folder == folder }
        guard let position = positions.firstIndex(of: source),
              positions.indices.contains(position + distance) else { return nil }
        return (source, positions[position + distance])
    }

    @discardableResult
    func renamePhraseFolder(_ folder: String, to name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = phrases.indices.filter { phrases[$0].folder == folder }
        guard !clean.isEmpty, !matching.isEmpty else { return false }
        let target = phrases.compactMap(\.folder).first {
            $0 != folder && $0.caseInsensitiveCompare(clean) == .orderedSame
        } ?? clean
        for index in matching { phrases[index].folder = target }
        for index in phrases.indices where phrases[index].folderLink == .named(folder) {
            phrases[index].folderLink = .named(target)
        }
        let oldGridKey = "folder:\(folder)"
        let newGridKey = "folder:\(target)"
        if oldGridKey != newGridKey {
            if settings.phraseCardGridLayouts[newGridKey] == nil {
                settings.phraseCardGridLayouts[newGridKey] = settings.phraseCardGridLayouts[oldGridKey]
                settings.phraseCardEmptySlots[newGridKey] = settings.phraseCardEmptySlots[oldGridKey]
            }
            settings.phraseCardGridLayouts.removeValue(forKey: oldGridKey)
            settings.phraseCardEmptySlots.removeValue(forKey: oldGridKey)
        }
        save()
        return true
    }

    private func normalizedPhraseFolder(_ folder: String?) -> String? {
        guard let clean = folder?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else { return nil }
        return phrases.compactMap(\.folder).first { $0.caseInsensitiveCompare(clean) == .orderedSame } ?? clean
    }

    var phraseFolderLinkOptions: [PhraseFolderLink] {
        let quick: [PhraseFolderLink] = phrases.contains(where: { $0.folder == nil }) ? [.quick] : []
        let names = Array(Set(phrases.compactMap(\.folder)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return quick + names.map(PhraseFolderLink.named)
    }

    private func normalizedPhraseFolderLink(_ link: PhraseFolderLink?) -> PhraseFolderLink? {
        guard let link else { return nil }
        switch link {
        case .quick:
            return phraseFolderLinkOptions.contains(.quick) ? .quick : nil
        case .named(let name):
            return phraseFolderLinkOptions.first { option in
                if case .named(let existing) = option {
                    return existing.caseInsensitiveCompare(name) == .orderedSame
                }
                return false
            }
        }
    }

    private func removeDanglingPhraseFolderLinks() {
        for index in phrases.indices {
            phrases[index].folderLink = normalizedPhraseFolderLink(phrases[index].folderLink)
        }
    }

    func updatePhraseRecording(_ phrase: SavedPhrase, audioData: Data?) {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        phrases[index].audioData = audioData?.isEmpty == true ? nil : audioData
        save()
    }

    func speakPhrase(_ phrase: SavedPhrase) {
        guard let current = phrases.first(where: { $0.id == phrase.id }) else { return }
        guard PhraseTemplate.fields(in: current.text).isEmpty else { return }
        saveTransactionDepth += 1
        defer { finishSaveTransaction() }
        recordCommunicationUse(kind: .savedPhrase, label: current.displayLabel,
                               board: current.folder, itemID: current.id)
        if let audioData = current.audioData, (try? AVAudioPlayer(data: audioData)) != nil {
            playRecorded(audioData)
            saveSpokenMessage(current.text, inputMode: .savedPhrase)
        } else {
            speak(current.text, saveToHistory: true, languageCode: current.languageCode,
                  inputMode: .savedPhrase)
        }
        recordRecentPhrase(current)
    }

    var recentPhrases: [SavedPhrase] {
        guard settings.recentPhrasesEnabled else { return [] }
        let byID = Dictionary(phrases.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return settings.recentPhraseIDs.compactMap { byID[$0] }
    }

    func recordRecentPhrase(_ phrase: SavedPhrase) {
        guard !isPrivateConversationActive, settings.recentPhrasesEnabled,
              phrases.contains(where: { $0.id == phrase.id }) else { return }
        var ids = settings.recentPhraseIDs.filter { $0 != phrase.id }
        ids.insert(phrase.id, at: 0)
        settings.recentPhraseIDs = Array(ids.prefix(12))
    }

    func clearRecentPhrases() {
        settings.recentPhraseIDs = []
    }

    func deletePhrase(_ phrase: SavedPhrase) {
        phrases.removeAll { $0.id == phrase.id }
        settings.recentPhraseIDs.removeAll { $0 == phrase.id }
        if settings.singleButtonPhraseID == phrase.id { settings.singleButtonPhraseID = nil }
        removeDanglingPhraseFolderLinks()
        save()
    }

    @discardableResult
    func addJoke(title: String, setup: String, punchline: String, soundEffectData: Data? = nil) -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSetup = setup.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPunchline = punchline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanSetup.isEmpty, !cleanPunchline.isEmpty,
              !jokes.contains(where: { $0.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame }) else { return false }
        jokes.append(Joke(title: cleanTitle, setup: cleanSetup, punchline: cleanPunchline,
                          soundEffectData: soundEffectData?.isEmpty == true ? nil : soundEffectData))
        save()
        return true
    }

    @discardableResult
    func updateJoke(_ joke: Joke) -> Bool {
        let cleanTitle = joke.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSetup = joke.setup.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPunchline = joke.punchline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = jokes.firstIndex(where: { $0.id == joke.id }),
              !cleanTitle.isEmpty, !cleanSetup.isEmpty, !cleanPunchline.isEmpty,
              !jokes.contains(where: { $0.id != joke.id && $0.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame }) else { return false }
        jokes[index] = Joke(id: joke.id, title: cleanTitle, setup: cleanSetup, punchline: cleanPunchline,
                            soundEffectData: joke.soundEffectData?.isEmpty == true ? nil : joke.soundEffectData)
        save()
        return true
    }

    func deleteJoke(_ joke: Joke) {
        jokes.removeAll { $0.id == joke.id }
        save()
    }

    func playJokeSoundEffect(_ joke: Joke) {
        guard let data = jokes.first(where: { $0.id == joke.id })?.soundEffectData,
              (try? AVAudioPlayer(data: data)) != nil else { return }
        playRecorded(data)
    }

    @discardableResult
    func saveChoiceBoard(_ board: ChoiceBoard) -> Bool {
        guard !settings.choiceBoardEditingLocked, !isBoardOnlyModeActive else { return false }
        let title = board.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedFolder = board.folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = requestedFolder.flatMap { name -> String? in
            guard !name.isEmpty else { return nil }
            return choiceBoardFolders.first(where: {
                $0.localizedCaseInsensitiveCompare(name) == .orderedSame
            }) ?? name
        }
        let options = board.options.map { option in
            var cleaned = option
            cleaned.label = option.label.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.message = option.message.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.backgroundColorHex = option.backgroundColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
            cleaned.borderColorHex = option.borderColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
            return cleaned
        }
        guard !title.isEmpty, (2...8).contains(options.count),
              Set(options.map(\.id)).count == options.count,
              options.allSatisfy({ !$0.label.isEmpty && !$0.message.isEmpty }),
              Set(options.map { $0.label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }).count == options.count,
              !choiceBoards.contains(where: {
                  $0.id != board.id && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
              }) else { return false }
        let cleaned = ChoiceBoard(id: board.id, title: title, options: options, folder: folder,
                                  layout: board.effectiveLayout == .grid ? nil : board.layout)
        if let index = choiceBoards.firstIndex(where: { $0.id == board.id }) {
            choiceBoards[index] = cleaned
        } else {
            choiceBoards.append(cleaned)
        }
        save()
        return true
    }

    @discardableResult
    func moveChoiceBoards(ids: [UUID], fromOffsets: IndexSet, toOffset: Int) -> Bool {
        guard !settings.choiceBoardEditingLocked, !isBoardOnlyModeActive else { return false }
        let idsToMove = Set(ids)
        let positions = choiceBoards.indices.filter { idsToMove.contains(choiceBoards[$0].id) }
        guard !ids.isEmpty, idsToMove.count == ids.count,
              positions.map({ choiceBoards[$0].id }) == ids,
              !fromOffsets.isEmpty, (0...positions.count).contains(toOffset),
              fromOffsets.allSatisfy({ positions.indices.contains($0) }) else { return false }

        var visible = positions.map { choiceBoards[$0] }
        let moving = fromOffsets.sorted().map { visible[$0] }
        for index in fromOffsets.sorted(by: >) { visible.remove(at: index) }
        let insertionIndex = toOffset - fromOffsets.filter { $0 < toOffset }.count
        visible.insert(contentsOf: moving, at: insertionIndex)
        guard visible.map(\.id) != ids else { return false }
        for (position, board) in zip(positions, visible) { choiceBoards[position] = board }
        save()
        return true
    }

    @discardableResult
    func importChoiceBoard(_ data: Data) throws -> ChoiceBoard {
        guard !settings.choiceBoardEditingLocked, !isBoardOnlyModeActive else {
            throw ChoiceBoardTransferError.editingLocked
        }
        var imported = try ChoiceBoardTransfer.importBoard(data)
        let baseTitle = imported.title
        var candidate = baseTitle
        var suffix = 2
        while choiceBoards.contains(where: { $0.title.localizedCaseInsensitiveCompare(candidate) == .orderedSame }) {
            candidate = "\(baseTitle) (imported \(suffix))"
            suffix += 1
        }
        imported.title = candidate
        guard saveChoiceBoard(imported) else { throw ChoiceBoardTransferError.invalidBoard }
        guard let saved = choiceBoards.first(where: { $0.id == imported.id }) else {
            throw ChoiceBoardTransferError.invalidBoard
        }
        return saved
    }

    func deleteChoiceBoard(id: UUID) {
        guard !settings.choiceBoardEditingLocked, !isBoardOnlyModeActive else { return }
        choiceBoards.removeAll { $0.id == id }
        for index in routines.indices where routines[index].choiceBoardID == id {
            routines[index].choiceBoardID = nil
        }
        for templateIndex in routineTemplates.indices {
            for stepIndex in routineTemplates[templateIndex].steps.indices
                where routineTemplates[templateIndex].steps[stepIndex].choiceBoardID == id {
                routineTemplates[templateIndex].steps[stepIndex].choiceBoardID = nil
            }
        }
        save()
    }

    @discardableResult
    func saveSceneBoard(_ board: VisualSceneBoard) -> Bool {
        guard !isBoardOnlyModeActive else { return false }
        let title = board.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !board.imageData.isEmpty,
              board.hasValidMedia,
              (1...12).contains(board.hotspots.count),
              Set(board.hotspots.map(\.id)).count == board.hotspots.count,
              board.hotspots.allSatisfy({ $0.hasValidPosition && $0.hasValidMedia &&
                  !$0.option.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  !$0.option.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              !sceneBoards.contains(where: {
                  $0.id != board.id && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
              }) else { return false }
        var cleaned = board
        cleaned.title = title
        if let index = sceneBoards.firstIndex(where: { $0.id == board.id }) {
            sceneBoards[index] = cleaned
        } else {
            sceneBoards.append(cleaned)
        }
        save()
        return true
    }

    @discardableResult
    func importSceneBoard(_ data: Data) throws -> VisualSceneBoard {
        guard !isBoardOnlyModeActive else { throw SceneBoardTransferError.editingLocked }
        let importedBoards = try SceneBoardTransfer.importBundle(data)
        var prepared: [VisualSceneBoard] = []
        for var imported in importedBoards {
            let baseTitle = imported.title
            var candidate = baseTitle
            var suffix = 2
            while (sceneBoards + prepared).contains(where: {
                $0.title.localizedCaseInsensitiveCompare(candidate) == .orderedSame
            }) {
                candidate = "\(baseTitle) (imported \(suffix))"
                suffix += 1
            }
            imported.title = candidate
            prepared.append(imported)
        }
        for imported in prepared {
            guard saveSceneBoard(imported) else { throw SceneBoardTransferError.invalidScene }
        }
        return prepared[0]
    }

    func deleteSceneBoard(id: UUID) {
        guard !isBoardOnlyModeActive else { return }
        sceneBoards.removeAll { $0.id == id }
        for sceneIndex in sceneBoards.indices {
            for hotspotIndex in sceneBoards[sceneIndex].hotspots.indices where
                sceneBoards[sceneIndex].hotspots[hotspotIndex].destinationSceneID == id {
                sceneBoards[sceneIndex].hotspots[hotspotIndex].destinationSceneID = nil
            }
        }
        for itemIndex in items.indices where items[itemIndex].destinationSceneID == id {
            items[itemIndex].destinationSceneID = nil
            items[itemIndex].action = nil
        }
        save()
    }

    func deleteHistoryEntry(_ entry: SpokenMessage) {
        history.removeAll { $0.id == entry.id }
        save()
    }

    @discardableResult
    func addPartnerTurn(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.saveHistory, !settings.historyPaused, !isPrivateConversationActive,
              !isBoardOnlyModeActive, !clean.isEmpty, clean.count <= 1_000 else { return false }
        history.insert(.init(text: clean, speaker: .partner, inputMode: .manualNote), at: 0)
        if history.count > 50 { history.removeLast(history.count - 50) }
        save()
        return true
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    @discardableResult
    func saveReadingDocument(title: String, pages: [String], existingID: UUID? = nil) throws -> UUID {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ReadingLibraryError.emptyTitle }
        guard pages.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ReadingLibraryError.emptyText
        }
        let document = SavedReadingDocument(id: existingID ?? UUID(), title: cleanTitle, pages: pages)
        guard document.characterCount <= SavedReadingDocument.maximumDocumentCharacters else {
            throw ReadingLibraryError.documentTooLong
        }
        var updated = savedReadingDocuments
        if let index = updated.firstIndex(where: { $0.id == existingID }) {
            updated[index] = document
        } else {
            updated.append(document)
        }
        let totalCharacters = updated.reduce(0) { $0 + $1.characterCount }
        guard updated.count <= SavedReadingDocument.maximumDocuments,
              totalCharacters <= SavedReadingDocument.maximumLibraryCharacters else {
            throw ReadingLibraryError.libraryFull
        }
        savedReadingDocuments = updated.sorted { $0.updatedAt > $1.updatedAt }
        save()
        return document.id
    }

    func deleteReadingDocument(id: UUID) {
        savedReadingDocuments.removeAll { $0.id == id }
        save()
    }

    @discardableResult
    func saveNote(id: UUID? = nil, title: String, topic: String, text: String) -> Bool {
        guard !isBoardOnlyModeActive else { return false }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanText.isEmpty else { return false }
        let cleanTopic = notes.first {
            $0.topic.localizedCaseInsensitiveCompare(requestedTopic) == .orderedSame
        }?.topic ?? (requestedTopic.isEmpty ? "General" : requestedTopic)
        if let id {
            guard let index = notes.firstIndex(where: { $0.id == id }) else { return false }
            var note = notes.remove(at: index)
            note.title = cleanTitle
            note.topic = cleanTopic
            note.text = cleanText
            note.updatedAt = .now
            notes.insert(note, at: 0)
        } else {
            notes.insert(CommunicationNote(title: cleanTitle, topic: cleanTopic,
                                           text: cleanText), at: 0)
        }
        save()
        return true
    }

    @discardableResult
    func deleteNote(id: UUID) -> Bool {
        guard !isBoardOnlyModeActive, let index = notes.firstIndex(where: { $0.id == id }) else { return false }
        notes.remove(at: index)
        save()
        return true
    }

    func clearLearnedPrediction() {
        learnedPrediction.clear()
        save()
    }

    @discardableResult
    func saveFeelingEntry(label: String, symbol: String, intensity: Int,
                          support: String?, message: String) -> Bool {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.saveFeelingsLog, !cleanLabel.isEmpty, !cleanMessage.isEmpty,
              (1...5).contains(intensity) else { return false }
        feelingsLog.insert(FeelingLogEntry(feelingLabel: cleanLabel, symbol: symbol,
                                           intensity: intensity, support: support,
                                           message: cleanMessage,
                                           language: settings.communicationLanguage), at: 0)
        save()
        return true
    }

    @discardableResult
    func savePainEntry(message: String, intensity: Int) -> Bool {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.saveFeelingsLog, !cleanMessage.isEmpty,
              (0...settings.painScaleMaximum).contains(intensity) else { return false }
        feelingsLog.insert(FeelingLogEntry(
            feelingLabel: settings.communicationLanguage == "es" ? "Dolor" : "Pain",
            symbol: "🩹", intensity: intensity, support: nil,
            message: cleanMessage, language: settings.communicationLanguage,
            scaleMaximum: settings.painScaleMaximum), at: 0)
        save()
        return true
    }

    func deleteFeelingEntry(id: UUID) {
        feelingsLog.removeAll { $0.id == id }
        save()
    }

    func clearFeelingsLog() {
        feelingsLog.removeAll()
        save()
    }

    func updatePassport(_ updated: CommunicationPassport) {
        passport = updated
        save()
    }

    func addStory(_ title: String) -> UUID? {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let story = VisualStory(title: clean)
        stories.append(story)
        save()
        return story.id
    }

    @discardableResult
    func importStory(_ data: Data) throws -> VisualStory {
        var imported = try StoryTransfer.importStory(data)
        let baseTitle = imported.title
        var candidate = baseTitle
        var suffix = 2
        while stories.contains(where: {
            $0.title.localizedCaseInsensitiveCompare(candidate) == .orderedSame
        }) {
            candidate = "\(baseTitle) (imported \(suffix))"
            suffix += 1
        }
        imported.title = candidate
        stories.append(imported)
        save()
        return imported
    }

    func renameStory(id: UUID, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = stories.firstIndex(where: { $0.id == id }) else { return }
        stories[index].title = clean
        save()
    }

    func deleteStory(id: UUID) {
        stories.removeAll { $0.id == id }
        save()
    }

    func addStoryPage(storyID: UUID, text: String, symbol: String, imageData: Data?, audioData: Data? = nil,
                      videoData: Data? = nil, videoPosterData: Data? = nil,
                      additionalImageData: [Data] = [],
                      backgroundStyle: StoryBackgroundStyle = .plain,
                      backgroundPhotoData: Data? = nil) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = stories.firstIndex(where: { $0.id == storyID }) else { return }
        let page = StoryPage(text: clean, symbol: symbol.isEmpty ? "📖" : symbol,
                             imageData: imageData, additionalImageData: additionalImageData,
                             backgroundStyle: backgroundStyle, backgroundPhotoData: backgroundPhotoData,
                             audioData: audioData?.isEmpty == true ? nil : audioData,
                             videoData: videoData, videoPosterData: videoPosterData)
        guard page.hasValidVideoMedia && page.hasValidPhotoMedia && page.hasValidBackgroundMedia else { return }
        stories[index].pages.append(page)
        save()
    }

    @discardableResult
    func readStoryPage(storyID: UUID, pageID: UUID, usingSystemVoice: Bool = false) -> UUID? {
        guard let page = stories.first(where: { $0.id == storyID })?.pages.first(where: { $0.id == pageID }) else { return nil }
        let playbackID = UUID()
        if !usingSystemVoice, let data = page.audioData, (try? AVAudioPlayer(data: data)) != nil {
            playRecorded(data, storyPlaybackID: playbackID)
        } else {
            if page.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stopSpeaking()
                completedStoryPlaybackID = playbackID
            } else {
                speak(page.text, followAlong: .story(storyID: storyID, pageID: pageID))
                activeStoryPlaybackID = playbackID
            }
        }
        return playbackID
    }

    func updateStoryPage(storyID: UUID, page: StoryPage) {
        guard let storyIndex = stories.firstIndex(where: { $0.id == storyID }),
              let pageIndex = stories[storyIndex].pages.firstIndex(where: { $0.id == page.id }),
              page.hasValidVideoMedia && page.hasValidPhotoMedia && page.hasValidBackgroundMedia else { return }
        var cleanedPage = page
        cleanedPage.choices = StoryChoice.cleaned(page.choices,
            validTargets: Set(stories[storyIndex].pages.map(\.id)).subtracting([page.id]))
        stories[storyIndex].pages[pageIndex] = cleanedPage
        save()
    }

    func deleteStoryPage(storyID: UUID, pageID: UUID) {
        guard let index = stories.firstIndex(where: { $0.id == storyID }) else { return }
        stories[index].pages.removeAll { $0.id == pageID }
        for pageIndex in stories[index].pages.indices {
            stories[index].pages[pageIndex].choices.removeAll { $0.targetPageID == pageID }
        }
        save()
    }

    @discardableResult
    func addRewardChart(title: String, reward: String, symbol: String = "⭐️",
                        targetTokens: Int = 5, photoData: Data? = nil) -> RewardChart? {
        let chart = RewardChart(title: title, reward: reward, symbol: symbol,
                                targetTokens: targetTokens, photoData: photoData)
        guard chart.isValid else { return nil }
        rewardCharts.append(chart)
        save()
        return chart
    }

    @discardableResult
    func updateRewardChart(_ chart: RewardChart) -> Bool {
        guard let index = rewardCharts.firstIndex(where: { $0.id == chart.id }) else { return false }
        let cleaned = RewardChart(id: chart.id, title: chart.title, reward: chart.reward,
                                  symbol: chart.symbol, targetTokens: chart.targetTokens,
                                  earnedTokens: rewardCharts[index].earnedTokens, photoData: chart.photoData)
        guard cleaned.isValid else { return false }
        rewardCharts[index] = cleaned
        save()
        return true
    }

    @discardableResult
    func deleteRewardChart(id: UUID) -> Bool {
        guard let index = rewardCharts.firstIndex(where: { $0.id == id }) else { return false }
        rewardCharts.remove(at: index)
        for index in routineTemplates.indices where routineTemplates[index].rewardChartID == id {
            routineTemplates[index].rewardChartID = nil
        }
        weeklyPlan.removeMissingRewardCharts(validIDs: Set(rewardCharts.map(\.id)))
        visualCalendar.removeMissingRewardCharts(validIDs: Set(rewardCharts.map(\.id)))
        save()
        return true
    }

    @discardableResult
    func setRewardChartTokens(id: UUID, count: Int) -> Bool {
        guard let index = rewardCharts.firstIndex(where: { $0.id == id }),
              rewardCharts[index].setEarnedTokens(count) else { return false }
        save()
        return true
    }

    @discardableResult
    func startRewardChartAgain(id: UUID) -> Bool {
        guard let index = rewardCharts.firstIndex(where: { $0.id == id }),
              rewardCharts[index].startAgain() else { return false }
        save()
        return true
    }

    @discardableResult
    func collectReward(id: UUID) -> RewardCollectible? {
        guard let index = rewardCharts.firstIndex(where: { $0.id == id }),
              rewardCharts[index].isComplete else { return nil }
        let collectible = RewardCollectible(chart: rewardCharts[index])
        rewardCollectibles.insert(collectible, at: 0)
        rewardCharts[index].startAgain()
        save()
        return collectible
    }

    @discardableResult
    func deleteRewardCollectible(id: UUID) -> Bool {
        guard let index = rewardCollectibles.firstIndex(where: { $0.id == id }) else { return false }
        rewardCollectibles.remove(at: index)
        save()
        return true
    }

    func addRoutineStep(_ title: String, symbol: String = "⭐️", durationSeconds: Int? = nil) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, RoutineStep.acceptsDuration(durationSeconds) else { return }
        routines.append(.init(title: clean, symbol: symbol, durationSeconds: durationSeconds))
        save()
    }

    @discardableResult
    func saveRoutineStep(_ step: RoutineStep) -> Bool {
        var updated = step
        updated.title = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.title.isEmpty, RoutineStep.acceptsDuration(step.durationSeconds),
              updated.hasValidVideoMedia,
              updated.choiceBoardID.map({ id in choiceBoards.contains { $0.id == id } }) ?? true else { return false }
        updated.symbol = step.symbol.isEmpty ? "⭐️" : step.symbol
        updated.spokenText = step.spokenText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if updated.spokenText?.isEmpty == true { updated.spokenText = nil }
        if let index = routines.firstIndex(where: { $0.id == step.id }) {
            updated.isComplete = routines[index].isComplete
            routines[index] = updated
        } else {
            routines.append(updated)
        }
        save()
        return true
    }

    func setRoutineStepDuration(stepID: UUID, durationSeconds: Int?) {
        guard let index = routines.firstIndex(where: { $0.id == stepID }),
              RoutineStep.acceptsDuration(durationSeconds) else { return }
        routines[index].durationSeconds = durationSeconds
        save()
    }

    func toggleRoutineStep(_ step: RoutineStep) {
        guard let index = routines.firstIndex(where: { $0.id == step.id }) else { return }
        routines[index].isComplete.toggle()
        save()
    }

    func deleteRoutineStep(_ step: RoutineStep) {
        routines.removeAll { $0.id == step.id }
        save()
    }

    func moveRoutineSteps(from source: IndexSet, to destination: Int) {
        guard destination >= 0, destination <= routines.count,
              source.allSatisfy({ routines.indices.contains($0) }) else { return }
        let moved = source.map { routines[$0] }
        for index in source.sorted(by: >) { routines.remove(at: index) }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        routines.insert(contentsOf: moved, at: adjustedDestination)
        save()
    }

    func resetRoutine() {
        for index in routines.indices { routines[index].isComplete = false }
        save()
    }

    @discardableResult
    func saveRoutineTemplate(name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !routines.isEmpty,
              !routineTemplates.contains(where: { $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else {
            return false
        }
        routineTemplates.append(RoutineTemplate(name: clean, steps: routines))
        save()
        return true
    }

    @discardableResult
    func updateRoutineTemplate(id: UUID) -> Bool {
        guard let index = routineTemplates.firstIndex(where: { $0.id == id }), !routines.isEmpty else { return false }
        routineTemplates[index].steps = RoutineTemplate(name: routineTemplates[index].name, steps: routines).steps
        save()
        return true
    }

    @discardableResult
    func renameRoutineTemplate(id: UUID, name: String) -> Bool {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = routineTemplates.firstIndex(where: { $0.id == id }), !clean.isEmpty,
              !routineTemplates.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else {
            return false
        }
        routineTemplates[index].name = clean
        save()
        Task { await restoreRoutineReminders() }
        return true
    }

    @discardableResult
    func loadRoutineTemplate(id: UUID) -> Bool {
        guard let template = routineTemplates.first(where: { $0.id == id }), !template.steps.isEmpty else { return false }
        routines = template.freshSteps()
        save()
        return true
    }

    func deleteRoutineTemplate(id: UUID) {
        for reminder in routineReminders where reminder.templateID == id {
            RoutineReminderManager.cancel(reminder, profileID: activeProfileID)
        }
        routineReminders.removeAll { $0.templateID == id }
        routineTemplates.removeAll { $0.id == id }
        save()
    }

    @discardableResult
    func addRoutineReminder(_ reminder: RoutineReminder) -> Bool {
        guard reminder.isValid, routineTemplates.contains(where: { $0.id == reminder.templateID }),
              !routineReminders.contains(where: { $0.id == reminder.id }) else { return false }
        routineReminders.append(reminder)
        save()
        return true
    }

    func deleteRoutineReminder(id: UUID) {
        guard let reminder = routineReminders.first(where: { $0.id == id }) else { return }
        RoutineReminderManager.cancel(reminder, profileID: activeProfileID)
        routineReminders.removeAll { $0.id == id }
        save()
    }

    func restoreRoutineReminders() async {
        let plans = profiles.flatMap { profile -> [RoutineReminderPlan] in
            let templates: [RoutineTemplate]
            let reminders: [RoutineReminder]
            if profile.id == activeProfileID {
                templates = routineTemplates
                reminders = routineReminders
            } else {
                let stored = Self.readData(from: baseURL.deletingLastPathComponent().appendingPathComponent(profile.fileName))
                templates = stored.routineTemplates
                reminders = stored.routineReminders
            }
            return reminders.compactMap { reminder in
                guard reminder.isValid,
                      let template = templates.first(where: { $0.id == reminder.templateID }) else { return nil }
                return RoutineReminderPlan(profileID: profile.id, profileName: profile.name,
                                           templateName: template.name, reminder: reminder)
            }
        }
        await RoutineReminderManager.restore(plans)
    }

    func restoreAllReminders() async {
        let activePlans = Self.reminderPlans(profileID: activeProfileID,
                                             profileName: activeProfileName,
                                             templates: routineTemplates,
                                             reminders: routineReminders,
                                             weeklyPlan: weeklyPlan,
                                             calendar: visualCalendar)
        let directory = baseURL.deletingLastPathComponent()
        let otherProfiles = profiles.filter { $0.id != activeProfileID }
            .map { (id: $0.id, name: $0.name, url: directory.appendingPathComponent($0.fileName)) }
        let otherPlans = await Task.detached(priority: .utility) {
            ProfilePersistenceWriter.shared.flush()
            var plans = ReminderRestorePlans()
            for profile in otherProfiles {
                guard let data = try? Data(contentsOf: profile.url),
                      let stored = try? JSONDecoder().decode(ReminderProfileSnapshot.self, from: data) else { continue }
                plans.append(Self.reminderPlans(profileID: profile.id,
                                                profileName: profile.name,
                                                templates: stored.routineTemplates,
                                                reminders: stored.routineReminders,
                                                weeklyPlan: stored.weeklyPlan,
                                                calendar: stored.visualCalendar))
            }
            return plans
        }.value
        guard !Task.isCancelled else { return }
        var plans = activePlans
        plans.append(otherPlans)
        await RoutineReminderManager.restore(plans.routines)
        await WeeklyReminderManager.restore(plans.weekly)
        await CalendarReminderManager.restore(plans.calendar)
    }

    nonisolated private static func reminderPlans(profileID: UUID, profileName: String,
                                                  templates: [RoutineTemplate],
                                                  reminders: [RoutineReminder],
                                                  weeklyPlan: WeeklyPlan,
                                                  calendar: VisualCalendar) -> ReminderRestorePlans {
        var plans = ReminderRestorePlans()
        let templatesByID = Dictionary(templates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        plans.routines = reminders.compactMap { reminder in
            guard reminder.isValid, let template = templatesByID[reminder.templateID] else { return nil }
            return RoutineReminderPlan(profileID: profileID, profileName: profileName,
                                       templateName: template.name, reminder: reminder)
        }
        plans.weekly = weeklyPlan.reminders.compactMap { reminder in
            guard reminder.isValid,
                  let activity = weeklyPlan.activities(on: reminder.weekday)
                    .first(where: { $0.id == reminder.activityID }) else { return nil }
            return WeeklyReminderPlan(profileID: profileID, activityName: activity.option.label,
                                      reminder: reminder)
        }
        plans.calendar = calendar.events.filter { $0.reminder?.isValid == true }.map {
            CalendarReminderPlan(profileID: profileID, event: $0)
        }
        return plans
    }

    func setRoutineTemplateLayout(id: UUID, layout: FirstThenLayout) {
        guard let index = routineTemplates.firstIndex(where: { $0.id == id }) else { return }
        routineTemplates[index].firstThenLayout = layout
        save()
    }

    func setRoutineTemplateMode(id: UUID, mode: RoutineBoardMode) {
        guard let index = routineTemplates.firstIndex(where: { $0.id == id }) else { return }
        routineTemplates[index].boardMode = mode
        save()
    }

    @discardableResult
    func setRoutineTemplateRewardChart(id: UUID, chartID: UUID?) -> Bool {
        guard let index = routineTemplates.firstIndex(where: { $0.id == id }),
              chartID == nil || rewardCharts.contains(where: { $0.id == chartID }) else { return false }
        routineTemplates[index].rewardChartID = chartID
        save()
        return true
    }

    @discardableResult
    func setRoutineTemplateRewardFrequency(id: UUID, frequency: RoutineRewardFrequency) -> Bool {
        guard let index = routineTemplates.firstIndex(where: { $0.id == id }) else { return false }
        routineTemplates[index].rewardFrequency = frequency
        save()
        return true
    }

    @discardableResult
    func awardRoutineCompletion(templateID: UUID) -> RewardChart? {
        guard let chartID = routineTemplates.first(where: { $0.id == templateID })?.rewardChartID,
              let index = rewardCharts.firstIndex(where: { $0.id == chartID }),
              rewardCharts[index].setEarnedTokens(rewardCharts[index].earnedTokens + 1) else { return nil }
        save()
        return rewardCharts[index]
    }

    @discardableResult
    func recordRoutineRun(outcome: RoutineRun.Outcome, at date: Date = .now) -> Bool {
        guard !routines.isEmpty else { return false }
        if outcome == .completed && routines.contains(where: { !$0.isComplete }) { return false }
        routineHistory.insert(RoutineRun(outcome: outcome, steps: routines, recordedAt: date), at: 0)
        save()
        return true
    }

    func deleteRoutineRun(id: UUID) {
        routineHistory.removeAll { $0.id == id }
        save()
    }

    @discardableResult
    func addWeeklyActivity(_ activity: WeeklyActivity, on weekday: Int) -> Bool {
        guard !calendarEditingBlocked,
              activity.rewardChartID.map({ id in rewardCharts.contains(where: { $0.id == id }) }) ?? true,
              weeklyPlan.add(activity, on: weekday) else { return false }
        save()
        return true
    }

    @discardableResult
    func updateWeeklyActivity(_ activity: WeeklyActivity, on weekday: Int) -> Bool {
        var updated = activity
        if let previous = weeklyPlan.activities(on: weekday).first(where: { $0.id == activity.id }) {
            updated.rewardedDates = previous.rewardChartID == activity.rewardChartID
                ? previous.rewardedDates : nil
        }
        guard !calendarEditingBlocked,
              updated.rewardChartID.map({ id in rewardCharts.contains(where: { $0.id == id }) }) ?? true,
              weeklyPlan.update(updated, on: weekday) else { return false }
        save()
        if weeklyPlan.reminders.contains(where: { $0.weekday == weekday && $0.activityID == activity.id }) {
            Task { await restoreWeeklyReminders() }
        }
        return true
    }

    func deleteWeeklyActivity(id: UUID, on weekday: Int) {
        guard !calendarEditingBlocked else { return }
        let previous = weeklyPlan.reminders.first { $0.weekday == weekday && $0.activityID == id }
        weeklyPlan.delete(id: id, on: weekday)
        save()
        if let previous { WeeklyReminderManager.cancel(previous, profileID: activeProfileID) }
    }

    @discardableResult
    func setWeeklyReminder(_ reminder: WeeklyActivityReminder) -> Bool {
        guard !calendarEditingBlocked, weeklyPlan.setReminder(reminder) else { return false }
        save()
        return true
    }

    func deleteWeeklyReminder(activityID: UUID, on weekday: Int) {
        guard !calendarEditingBlocked,
              let reminder = weeklyPlan.reminders.first(where: { $0.weekday == weekday && $0.activityID == activityID }) else { return }
        weeklyPlan.deleteReminder(activityID: activityID, on: weekday)
        save()
        WeeklyReminderManager.cancel(reminder, profileID: activeProfileID)
    }

    func restoreWeeklyReminders() async {
        let plans = profiles.flatMap { profile -> [WeeklyReminderPlan] in
            let plan = profile.id == activeProfileID ? weeklyPlan :
                Self.readData(from: baseURL.deletingLastPathComponent().appendingPathComponent(profile.fileName)).weeklyPlan
            return plan.reminders.compactMap { reminder in
                guard reminder.isValid,
                      let activity = plan.activities(on: reminder.weekday).first(where: { $0.id == reminder.activityID }) else { return nil }
                return WeeklyReminderPlan(profileID: profile.id, activityName: activity.option.label,
                                          reminder: reminder)
            }
        }
        await WeeklyReminderManager.restore(plans)
    }

    func toggleWeeklyActivity(id: UUID, on weekday: Int, date: Date) {
        let before = weeklyPlan.activities(on: weekday).first(where: { $0.id == id })
        let wasComplete = before?.isComplete(on: date) == true
        weeklyPlan.toggle(id: id, on: weekday, date: date)
        if !wasComplete,
           let activity = weeklyPlan.activities(on: weekday).first(where: { $0.id == id }),
           activity.isComplete(on: date), !activity.hasEarnedReward(on: date),
           let chartID = activity.rewardChartID,
           let chartIndex = rewardCharts.firstIndex(where: { $0.id == chartID }),
           rewardCharts[chartIndex].earnedTokens < rewardCharts[chartIndex].targetTokens,
           weeklyPlan.markRewarded(id: id, on: weekday, date: date) {
            _ = rewardCharts[chartIndex].setEarnedTokens(rewardCharts[chartIndex].earnedTokens + 1)
        }
        save()
    }

    func moveWeeklyActivities(on weekday: Int, from source: IndexSet, to destination: Int) {
        guard !calendarEditingBlocked else { return }
        if weeklyPlan.move(on: weekday, from: source, to: destination) { save() }
    }

    @discardableResult
    func copyWeeklyDay(from source: Int, to destination: Int) -> Bool {
        guard !calendarEditingBlocked else { return false }
        let previous = weeklyPlan.reminders.filter { $0.weekday == destination }
        guard weeklyPlan.copy(from: source, to: destination) else { return false }
        save()
        for reminder in previous { WeeklyReminderManager.cancel(reminder, profileID: activeProfileID) }
        Task { await restoreWeeklyReminders() }
        return true
    }

    @discardableResult
    func saveWeeklyTemplate(title: String, from weekday: Int) -> Bool {
        guard !calendarEditingBlocked, weeklyPlan.saveTemplate(title: title, from: weekday) else { return false }
        save()
        return true
    }

    @discardableResult
    func applyWeeklyTemplate(id: UUID, to weekday: Int) -> Bool {
        guard !calendarEditingBlocked else { return false }
        let previous = weeklyPlan.reminders.filter { $0.weekday == weekday }
        guard weeklyPlan.applyTemplate(id: id, to: weekday) else { return false }
        save()
        for reminder in previous { WeeklyReminderManager.cancel(reminder, profileID: activeProfileID) }
        Task { await restoreWeeklyReminders() }
        return true
    }

    func deleteWeeklyTemplate(id: UUID) {
        guard !calendarEditingBlocked else { return }
        weeklyPlan.deleteTemplate(id: id)
        save()
    }

    var calendarEditingBlocked: Bool {
        visualCalendar.isEditingLocked && !isCalendarEditingUnlocked
    }

    func enableCalendarEditingLock(pin: String) throws {
        guard !calendarEditingBlocked else { throw CalendarEditingAccessError.locked }
        try CalendarEditingPINStore.save(pin, for: activeProfileID)
        visualCalendar.editingLocked = true
        isCalendarEditingUnlocked = false
        save()
    }

    @discardableResult
    func unlockCalendarEditing(pin: String) -> Bool {
        guard visualCalendar.isEditingLocked,
              CalendarEditingPINStore.matches(pin, for: activeProfileID) else { return false }
        isCalendarEditingUnlocked = true
        return true
    }

    func lockCalendarEditing() {
        isCalendarEditingUnlocked = false
    }

    @discardableResult
    func disableCalendarEditingLock() -> Bool {
        guard visualCalendar.isEditingLocked, isCalendarEditingUnlocked else { return false }
        CalendarEditingPINStore.delete(for: activeProfileID)
        visualCalendar.editingLocked = false
        isCalendarEditingUnlocked = false
        save()
        return true
    }

    @discardableResult
    func addCalendarEvent(_ event: CalendarEvent) -> Bool {
        guard !calendarEditingBlocked else { return false }
        var updated = event
        if let id = updated.rewardChartID, !rewardCharts.contains(where: { $0.id == id }) {
            updated.rewardChartID = nil
            updated.rewardedDates = nil
        }
        guard visualCalendar.add(updated) else { return false }
        save()
        return true
    }

    func setCalendarAppearance(_ appearance: CalendarAppearance) {
        guard !calendarEditingBlocked else { return }
        visualCalendar.appearance = appearance.cleaned()
        save()
    }

    @discardableResult
    func updateCalendarEvent(_ event: CalendarEvent) -> Bool {
        guard !calendarEditingBlocked else { return false }
        let previous = visualCalendar.events.first { $0.id == event.id }
        var updated = event
        if let id = updated.rewardChartID, !rewardCharts.contains(where: { $0.id == id }) {
            updated.rewardChartID = nil
        }
        updated.rewardedDates = updated.rewardChartID == previous?.rewardChartID
            ? previous?.rewardedDates : nil
        guard visualCalendar.update(updated) else { return false }
        save()
        if let previous, previous.reminder != nil && updated.reminder == nil {
            CalendarReminderManager.cancel(previous, profileID: activeProfileID)
        } else if previous?.reminder != nil || updated.reminder != nil {
            Task { await restoreCalendarReminders() }
        }
        return true
    }

    func deleteCalendarEvent(id: UUID) {
        guard !calendarEditingBlocked else { return }
        if let event = visualCalendar.events.first(where: { $0.id == id }) {
            CalendarReminderManager.cancel(event, profileID: activeProfileID)
        }
        visualCalendar.delete(id: id)
        save()
    }

    @discardableResult
    func setCalendarReminder(_ reminder: CalendarEventReminder, eventID: UUID) -> Bool {
        guard !calendarEditingBlocked, reminder.isValid,
              let index = visualCalendar.events.firstIndex(where: { $0.id == eventID }) else {
            return false
        }
        visualCalendar.events[index].reminder = reminder
        save()
        return true
    }

    func deleteCalendarReminder(eventID: UUID) {
        guard !calendarEditingBlocked,
              let index = visualCalendar.events.firstIndex(where: { $0.id == eventID }) else { return }
        CalendarReminderManager.cancel(visualCalendar.events[index], profileID: activeProfileID)
        visualCalendar.events[index].reminder = nil
        save()
    }

    func restoreCalendarReminders() async {
        let plans = profiles.flatMap { profile -> [CalendarReminderPlan] in
            let calendar = profile.id == activeProfileID ? visualCalendar :
                Self.readData(from: baseURL.deletingLastPathComponent()
                    .appendingPathComponent(profile.fileName)).visualCalendar
            return calendar.events.filter { $0.reminder?.isValid == true }.map {
                CalendarReminderPlan(profileID: profile.id, event: $0)
            }
        }
        await CalendarReminderManager.restore(plans)
    }

    func toggleCalendarEvent(id: UUID, on date: Date) {
        guard let event = visualCalendar.events.first(where: { $0.id == id }),
              event.occurs(on: date) else { return }
        let wasComplete = event.isComplete(on: date)
        visualCalendar.toggleComplete(id: id, on: date)
        if !wasComplete, let chartID = event.rewardChartID,
           !event.hasEarnedReward(on: date),
           let chartIndex = rewardCharts.firstIndex(where: { $0.id == chartID }),
           rewardCharts[chartIndex].earnedTokens < rewardCharts[chartIndex].targetTokens {
            rewardCharts[chartIndex].earnedTokens += 1
            visualCalendar.markRewarded(id: id, on: date)
        }
        save()
    }

    func backupData() throws -> Data {
        guard !isSavingPictureLibrary else { throw PictureLibraryError.busy }
        guard !isSavingLifeNotebook else { throw LifeNotebookError.busy }
        updateActiveConversation(immediately: true)
        return try JSONEncoder().encode(StoredData(items: items, categories: categories, routines: routines,
                                            routineHistory: routineHistory,
                                            routineTemplates: routineTemplates,
                                            routineReminders: routineReminders,
                                            phrases: phrases, jokes: jokes, history: history,
                                            usageEvents: usageEvents, notes: notes,
                                            lifeNotebookPosts: try LifeNotebookDiskStore.load(
                                                for: activeProfileID, in: baseURL.deletingLastPathComponent()),
                                            savedReadingDocuments: savedReadingDocuments,
                                            learnedPrediction: learnedPrediction,
                                            feelingsLog: feelingsLog, stories: stories,
                                            choiceBoards: choiceBoards, sceneBoards: sceneBoards,
                                            weeklyPlan: weeklyPlan, visualCalendar: visualCalendar,
                                            rewardCharts: rewardCharts, rewardCollectibles: rewardCollectibles,
                                             settings: settings, passport: passport,
                                             wordTranslations: wordTranslations,
                                             conversations: conversations, activeConversationID: activeConversationID,
                                             drawingStrokes: drawingStrokes, speechTopics: speechTopics,
                                             nearbyMessages: nearbyMessages,
                                             nearbyChatSavingEnabled: nearbyChatSavingEnabled,
                                             pictureLibrary: try PictureLibraryDiskStore.load(
                                                for: activeProfileID, in: baseURL.deletingLastPathComponent())))
    }

    private var localBackupLibrary: LocalBackupLibrary {
        LocalBackupLibrary(baseURL: baseURL.deletingLastPathComponent())
    }

    func localBackups() throws -> [LocalBackupSnapshot] {
        try localBackupLibrary.list(profileID: activeProfileID)
    }

    @discardableResult
    func createLocalBackup(named name: String) throws -> LocalBackupSnapshot {
        try localBackupLibrary.create(name: name, profileID: activeProfileID,
                                      profileName: activeProfileName, data: backupData())
    }

    func localBackupData(id: UUID) throws -> Data {
        try localBackupLibrary.load(id: id, profileID: activeProfileID)
    }

    func localBackupDataAsync(id: UUID) async throws -> Data {
        let directory = baseURL.deletingLastPathComponent()
        let profileID = activeProfileID
        return try await Task.detached(priority: .userInitiated) { @Sendable in
            try LocalBackupLibrary(baseURL: directory).loadRaw(id: id, profileID: profileID)
        }.value
    }

    func deleteLocalBackup(id: UUID) throws {
        try localBackupLibrary.delete(id: id, profileID: activeProfileID)
    }

    func openBoardArchiveData() throws -> Data {
        try OpenBoardFormat.exportArchive(profileName: activeProfileName, categories: categories,
                                          items: localizedItems(), language: settings.communicationLanguage,
                                          layouts: settings.boardGridLayouts,
                                          defaultLayout: settings.defaultBoardGridLayout,
                                          emptyPositions: settings.boardEmptySlots)
    }

    func openBoardData(named name: String) throws -> Data {
        try OpenBoardFormat.exportBoard(name: name, items: localizedItems(),
                                       language: settings.communicationLanguage,
                                       layout: gridLayout(for: name),
                                       emptyPositions: emptyGridPositions(in: name))
    }

    func addOpenBoards(_ imported: ImportedOpenBoards) {
        var used = categories
        var renamed: [String: String] = [:]
        for name in imported.categories {
            var candidate = name
            var suffix = 2
            while used.contains(where: { $0.localizedCaseInsensitiveCompare(candidate) == .orderedSame }) {
                candidate = "\(name) (imported \(suffix))"
                suffix += 1
            }
            used.append(candidate)
            renamed[name] = candidate
        }
        categories = used
        for (name, layout) in imported.layouts {
            if let target = renamed[name] { settings.boardGridLayouts[target] = layout }
        }
        for (name, positions) in imported.emptyPositions {
            if let target = renamed[name] { settings.boardEmptySlots[target] = positions }
        }
        items.append(contentsOf: imported.items.map { source in
            var item = source
            item.id = UUID()
            item.category = renamed[source.category] ?? source.category
            item.destinationBoard = source.destinationBoard.flatMap { renamed[$0] }
            return item
        })
        save()
    }

    func qrCodeForBoard(_ name: String) throws -> String {
        guard categories.contains(name), !isBoardOnlyModeActive else {
            throw QRPageTransferError.boardUnavailable
        }
        return try QRPageTransfer.encode(title: name, icon: settings.boardIcons[name],
                                         items: items.filter { $0.category == name },
                                         translations: wordTranslations)
    }

    @discardableResult
    func addQRPage(_ page: QRPageContent) -> String? {
        guard !isBoardOnlyModeActive else { return nil }
        let base = page.title
        var name = base
        var suffix = 2
        while categories.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            name = "\(base) (imported \(suffix))"
            suffix += 1
        }
        categories.append(name)
        for tile in page.tiles {
            let item = CommunicationItem(label: tile.label, symbol: tile.symbol,
                                         message: tile.message, category: name, isCustom: true,
                                         visibility: tile.visibility,
                                         action: tile.action,
                                         backgroundColorHex: tile.backgroundColorHex,
                                         borderColorHex: tile.borderColorHex,
                                         grammarCategory: tile.grammarCategory)
            items.append(item)
            if let spanish = tile.spanish {
                wordTranslations[item.id.uuidString] = ["es": spanish]
            }
        }
        if let icon = page.icon { settings.boardIcons[name] = icon }
        save()
        return name
    }

    func localizedItems(excludingPredictionKeys: Bool = false) -> [CommunicationItem] {
        items.filter { !excludingPredictionKeys || $0.effectiveAction != .completeTypedPrediction }.map { source in
            var item = source
            if source.effectiveAction != .completeTypedPrediction {
                item.label = displayLabel(for: source)
                item.message = displayMessage(for: source)
            }
            return item
        }
    }

    func importBackup(_ data: Data) throws {
        guard !isSavingPictureLibrary else { throw PictureLibraryError.busy }
        guard !isSavingLifeNotebook else { throw LifeNotebookError.busy }
        let restored = try JSONDecoder().decode(StoredData.self, from: data)
        guard !restored.items.isEmpty else { throw BackupError.emptyVocabulary }
        try LifeNotebookDiskStore.validate(restored.lifeNotebookPosts)
        try PictureLibraryDiskStore.save(restored.pictureLibrary, for: activeProfileID,
                                         in: baseURL.deletingLastPathComponent())
        try LifeNotebookDiskStore.save(restored.lifeNotebookPosts, for: activeProfileID,
                                       in: baseURL.deletingLastPathComponent())
        if isPrivateConversationActive { endPrivateConversation() }
        let availableChoiceBoardIDs = Set(restored.choiceBoards.map(\.id))
        let previousReminders = routineReminders
        let previousWeeklyReminders = weeklyPlan.reminders
        let previousCalendarReminders = visualCalendar.events.filter { $0.reminder != nil }
        draftSaveTask?.cancel()
        isLoadingConversation = true
        items = restored.items
        categories = restored.categories
        routines = restored.routines.map { step in
            var copy = step
            if let id = copy.choiceBoardID, !availableChoiceBoardIDs.contains(id) {
                copy.choiceBoardID = nil
            }
            return copy
        }
        routineHistory = restored.routineHistory
        routineTemplates = restored.routineTemplates.map { template in
            var copy = template
            if let chartID = copy.rewardChartID,
               !restored.rewardCharts.contains(where: { $0.id == chartID }) {
                copy.rewardChartID = nil
            }
            copy.steps = template.steps.map { step in
                var linkedStep = step
                if let id = linkedStep.choiceBoardID, !availableChoiceBoardIDs.contains(id) {
                    linkedStep.choiceBoardID = nil
                }
                return linkedStep
            }
            return copy
        }
        routineReminders = restored.routineReminders.filter { reminder in
            reminder.isValid && restored.routineTemplates.contains(where: { $0.id == reminder.templateID })
        }
        phrases = restored.phrases
        jokes = restored.jokes
        history = restored.history
        usageEvents = restored.usageEvents
        notes = restored.notes
        lifeNotebookPosts = restored.lifeNotebookPosts.sorted { $0.occurredAt > $1.occurredAt }
        loadedLifeNotebookProfileID = activeProfileID
        savedReadingDocuments = restored.savedReadingDocuments
        pictureLibrary = restored.pictureLibrary
        loadedPictureLibraryProfileID = activeProfileID
        learnedPrediction = restored.learnedPrediction
        feelingsLog = restored.feelingsLog
        stories = restored.stories
        choiceBoards = restored.choiceBoards
        sceneBoards = restored.sceneBoards
        weeklyPlan = restored.weeklyPlan
        visualCalendar = restored.visualCalendar
        rewardCharts = restored.rewardCharts
        weeklyPlan.removeMissingRewardCharts(validIDs: Set(rewardCharts.map(\.id)))
        visualCalendar.removeMissingRewardCharts(validIDs: Set(rewardCharts.map(\.id)))
        rewardCollectibles = restored.rewardCollectibles
        isCalendarEditingUnlocked = false
        if visualCalendar.isEditingLocked && CalendarEditingPINStore.isMissing(for: activeProfileID) {
            visualCalendar.editingLocked = false
        }
        passport = restored.passport
        wordTranslations = restored.wordTranslations
        settings = restored.settings
        settings.boardOnlyModeActive = false
        conversations = restored.conversations
        activeConversationID = restored.activeConversationID
        drawingStrokes = restored.drawingStrokes
        speechTopics = restored.speechTopics
        nearbyMessages = restored.nearbyMessages
        nearbyChatSavingEnabled = restored.nearbyChatSavingEnabled
        let activeDraft = restored.conversations.first(where: { $0.id == restored.activeConversationID })!
        messageParts = activeDraft.messageParts
        messagePartLanguages = Self.languages(for: activeDraft, fallback: restored.settings.communicationLanguage)
        messagePartBases = Self.bases(for: activeDraft)
        messagePartItemIDs = Self.itemIDs(for: activeDraft)
        messagePartPictureOverrides = Self.pictureOverrides(for: activeDraft)
        typedMessage = activeDraft.typedMessage
        typedCursorOffset = activeDraft.typedCursorOffset
        pendingPhrasePrefix = activeDraft.pendingPhrasePrefix
        isBoardOnlyModeActive = false
        isLoadingConversation = false
        save()
        for reminder in previousReminders { RoutineReminderManager.cancel(reminder, profileID: activeProfileID) }
        for reminder in previousWeeklyReminders { WeeklyReminderManager.cancel(reminder, profileID: activeProfileID) }
        for event in previousCalendarReminders { CalendarReminderManager.cancel(event, profileID: activeProfileID) }
        Task { await restoreRoutineReminders() }
        Task { await restoreWeeklyReminders() }
        Task { await restoreCalendarReminders() }
    }

    @discardableResult
    func addBoards(fromBackup data: Data, selectedBoards: Set<String>) throws -> [String] {
        let restored = try JSONDecoder().decode(StoredData.self, from: data)
        let selected = restored.categories.filter { selectedBoards.contains($0) }
        guard !selected.isEmpty else { throw BackupError.invalidBoardSelection }

        var used = categories
        var renamed: [String: String] = [:]
        for name in selected {
            var candidate = name
            var suffix = 2
            while used.contains(where: { $0.localizedCaseInsensitiveCompare(candidate) == .orderedSame }) {
                candidate = "\(name) (imported \(suffix))"
                suffix += 1
            }
            used.append(candidate)
            renamed[name] = candidate
        }

        var additions: [CommunicationItem] = []
        var translations = wordTranslations
        for source in restored.items where selectedBoards.contains(source.category) {
            guard let category = renamed[source.category] else { continue }
            var item = source
            item.id = UUID()
            item.category = category
            item.isCustom = true
            if let destination = source.destinationBoard {
                item.destinationBoard = renamed[destination]
                    ?? (used.contains(destination) ? destination : nil)
                if item.destinationBoard == nil { item.linkBehavior = nil }
            }
            additions.append(item)
            if let translated = restored.wordTranslations[source.id.uuidString] {
                translations[item.id.uuidString] = translated
            }
        }

        var updatedSettings = settings
        for name in selected {
            guard let target = renamed[name] else { continue }
            updatedSettings.boardTileSizes[target] = restored.settings.boardTileSizes[name]
            updatedSettings.boardGridLayouts[target] = restored.settings.boardGridLayouts[name]
            updatedSettings.boardEmptySlots[target] = restored.settings.boardEmptySlots[name]
            updatedSettings.boardIcons[target] = restored.settings.boardIcons[name]
            if restored.settings.boardsWithoutTileLabels.contains(name) {
                updatedSettings.boardsWithoutTileLabels.append(target)
            }
            if let importedFolder = restored.settings.boardFolderAssignments[name],
               restored.settings.boardFolders.contains(importedFolder) {
                let folder = updatedSettings.boardFolders.first {
                    $0.localizedCaseInsensitiveCompare(importedFolder) == .orderedSame
                } ?? importedFolder
                if !updatedSettings.boardFolders.contains(folder) {
                    updatedSettings.boardFolders.append(folder)
                }
                updatedSettings.boardFolderAssignments[target] = folder
                if updatedSettings.boardFolderVoiceIdentifiers[folder] == nil {
                    updatedSettings.boardFolderVoiceIdentifiers[folder] =
                        restored.settings.boardFolderVoiceIdentifiers[importedFolder]
                }
            }
        }
        categories = used
        items.append(contentsOf: additions)
        wordTranslations = translations
        settings = updatedSettings
        return selected.compactMap { renamed[$0] }
    }

    private func save() {
        predictionContentRevision &+= 1
        draftSaveTask?.cancel()
        draftSaveTask = nil
        if saveTransactionDepth > 0 {
            saveRequested = true
            return
        }
        let data = StoredData(items: items, categories: categories, routines: routines,
                              routineHistory: routineHistory, routineTemplates: routineTemplates,
                              routineReminders: routineReminders,
                              phrases: phrases,
                              jokes: jokes,
                              history: history, usageEvents: usageEvents, notes: notes,
                              savedReadingDocuments: savedReadingDocuments,
                              learnedPrediction: learnedPrediction,
                              feelingsLog: feelingsLog,
                              stories: stories, choiceBoards: choiceBoards,
                              sceneBoards: sceneBoards, weeklyPlan: weeklyPlan, visualCalendar: visualCalendar,
                              rewardCharts: rewardCharts, rewardCollectibles: rewardCollectibles,
                               settings: settings, passport: passport,
                               wordTranslations: wordTranslations,
                               conversations: conversations, activeConversationID: activeConversationID,
                               drawingStrokes: drawingStrokes, speechTopics: speechTopics,
                               nearbyMessages: nearbyMessages,
                               nearbyChatSavingEnabled: nearbyChatSavingEnabled)
        ProfilePersistenceWriter.shared.enqueue(data, to: fileURL)
#if DEBUG
        persistenceWriteCount += 1
#endif
    }

    private func withSaveTransaction<Result>(_ action: () -> Result) -> Result {
        saveTransactionDepth += 1
        defer { finishSaveTransaction() }
        return action()
    }

    private func finishSaveTransaction() {
        guard saveTransactionDepth > 0 else { return }
        saveTransactionDepth -= 1
        if saveTransactionDepth == 0 && saveRequested {
            saveRequested = false
            save()
        }
    }

    private func updateActiveConversation(immediately: Bool) {
        guard !isPrivateConversationActive else { return }
        guard let index = conversations.firstIndex(where: { $0.id == activeConversationID }) else { return }
        let draft = conversations[index]
        let hasChanges = draft.messageParts != messageParts ||
            draft.messagePartLanguages != messagePartLanguages ||
            (draft.messagePartBases ?? []) != messagePartBases ||
            (draft.messagePartItemIDs ?? []) != messagePartItemIDs ||
            (draft.messagePartPictureOverrides ?? []) != messagePartPictureOverrides ||
            draft.typedMessage != typedMessage ||
            draft.typedCursorOffset != typedCursorOffset ||
            draft.pendingPhrasePrefix != pendingPhrasePrefix
        guard hasChanges else {
            if immediately && draftSaveTask != nil { save() }
            return
        }
        conversations[index].messageParts = messageParts
        conversations[index].messagePartLanguages = messagePartLanguages
        conversations[index].messagePartBases = messagePartBases
        conversations[index].messagePartItemIDs = messagePartItemIDs
        conversations[index].messagePartPictureOverrides = messagePartPictureOverrides
        conversations[index].typedMessage = typedMessage
        conversations[index].typedCursorOffset = typedCursorOffset
        conversations[index].pendingPhrasePrefix = pendingPhrasePrefix
        conversations[index].updatedAt = .now
        draftSaveTask?.cancel()
        draftSaveTask = nil
        if immediately {
            save()
        } else {
            draftSaveTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                self?.draftSaveTask = nil
                self?.save()
            }
        }
    }

    private static func languages(for draft: ConversationDraft, fallback: String) -> [String] {
        let valid = draft.messagePartLanguages.prefix(draft.messageParts.count).map {
            ["en", "es"].contains($0) ? $0 : fallback
        }
        return valid + Array(repeating: fallback, count: draft.messageParts.count - valid.count)
    }

    private static func bases(for draft: ConversationDraft) -> [String] {
        guard let bases = draft.messagePartBases, bases.count == draft.messageParts.count else {
            return draft.messageParts
        }
        return bases
    }

    private static func itemIDs(for draft: ConversationDraft) -> [UUID?] {
        guard let ids = draft.messagePartItemIDs, ids.count == draft.messageParts.count else {
            return Array(repeating: nil, count: draft.messageParts.count)
        }
        return ids
    }

    private static func pictureOverrides(for draft: ConversationDraft) -> [MessagePictureOverride?] {
        guard let pictures = draft.messagePartPictureOverrides,
              pictures.count == draft.messageParts.count else {
            return Array(repeating: nil, count: draft.messageParts.count)
        }
        return pictures
    }

    private func validDestination(_ destination: String?, from category: String) -> String? {
        guard let destination, destination != category,
              categories.contains(destination) else { return nil }
        return destination
    }

    private func saveProfileDirectory() throws {
        let directory = ProfileDirectory(profiles: profiles, activeProfileID: activeProfileID)
        try JSONEncoder().encode(directory).write(to: profilesURL, options: .atomic)
    }

    private static func readData(from url: URL) -> StoredData {
        ProfilePersistenceWriter.shared.flush()
        if let data = try? Data(contentsOf: url),
           let stored = try? JSONDecoder().decode(StoredData.self, from: data) {
            return stored
        }
        return starterData()
    }

    private static func starterData() -> StoredData {
        StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                   phrases: StarterVocabulary.phrases, settings: AppSettings())
    }

    private static func cleanedItems(_ items: [CommunicationItem]) -> [CommunicationItem] {
        items.map { item in
            var cleaned = item
            cleaned.label = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.message = item.message.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.imageData == nil { cleaned.arasaacPictogramID = nil }
            cleaned.phraseOptions = item.effectiveAction.allowsPhraseOptions
                ? CardPhrase.cleaned(item.phraseOptions ?? []) : nil
            cleaned.webURL = item.effectiveAction == .openWebPage
                ? ButtonWebLink.normalized(item.webURL) : nil
            if cleaned.effectiveAction == .openWebPage && cleaned.webURL == nil {
                cleaned.action = nil
            }
            if cleaned.action == .openScene && cleaned.destinationSceneID == nil {
                cleaned.action = nil
            }
            cleaned.backgroundColorHex = item.backgroundColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
            cleaned.borderColorHex = item.borderColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
            cleaned.labelFontSize = CommunicationItem.normalizedLabelFontSize(item.labelFontSize)
            cleaned.contentPadding = CommunicationItem.normalizedContentPadding(item.contentPadding)
            return cleaned
        }
    }
}

enum BackupError: LocalizedError {
    case emptyVocabulary
    case invalidBoardSelection

    var errorDescription: String? {
        switch self {
        case .emptyVocabulary: "The backup has no vocabulary buttons."
        case .invalidBoardSelection: "Choose at least one board from this backup."
        }
    }
}
