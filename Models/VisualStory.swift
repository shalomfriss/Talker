import Foundation

enum StoryBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case plain, cream, mint, sky, sunset, photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: "Plain"
        case .cream: "Warm cream"
        case .mint: "Soft mint"
        case .sky: "Sky gradient"
        case .sunset: "Sunset gradient"
        case .photo: "My photo"
        }
    }
}

struct StoryPage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var symbol: String = "📖"
    var imageData: Data? = nil
    var additionalImageData: [Data] = []
    var backgroundStyle: StoryBackgroundStyle = .plain
    var backgroundPhotoData: Data? = nil
    var audioData: Data? = nil
    var videoData: Data? = nil
    var videoPosterData: Data? = nil
    var choices: [StoryChoice] = []

    var photos: [Data] {
        (imageData.map { [$0] } ?? []) + additionalImageData
    }

    var hasValidPhotoMedia: Bool {
        additionalImageData.count <= 3 &&
            (imageData != nil || additionalImageData.isEmpty) &&
            (videoData == nil || additionalImageData.isEmpty) &&
            photos.allSatisfy { !$0.isEmpty && $0.count <= 5 * 1_048_576 }
    }

    var hasValidBackgroundMedia: Bool {
        if backgroundStyle == .photo && backgroundPhotoData == nil { return false }
        return backgroundPhotoData.map { !$0.isEmpty && $0.count <= 5 * 1_048_576 } ?? true
    }

    var hasValidVideoMedia: Bool {
        guard let videoData else { return videoPosterData == nil }
        return !videoData.isEmpty && videoData.count <= SceneVideoProcessing.maxHotspotBytes &&
            videoPosterData.map { !$0.isEmpty && $0.count <= 2 * 1_048_576 } == true
    }

    init(id: UUID = UUID(), text: String, symbol: String = "📖", imageData: Data? = nil,
         additionalImageData: [Data] = [],
         backgroundStyle: StoryBackgroundStyle = .plain, backgroundPhotoData: Data? = nil,
         audioData: Data? = nil, videoData: Data? = nil, videoPosterData: Data? = nil,
         choices: [StoryChoice] = []) {
        self.id = id
        self.text = text
        self.symbol = symbol
        self.imageData = imageData
        self.additionalImageData = additionalImageData
        self.backgroundStyle = backgroundStyle
        self.backgroundPhotoData = backgroundPhotoData
        self.audioData = audioData
        self.videoData = videoData
        self.videoPosterData = videoPosterData
        self.choices = choices
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try values.decode(String.self, forKey: .text)
        symbol = try values.decodeIfPresent(String.self, forKey: .symbol) ?? "📖"
        imageData = try values.decodeIfPresent(Data.self, forKey: .imageData)
        additionalImageData = try values.decodeIfPresent([Data].self, forKey: .additionalImageData) ?? []
        backgroundStyle = (try? values.decode(StoryBackgroundStyle.self, forKey: .backgroundStyle)) ?? .plain
        backgroundPhotoData = try values.decodeIfPresent(Data.self, forKey: .backgroundPhotoData)
        audioData = try values.decodeIfPresent(Data.self, forKey: .audioData)
        videoData = try values.decodeIfPresent(Data.self, forKey: .videoData)
        videoPosterData = try values.decodeIfPresent(Data.self, forKey: .videoPosterData)
        choices = StoryChoice.cleaned((try? values.decode([StoryChoice].self, forKey: .choices)) ?? [])
    }
}

struct StoryChoice: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String
    var targetPageID: UUID

    static let maximumCount = 4
    static let maximumLabelLength = 60

    static func cleaned(_ choices: [StoryChoice], validTargets: Set<UUID>? = nil) -> [StoryChoice] {
        var seen = Set<UUID>()
        return Array(choices.compactMap { choice -> StoryChoice? in
            var result = choice
            result.label = choice.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.label.isEmpty, result.label.count <= maximumLabelLength,
                  validTargets?.contains(result.targetPageID) ?? true,
                  seen.insert(result.id).inserted else { return nil }
            return result
        }.prefix(maximumCount))
    }
}

struct VisualStory: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var pages: [StoryPage] = []

    var shareText: String {
        ([title] + pages.map { pageText(for: $0) }).joined(separator: "\n\n")
    }

    func pageText(for page: StoryPage) -> String {
        let destinations = pages.enumerated().reduce(into: [UUID: Int]()) { result, entry in
            if result[entry.element.id] == nil { result[entry.element.id] = entry.offset + 1 }
        }
        let choices = StoryChoice.cleaned(page.choices,
            validTargets: Set(destinations.keys).subtracting([page.id]))
        guard !choices.isEmpty else { return page.text }
        let choiceLines = choices.compactMap { choice -> String? in
            guard let number = destinations[choice.targetPageID] else { return nil }
            return "\(choice.label) → page \(number)"
        }
        return page.text + "\n\nChoices:\n" + choiceLines.joined(separator: "\n")
    }
}

struct StoryTransfer: Codable {
    static let maxImportBytes = 128 * 1_048_576
    private static let formatName = "org.openvoice.visual-story"

    let format: String
    let version: Int
    let story: VisualStory

    static func exportData(_ story: VisualStory) throws -> Data {
        guard isValid(story) else { throw StoryTransferError.invalidStory }
        let data = try JSONEncoder().encode(Self(format: formatName, version: 1, story: story))
        guard data.count <= maxImportBytes else { throw StoryTransferError.tooLarge }
        return data
    }

    static func importStory(_ data: Data) throws -> VisualStory {
        guard data.count <= maxImportBytes else { throw StoryTransferError.tooLarge }
        let transfer: Self
        do {
            transfer = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw StoryTransferError.unsupportedFormat
        }
        guard transfer.format == formatName, transfer.version == 1 else {
            throw StoryTransferError.unsupportedFormat
        }
        guard isValid(transfer.story) else { throw StoryTransferError.invalidStory }
        var copy = transfer.story
        copy.id = UUID()
        copy.title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPageIDs = Dictionary(uniqueKeysWithValues: copy.pages.map { ($0.id, UUID()) })
        copy.pages = copy.pages.map { page in
            var copiedPage = page
            copiedPage.id = newPageIDs[page.id]!
            copiedPage.choices = page.choices.map { choice in
                var copiedChoice = choice
                copiedChoice.id = UUID()
                copiedChoice.targetPageID = newPageIDs[choice.targetPageID]!
                return copiedChoice
            }
            return copiedPage
        }
        return copy
    }

    private static func isValid(_ story: VisualStory) -> Bool {
        guard !story.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              story.title.count <= 200, story.pages.count <= 500,
              Set(story.pages.map(\.id)).count == story.pages.count else { return false }
        let pageIDs = Set(story.pages.map(\.id))
        return story.pages.allSatisfy { page in
            !page.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            page.text.count <= 10_000 && page.symbol.count <= 8 &&
            page.hasValidPhotoMedia && page.hasValidBackgroundMedia &&
            (page.audioData.map { !$0.isEmpty && $0.count <= 10 * 1_048_576 } ?? true) &&
            page.hasValidVideoMedia &&
            StoryChoice.cleaned(page.choices, validTargets: pageIDs.subtracting([page.id])).count == page.choices.count
        }
    }
}

enum StoryTransferError: LocalizedError {
    case unsupportedFormat
    case invalidStory
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "Choose an Open Voice story file."
        case .invalidStory: "This story has missing or invalid pages or media."
        case .tooLarge: "This story file is too large to import or export."
        }
    }
}
