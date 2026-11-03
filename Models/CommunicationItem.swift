import Foundation

enum BoardLinkBehavior: String, Codable, CaseIterable {
    case navigate
    case visit
}

enum ButtonVisibility: String, Codable, CaseIterable {
    case shown
    case dimmed
    case hidden

    var title: String {
        switch self {
        case .shown: "Shown"
        case .dimmed: "Dimmed"
        case .hidden: "Hidden"
        }
    }
}

struct StorySwitchKey: RawRepresentable, Codable, Hashable, CaseIterable, Identifiable {
    let rawValue: String

    private init(_ rawValue: String) { self.rawValue = rawValue }

    init?(rawValue: String) {
        if Self.allCases.contains(where: { $0.rawValue == rawValue }) {
            self.rawValue = rawValue
            return
        }
        guard rawValue.hasPrefix("key-"),
              let value = UInt32(rawValue.dropFirst(4), radix: 16),
              let scalar = UnicodeScalar(value),
              !CharacterSet.controlCharacters.contains(scalar) else { return nil }
        self.rawValue = rawValue
    }

    static let space = StorySwitchKey("space")
    static let returnKey = StorySwitchKey("returnKey")
    static let rightArrow = StorySwitchKey("rightArrow")
    static let leftArrow = StorySwitchKey("leftArrow")
    static let n = StorySwitchKey("n")
    static let r = StorySwitchKey("r")
    static let allCases: [StorySwitchKey] = [.space, .returnKey, .rightArrow, .leftArrow, .n, .r]

    var id: String { rawValue }

    var title: String {
        switch rawValue {
        case Self.space.rawValue: return "Space"
        case Self.returnKey.rawValue: return "Return"
        case Self.rightArrow.rawValue: return "Right Arrow"
        case Self.leftArrow.rawValue: return "Left Arrow"
        case Self.n.rawValue: return "N"
        case Self.r.rawValue: return "R"
        default:
            guard let value = UInt32(rawValue.dropFirst(4), radix: 16),
                  let scalar = UnicodeScalar(value) else { return "Unknown key" }
            if (0xF704...0xF70F).contains(value) { return "F\(value - 0xF704 + 1)" }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return "Key U+\(String(value, radix: 16).uppercased())"
            }
            return String(scalar).uppercased()
        }
    }

    var customCharacter: Character? {
        guard rawValue.hasPrefix("key-"),
              let value = UInt32(rawValue.dropFirst(4), radix: 16),
              let scalar = UnicodeScalar(value) else { return nil }
        return Character(String(scalar))
    }

    static func captured(_ character: Character) -> StorySwitchKey? {
        let scalars = String(character).unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first,
              !CharacterSet.controlCharacters.contains(scalar),
              !CharacterSet.whitespacesAndNewlines.contains(scalar) else { return nil }
        return StorySwitchKey(rawValue: "key-\(String(scalar.value, radix: 16))")
    }

    static func alternative(to key: StorySwitchKey) -> StorySwitchKey {
        key == .space ? .returnKey : .space
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let key = StorySwitchKey(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                   debugDescription: "Invalid story switch key"))
        }
        self = key
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        try value.encode(rawValue)
    }
}

struct CommunicationItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String
    var symbol: String
    var message: String
    var category: String
    var isFavorite: Bool = false
    var imageData: Data? = nil
    var arasaacPictogramID: Int? = nil
    var audioData: Data? = nil
    var videoData: Data? = nil
    var videoPosterData: Data? = nil
    var webURL: String? = nil
    var destinationBoard: String? = nil
    var destinationSceneID: UUID? = nil
    var linkBehavior: BoardLinkBehavior? = nil
    var isCustom: Bool = false
    var phraseOptions: [CardPhrase]? = nil
    var visibility: ButtonVisibility? = nil
    var action: ButtonAction? = nil
    var backgroundColorHex: String? = nil
    var borderColorHex: String? = nil
    var grammarCategory: GrammarCategory? = nil
    var labelFontSize: Int? = nil
    var contentPadding: Int? = nil

    static func normalizedLabelFontSize(_ value: Int?) -> Int? {
        value.map { min(max($0, 12), 30) }
    }

    static func normalizedContentPadding(_ value: Int?) -> Int? {
        value.map { min(max($0, 0), 16) }
    }

    var boardVisibility: ButtonVisibility { visibility ?? .shown }

    var hasValidVideoMedia: Bool {
        guard let videoData else { return videoPosterData == nil }
        return !videoData.isEmpty && videoData.count <= SceneVideoProcessing.maxHotspotBytes &&
            videoPosterData.map { !$0.isEmpty && $0.count <= 2 * 1_048_576 } == true
    }

    var effectiveAction: ButtonAction {
        if destinationBoard != nil { return linkBehavior == .visit ? .visitBoard : .openBoard }
        if action == .openScene && destinationSceneID == nil { return .addToMessage }
        guard let action, !action.requiresDestination else { return .addToMessage }
        return action
    }

    func isBoardSelectable(dimmedButtonsActive: Bool) -> Bool {
        switch boardVisibility {
        case .shown: true
        case .dimmed: dimmedButtonsActive
        case .hidden: false
        }
    }
}

enum ButtonWebLink {
    static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.utf8.count <= 2_000 else { return nil }
        let candidate: String
        if input.contains("://") {
            candidate = input
        } else {
            guard !input.contains(":") else { return nil }
            candidate = "https://" + input
        }
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              let url = components.url else { return nil }
        return url.absoluteString
    }

    static func url(_ raw: String?) -> URL? {
        normalized(raw).flatMap(URL.init(string:))
    }
}

struct ButtonColorValue: Equatable {
    let red: Int
    let green: Int
    let blue: Int
    let alpha: Int

    init(red: Int, green: Int, blue: Int, alpha: Int = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init?(text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            let digits = String(value.dropFirst())
            guard [3, 4, 6, 8].contains(digits.count),
                  let number = UInt64(digits, radix: 16) else { return nil }
            switch digits.count {
            case 3:
                red = Int((number >> 8) & 0xF) * 17
                green = Int((number >> 4) & 0xF) * 17
                blue = Int(number & 0xF) * 17
                alpha = 255
            case 4:
                red = Int((number >> 12) & 0xF) * 17
                green = Int((number >> 8) & 0xF) * 17
                blue = Int((number >> 4) & 0xF) * 17
                alpha = Int(number & 0xF) * 17
            case 6:
                red = Int((number >> 16) & 0xFF)
                green = Int((number >> 8) & 0xFF)
                blue = Int(number & 0xFF)
                alpha = 255
            default:
                red = Int((number >> 24) & 0xFF)
                green = Int((number >> 16) & 0xFF)
                blue = Int((number >> 8) & 0xFF)
                alpha = Int(number & 0xFF)
            }
            return
        }
        let lower = value.lowercased()
        let hasAlpha = lower.hasPrefix("rgba(")
        guard (hasAlpha || lower.hasPrefix("rgb(")), lower.hasSuffix(")"),
              let open = lower.firstIndex(of: "(") else { return nil }
        let parts = lower[lower.index(after: open)..<lower.index(before: lower.endIndex)]
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == (hasAlpha ? 4 : 3),
              let r = Int(parts[0]), let g = Int(parts[1]), let b = Int(parts[2]),
              (0...255).contains(r), (0...255).contains(g), (0...255).contains(b) else { return nil }
        let opacity = hasAlpha ? Double(parts[3]) : 1
        guard let opacity, (0...1).contains(opacity) else { return nil }
        red = r
        green = g
        blue = b
        alpha = Int((opacity * 255).rounded())
    }

    var hex: String {
        if alpha == 255 { return String(format: "#%02X%02X%02X", red, green, blue) }
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }

    var prefersDarkText: Bool {
        let opacity = Double(alpha) / 255
        let channels = [red, green, blue].map { channel in
            let composited = (Double(channel) / 255) * opacity + (1 - opacity)
            return composited <= 0.04045 ? composited / 12.92
                : pow((composited + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
        return luminance > 0.179
    }
}

enum ButtonAction: String, Codable, CaseIterable, Hashable {
    case addToMessage
    case speakImmediately
    case speakCurrentTime
    case speakMessage
    case clearMessage
    case undoClearMessage
    case deleteLastEntry
    case stopSpeaking
    case playVideo
    case openWebPage
    case openKeyboard
    case typeText
    case typeSpace
    case deleteTypedCharacter
    case moveTypedCursorLeft
    case moveTypedCursorRight
    case completeTypedPrediction
    case speakTypedMessage
    case clearTypedMessage
    case openScene
    case openBoard
    case visitBoard
    case backBoard
    case homeBoard

    var requiresDestination: Bool { self == .openBoard || self == .visitBoard }
    var requiresWebURL: Bool { self == .openWebPage }
    var requiresScene: Bool { self == .openScene }
    var usesOwnMessage: Bool { self == .addToMessage || self == .speakImmediately || self == .typeText }
    var allowsRecording: Bool { self == .addToMessage || self == .speakImmediately }
    var allowsPhraseOptions: Bool { self == .addToMessage }
    var isTypingAction: Bool {
        self == .typeText || self == .typeSpace || self == .deleteTypedCharacter
            || self == .moveTypedCursorLeft || self == .moveTypedCursorRight
            || self == .completeTypedPrediction
            || self == .speakTypedMessage || self == .clearTypedMessage
    }

    var title: String {
        switch self {
        case .addToMessage: "Add to message"
        case .speakImmediately: "Speak immediately"
        case .speakCurrentTime: "Speak the current time"
        case .speakMessage: "Speak picture message"
        case .clearMessage: "Clear picture message"
        case .undoClearMessage: "Undo clear message"
        case .deleteLastEntry: "Delete last message entry"
        case .stopSpeaking: "Stop speaking"
        case .playVideo: "Play video"
        case .openWebPage: "Open a web page"
        case .openKeyboard: "Open typing keyboard"
        case .typeText: "Type this button's text"
        case .typeSpace: "Type a space"
        case .deleteTypedCharacter: "Delete last typed character"
        case .moveTypedCursorLeft: "Move typed cursor left"
        case .moveTypedCursorRight: "Move typed cursor right"
        case .completeTypedPrediction: "Complete suggested word"
        case .speakTypedMessage: "Speak typed message"
        case .clearTypedMessage: "Clear typed message"
        case .openScene: "Open a scene"
        case .openBoard: "Open a board"
        case .visitBoard: "Visit a board for one word"
        case .backBoard: "Go to previous board"
        case .homeBoard: "Go to home board"
        }
    }

    var suggestedSymbol: String {
        switch self {
        case .addToMessage: "💬"
        case .speakImmediately: "🔊"
        case .speakCurrentTime: "🕒"
        case .speakMessage: "🗣️"
        case .clearMessage: "🧹"
        case .undoClearMessage: "↩️"
        case .deleteLastEntry: "⌫"
        case .stopSpeaking: "🛑"
        case .playVideo: "▶️"
        case .openWebPage: "🌐"
        case .openKeyboard: "⌨️"
        case .typeText: "A"
        case .typeSpace: "␣"
        case .deleteTypedCharacter: "⌫"
        case .moveTypedCursorLeft: "←"
        case .moveTypedCursorRight: "→"
        case .completeTypedPrediction: "✨"
        case .speakTypedMessage: "🗣️"
        case .clearTypedMessage: "🧹"
        case .openScene: "🖼️"
        case .openBoard, .visitBoard: "📂"
        case .backBoard: "⬅️"
        case .homeBoard: "🏠"
        }
    }

    var linkBehavior: BoardLinkBehavior? {
        switch self {
        case .openBoard: .navigate
        case .visitBoard: .visit
        default: nil
        }
    }
}

enum SpokenClock {
    static func locale(for language: String) -> Locale {
        Locale(identifier: language == "es" ? "es_ES" : "en_US")
    }

    static func time(at date: Date, language: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale(for: language)
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func date(at date: Date, language: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale(for: language)
        formatter.timeZone = timeZone
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    static func message(at date: Date, language: String, timeZone: TimeZone = .current) -> String {
        let time = time(at: date, language: language, timeZone: timeZone)
        return language == "es" ? "La hora es \(time)." : "The time is \(time)."
    }
}

enum PhraseJoinBehavior: String, Codable, CaseIterable {
    case normal
    case prefix
    case suffix

    var title: String {
        switch self {
        case .normal: "Separate words"
        case .prefix: "Prefix: attach the next phrase"
        case .suffix: "Suffix: attach to the previous phrase"
        }
    }
}

enum PhraseFolderLink: Codable, Hashable {
    case quick
    case named(String)

    var title: String {
        switch self {
        case .quick: "Quick communication"
        case .named(let name): name
        }
    }
}

struct SavedPhrase: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var label: String? = nil
    var audioData: Data? = nil
    var imageData: Data? = nil
    var arasaacPictogramID: Int? = nil
    var colorHex: String? = nil
    var folder: String? = nil
    var shortcut: String? = nil
    var languageCode: String? = nil
    var tapActionOverride: PhraseTapAction? = nil
    var joinBehavior: PhraseJoinBehavior = .normal
    var folderLink: PhraseFolderLink? = nil

    var displayLabel: String {
        let clean = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? text : clean
    }

    var accessibleLabel: String {
        var phraseLabel = displayLabel == text ? text : "\(displayLabel). Full phrase: \(text)"
        if joinBehavior != .normal { phraseLabel += ". \(joinBehavior.title)" }
        if let folderLink { phraseLabel += ". Opens \(folderLink.title) folder" }
        guard let languageCode else { return phraseLabel }
        return "\(phraseLabel). Spoken in \(PhraseLanguage.title(for: languageCode))"
    }

    func effectiveTapAction(fallback: PhraseTapAction) -> PhraseTapAction {
        tapActionOverride ?? fallback
    }

    init(id: UUID = UUID(), text: String, label: String? = nil, audioData: Data? = nil,
         imageData: Data? = nil, arasaacPictogramID: Int? = nil, colorHex: String? = nil,
         folder: String? = nil, shortcut: String? = nil, languageCode: String? = nil,
         tapActionOverride: PhraseTapAction? = nil,
         joinBehavior: PhraseJoinBehavior = .normal,
         folderLink: PhraseFolderLink? = nil) {
        self.id = id
        self.text = text
        self.label = label
        self.audioData = audioData
        self.imageData = imageData
        self.arasaacPictogramID = arasaacPictogramID
        self.colorHex = colorHex
        self.folder = folder
        self.shortcut = shortcut
        self.languageCode = PhraseLanguage.normalized(languageCode)
        self.tapActionOverride = tapActionOverride
        self.joinBehavior = joinBehavior
        self.folderLink = folderLink
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try values.decode(String.self, forKey: .text)
        label = try values.decodeIfPresent(String.self, forKey: .label)
        audioData = try values.decodeIfPresent(Data.self, forKey: .audioData)
        imageData = try values.decodeIfPresent(Data.self, forKey: .imageData)
        arasaacPictogramID = try values.decodeIfPresent(Int.self, forKey: .arasaacPictogramID)
        colorHex = try values.decodeIfPresent(String.self, forKey: .colorHex)
        folder = try values.decodeIfPresent(String.self, forKey: .folder)
        shortcut = try values.decodeIfPresent(String.self, forKey: .shortcut)
        languageCode = PhraseLanguage.normalized(try values.decodeIfPresent(String.self, forKey: .languageCode))
        tapActionOverride = try values.decodeIfPresent(PhraseTapAction.self, forKey: .tapActionOverride)
        joinBehavior = try values.decodeIfPresent(PhraseJoinBehavior.self, forKey: .joinBehavior) ?? .normal
        folderLink = try values.decodeIfPresent(PhraseFolderLink.self, forKey: .folderLink)
    }
}

enum SpokenMessageSpeaker: String, Codable, Equatable {
    case communicator
    case partner

    var title: String { self == .partner ? "Partner" : "Communicator" }
}

enum SpokenMessageInputMode: String, Codable, Equatable {
    case picture
    case typed
    case savedPhrase
    case quickMessage
    case cue
    case writing
    case manualNote
    case other

    var title: String {
        switch self {
        case .picture: "Picture board"
        case .typed: "Typed"
        case .savedPhrase: "Saved phrase"
        case .quickMessage: "Quick message"
        case .cue: "Letter or topic cue"
        case .writing: "Reviewed writing"
        case .manualNote: "Manually entered"
        case .other: "Other AAC speech"
        }
    }
}

struct SpokenMessage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var date: Date = Date()
    var speaker: SpokenMessageSpeaker? = nil
    var inputMode: SpokenMessageInputMode? = nil
}

enum TileSize: Int, CaseIterable, Codable {
    case compact, standard, large

    var minimumWidth: CGFloat {
        switch self {
        case .compact: 86
        case .standard: 108
        case .large: 146
        }
    }

    var minimumTileHeight: CGFloat {
        switch self {
        case .compact: 80
        case .standard: 94
        case .large: 118
        }
    }
}

struct BoardGridLayout: Codable, Equatable {
    static let maximumColumns = 16
    static let maximumRows = 16

    var columns: Int
    var rows: Int

    init(columns: Int, rows: Int) {
        self.columns = min(Self.maximumColumns, max(1, columns))
        self.rows = min(Self.maximumRows, max(1, rows))
    }

    var pageCapacity: Int { columns * rows }

    func pageCount(for itemCount: Int) -> Int {
        let count = max(0, itemCount)
        return count == 0 ? 1 : (count - 1) / pageCapacity + 1
    }

    func range(for page: Int, itemCount: Int) -> Range<Int> {
        let count = max(0, itemCount)
        let safePage = min(max(0, page), pageCount(for: count) - 1)
        let start = min(count, safePage * pageCapacity)
        return start..<min(count, start + pageCapacity)
    }

    private enum CodingKeys: String, CodingKey { case columns, rows }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(columns: try values.decode(Int.self, forKey: .columns),
                  rows: try values.decode(Int.self, forKey: .rows))
    }
}

enum BoardSlotLayout {
    static let maximumEditablePosition = 10_000

    static func slotCount(itemCount: Int, emptyPositions: Set<Int>, minimumCount: Int = 0) -> Int {
        let empties = emptyPositions.filter { (0..<maximumEditablePosition).contains($0) }
        return max(minimumCount, itemCount + empties.count, (empties.max() ?? -1) + 1)
    }

    static func pageSlots(for items: [CommunicationItem], emptyPositions: Set<Int>,
                          layout: BoardGridLayout, page: Int) -> [CommunicationItem?] {
        let empties = Set(emptyPositions.filter { (0..<maximumEditablePosition).contains($0) })
        let count = max(items.count + empties.count, (empties.max() ?? -1) + 1)
        let range = layout.range(for: page, itemCount: count)
        var itemIndex = range.lowerBound - empties.filter { $0 < range.lowerBound }.count
        var result: [CommunicationItem?] = []
        result.reserveCapacity(layout.pageCapacity)
        for position in range {
            if empties.contains(position) || itemIndex >= items.count {
                result.append(nil)
            } else {
                result.append(items[itemIndex])
                itemIndex += 1
            }
        }
        result.append(contentsOf: repeatElement(nil, count: layout.pageCapacity - result.count))
        return result
    }

    static func slots(for items: [CommunicationItem], emptyPositions: Set<Int>,
                      minimumCount: Int = 0) -> [CommunicationItem?] {
        let empties = Set(emptyPositions.filter { (0..<maximumEditablePosition).contains($0) })
        let count = max(minimumCount, items.count + empties.count,
                        (empties.max() ?? -1) + 1)
        var result: [CommunicationItem?] = []
        result.reserveCapacity(count)
        var itemIndex = 0
        for position in 0..<count {
            if empties.contains(position) || itemIndex >= items.count {
                result.append(nil)
            } else {
                result.append(items[itemIndex])
                itemIndex += 1
            }
        }
        return result
    }
}

enum PhraseCardSlotLayout {
    static func slots(for phrases: [SavedPhrase], emptyPositions: Set<Int>,
                      minimumCount: Int = 0) -> [SavedPhrase?] {
        let empties = Set(emptyPositions.filter { (0..<BoardSlotLayout.maximumEditablePosition).contains($0) })
        let count = max(minimumCount, phrases.count + empties.count, (empties.max() ?? -1) + 1)
        var result: [SavedPhrase?] = []
        result.reserveCapacity(count)
        var phraseIndex = 0
        for position in 0..<count {
            if empties.contains(position) || phraseIndex >= phrases.count {
                result.append(nil)
            } else {
                result.append(phrases[phraseIndex])
                phraseIndex += 1
            }
        }
        return result
    }
}

enum LetterOrder: String, Codable, CaseIterable {
    case alphabetical
    case commonFirst
    case qwerty
    case custom

    var title: String {
        switch self {
        case .alphabetical: "A–Z"
        case .commonFirst: "Common first"
        case .qwerty: "QWERTY"
        case .custom: "Custom"
        }
    }

    func qwertyRows(language: String) -> [[String]] {
        ["QWERTYUIOP", language == "es" ? "ASDFGHJKLÑ" : "ASDFGHJKL", "ZXCVBNM"]
            .map { $0.map(String.init) }
    }

    func letters(language: String) -> [String] {
        let order: String
        switch (self, language) {
        case (.commonFirst, "es"):
            order = "EAOLSNDRUITCPMYQBHGFVJÑZXKW"
        case (.commonFirst, _):
            order = "ETAOINSRHLDCUMFPGWYBVKXJQZ"
        case (.qwerty, _):
            return qwertyRows(language: language).flatMap { $0 }
        case (.custom, "es"), (.alphabetical, "es"):
            order = "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"
        case (.custom, _), (.alphabetical, _):
            order = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        }
        return order.map(String.init)
    }
}

enum ScanMode: String, Codable, CaseIterable {
    case automatic
    case step
}

enum ScanPattern: String, Codable, CaseIterable {
    case sequential
    case rowColumn
    case columnRow
}

enum ScanCueMode: String, Codable, CaseIterable {
    case off
    case spoken
    case blip
    case woodblock
}

enum PhraseTapAction: String, Codable, CaseIterable, Identifiable {
    case speak
    case insertTyped

    var id: String { rawValue }
    var title: String {
        switch self {
        case .speak: "Speak"
        case .insertTyped: "Add to typed message"
        }
    }
}

enum SceneLabelMode: String, Codable, CaseIterable, Identifiable {
    case always
    case onTap

    var id: String { rawValue }
}

struct TimeOfDayWordUse: Codable, Equatable {
    static let maximumWords = 256
    let itemID: UUID
    var counts: [Int]

    init(itemID: UUID, counts: [Int] = [0, 0, 0, 0]) {
        self.itemID = itemID
        self.counts = Array((counts + [0, 0, 0, 0]).prefix(4)).map { min(100, max(0, $0)) }
    }

    static func bucket(for hour: Int) -> Int? {
        switch hour {
        case 5..<12: 0
        case 12..<17: 1
        case 17..<22: 2
        case 0..<5, 22..<24: 3
        default: nil
        }
    }

    func count(at hour: Int) -> Int {
        guard let bucket = Self.bucket(for: hour) else { return 0 }
        return counts[bucket]
    }

    static func cleaned(_ raw: [TimeOfDayWordUse]) -> [TimeOfDayWordUse] {
        var seen = Set<UUID>()
        var result: [TimeOfDayWordUse] = []
        for entry in raw.reversed() where seen.insert(entry.itemID).inserted {
            result.append(TimeOfDayWordUse(itemID: entry.itemID, counts: entry.counts))
            if result.count == maximumWords { break }
        }
        return Array(result.reversed())
    }

    static func recording(_ itemID: UUID, at hour: Int,
                          in existing: [TimeOfDayWordUse]) -> [TimeOfDayWordUse] {
        guard let bucket = Self.bucket(for: hour) else { return existing }
        var result = existing
        if result.contains(where: { $0.counts[bucket] >= 50 }) {
            for index in result.indices { result[index].counts[bucket] /= 2 }
        }
        var entry = result.firstIndex(where: { $0.itemID == itemID })
            .map { result.remove(at: $0) } ?? TimeOfDayWordUse(itemID: itemID)
        entry.counts[bucket] = min(100, entry.counts[bucket] + 1)
        result.append(entry)
        if result.count > maximumWords { result.removeFirst(result.count - maximumWords) }
        return result
    }
}

struct AppSettings: Codable {
    var speechRate: Float = 0.48
    var speechPitch: Float = 1.0
    var speechVolume: Float = 1.0
    var speechMuted: Bool = false
    var voiceIdentifier: String = ""
    var speakOnTap: Bool = false
    var phraseTapAction: PhraseTapAction = .speak
    var phraseCardGridLayouts: [String: BoardGridLayout] = [:]
    var phraseCardEmptySlots: [String: [Int]] = [:]
    var sceneLabelMode: SceneLabelMode = .always
    var autoClearAfterSpeaking: Bool = false
    var speakTypedCharacters: Bool = false
    var speakTypedWords: Bool = false
    var speakTypedSentences: Bool = false
    var largeTiles: Bool = false
    var compactTiles: Bool = false
    var boardTileSizes: [String: TileSize] = [:]
    var defaultBoardGridLayout: BoardGridLayout? = nil
    var boardGridLayouts: [String: BoardGridLayout] = [:]
    var boardEmptySlots: [String: [Int]] = [:]
    var pinnedBoards: [String] = []
    var boardFolders: [String] = []
    var boardFolderAssignments: [String: String] = [:]
    var boardFolderVoiceIdentifiers: [String: String] = [:]
    var boardIcons: [String: String] = [:]
    var hiddenBoards: [String] = []
    var boardsWithoutTileLabels: [String] = []
    var homeBoardName: String = "Core"
    var highContrast: Bool = false
    var confirmSelection: Bool = false
    var showBoardSuggestions: Bool = false
    var recentPictureWordsEnabled: Bool = false
    var recentPhrasesEnabled: Bool = false
    var recentPhraseIDs: [UUID] = []
    var highlightRecentPictureWords: Bool = false
    var recentPictureWordIDs: [UUID] = []
    var highlightWordsForTimeOfDay: Bool = false
    var timeOfDayWordUses: [TimeOfDayWordUse] = []
    var progressiveVocabularyStage: VocabularyStage = .off
    var grammarColorScheme: GrammarColorScheme = .board
    var saveHistory: Bool = false
    var recordCommunicationUse: Bool = false
    var historyPaused: Bool = false
    var learnPrediction: Bool = false
    var saveFeelingsLog: Bool = false
    var painScaleMaximum: Int = 5
    var scanEnabled: Bool = false
    var scanMode: ScanMode = .automatic
    var scanPattern: ScanPattern = .sequential
    var scanSpokenCues: Bool = false
    var scanCueMode: ScanCueMode = .off
    var scanCueVoiceIdentifier: String = ""
    var scanInterval: Double = 1.5
    var dimmedButtonOpacity: Double = 0.35
    var dimmedButtonsActive: Bool = true
    var wordHoldDuration: Double = 0
    var pointerDwellDuration: Double = 0
    var repeatFilterInterval: Double = 0
    var communicationLanguage: String = "en"
    var quickResponses: [QuickResponse] = QuickResponse.starterReplies
    var showUrgentBar: Bool = false
    var soundBoardClips: [SoundBoardClip] = []
    var letterOrder: LetterOrder = .alphabetical
    var customLetterOrders: [String: [String]] = [:]
    var wordKeyboardEnabled: Bool = false
    var wordKeyboardColumns: Int = 0
    var wordKeyboardKeys: [String: [WordKeyboardKey]] = [:]
    var bedsideCards: [String: [BedsideCard]] = [:]
    var groupedKeyboardKeys: Bool = false
    var tenKeyKeyboardEnabled: Bool = false
    var groupedPictureBoard: Bool = false
    var twoBoardsEnabled: Bool = false
    var storyOneTapReading: Bool = false
    var storyTwoSwitchReading: Bool = false
    var storyReadKey: StorySwitchKey = .returnKey
    var storyAdvanceKey: StorySwitchKey = .space
    var storySlideshowPause: Double = 1.0
    var attentionMessageEnglish: String = ""
    var attentionMessageSpanish: String = ""
    var attentionHaptics: Bool = false
    var sensoryIntensity: SensoryIntensity = .calm
    var sensoryMotionEnabled: Bool = true
    var sensoryHapticsEnabled: Bool = false
    var soundscapeVolume: Double = 0.3
    var focusWordIDs: [UUID] = []
    var pronunciationRules: [PronunciationRule] = []
    var singleButtonPhraseID: UUID? = nil
    var singleButtonLocked: Bool = false
    var choiceBoardEditingLocked: Bool = false
    var boardOnlyModeActive: Bool = false

    var attentionMessage: String {
        let custom = (communicationLanguage == "es" ? attentionMessageSpanish : attentionMessageEnglish)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        return communicationLanguage == "es"
            ? "Disculpa. Tengo algo que decir."
            : "Excuse me. I have something to say."
    }

    var speechPlaybackVolume: Float { speechMuted ? 0 : speechVolume }

    mutating func selectGroupedKeyboardKeys(_ enabled: Bool) {
        groupedKeyboardKeys = enabled
        if enabled { tenKeyKeyboardEnabled = false }
    }

    mutating func selectTenKeyKeyboard(_ enabled: Bool) {
        tenKeyKeyboardEnabled = enabled
        if enabled { groupedKeyboardKeys = false }
    }

    mutating func selectStoryReadKey(_ key: StorySwitchKey) {
        let previous = storyReadKey
        storyReadKey = key
        if storyAdvanceKey == key { storyAdvanceKey = previous }
    }

    mutating func selectStoryAdvanceKey(_ key: StorySwitchKey) {
        let previous = storyAdvanceKey
        storyAdvanceKey = key
        if storyReadKey == key { storyReadKey = previous }
    }

    func wordsForKeyboard(language: String) -> [WordKeyboardKey] {
        wordKeyboardKeys[language] ?? WordKeyboardKey.starterKeys(language: language)
    }

    mutating func setWordsForKeyboard(_ keys: [WordKeyboardKey], language: String) {
        guard language == "en" || language == "es" else { return }
        wordKeyboardKeys[language] = WordKeyboardKey.cleaned(keys)
    }

    func cardsForBedside(language: String) -> [BedsideCard] {
        bedsideCards[language] ?? BedsideCard.starterCards(language: language)
    }

    mutating func setBedsideCards(_ cards: [BedsideCard], language: String) {
        guard language == "en" || language == "es" else { return }
        bedsideCards[language] = BedsideCard.cleaned(cards)
    }

    func orderedLetters(language: String) -> [String] {
        guard letterOrder == .custom else { return letterOrder.letters(language: language) }
        return Self.cleanedLetters(customLetterOrders[language] ?? [], language: language)
    }

    mutating func setCustomLetters(_ letters: [String], language: String) {
        guard language == "en" || language == "es" else { return }
        customLetterOrders[language] = Self.cleanedLetters(letters, language: language)
        letterOrder = .custom
    }

    static func cleanedLetters(_ letters: [String], language: String) -> [String] {
        let alphabet = LetterOrder.alphabetical.letters(language: language)
        let valid = Set(alphabet)
        var seen = Set<String>()
        let chosen = letters.filter { valid.contains($0) && seen.insert($0).inserted }
        return chosen + alphabet.filter { seen.insert($0).inserted }
    }

    var tileSize: TileSize {
        get { largeTiles ? .large : (compactTiles ? .compact : .standard) }
        set {
            largeTiles = newValue == .large
            compactTiles = newValue == .compact
        }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        speechRate = try values.decodeIfPresent(Float.self, forKey: .speechRate) ?? 0.48
        speechPitch = min(2, max(0.5, try values.decodeIfPresent(Float.self, forKey: .speechPitch) ?? 1))
        speechVolume = min(1, max(0.1, try values.decodeIfPresent(Float.self, forKey: .speechVolume) ?? 1))
        speechMuted = try values.decodeIfPresent(Bool.self, forKey: .speechMuted) ?? false
        voiceIdentifier = try values.decodeIfPresent(String.self, forKey: .voiceIdentifier) ?? ""
        speakOnTap = try values.decodeIfPresent(Bool.self, forKey: .speakOnTap) ?? false
        phraseTapAction = (try? values.decode(PhraseTapAction.self, forKey: .phraseTapAction)) ?? .speak
        phraseCardGridLayouts = (try? values.decode([String: BoardGridLayout].self,
                                                  forKey: .phraseCardGridLayouts)) ?? [:]
        phraseCardEmptySlots = ((try? values.decode([String: [Int]].self,
                                             forKey: .phraseCardEmptySlots)) ?? [:])
            .mapValues { Array(Set($0.filter { (0..<BoardSlotLayout.maximumEditablePosition).contains($0) })).sorted() }
        sceneLabelMode = (try? values.decode(SceneLabelMode.self, forKey: .sceneLabelMode)) ?? .always
        autoClearAfterSpeaking = try values.decodeIfPresent(Bool.self, forKey: .autoClearAfterSpeaking) ?? false
        speakTypedCharacters = try values.decodeIfPresent(Bool.self, forKey: .speakTypedCharacters) ?? false
        speakTypedWords = try values.decodeIfPresent(Bool.self, forKey: .speakTypedWords) ?? false
        speakTypedSentences = try values.decodeIfPresent(Bool.self, forKey: .speakTypedSentences) ?? false
        largeTiles = try values.decodeIfPresent(Bool.self, forKey: .largeTiles) ?? false
        compactTiles = try values.decodeIfPresent(Bool.self, forKey: .compactTiles) ?? false
        boardTileSizes = (try? values.decode([String: TileSize].self, forKey: .boardTileSizes)) ?? [:]
        defaultBoardGridLayout = try? values.decode(BoardGridLayout.self, forKey: .defaultBoardGridLayout)
        boardGridLayouts = (try? values.decode([String: BoardGridLayout].self, forKey: .boardGridLayouts)) ?? [:]
        boardEmptySlots = ((try? values.decode([String: [Int]].self, forKey: .boardEmptySlots)) ?? [:])
            .mapValues { Array(Set($0.filter { (0..<BoardSlotLayout.maximumEditablePosition).contains($0) })).sorted() }
        var seenPinnedBoards = Set<String>()
        pinnedBoards = ((try? values.decode([String].self, forKey: .pinnedBoards)) ?? [])
            .filter { !$0.isEmpty && seenPinnedBoards.insert($0).inserted }
        var folderNames: [String: String] = [:]
        boardFolders = ((try? values.decode([String].self, forKey: .boardFolders)) ?? [])
            .compactMap { raw in
                let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                guard !name.isEmpty, name.count <= 40, folderNames[key] == nil else { return nil }
                folderNames[key] = name
                return name
            }
        boardFolderAssignments = ((try? values.decode([String: String].self,
                                                    forKey: .boardFolderAssignments)) ?? [:])
            .reduce(into: [String: String]()) { result, entry in
                let key = entry.value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                if !entry.key.isEmpty, let folder = folderNames[key] { result[entry.key] = folder }
            }
        boardFolderVoiceIdentifiers = ((try? values.decode([String: String].self,
                                                        forKey: .boardFolderVoiceIdentifiers)) ?? [:])
            .reduce(into: [String: String]()) { result, entry in
                let key = entry.key.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                let identifier = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let folder = folderNames[key], !identifier.isEmpty, identifier.count <= 256 {
                    result[folder] = identifier
                }
            }
        boardIcons = ((try? values.decode([String: String].self, forKey: .boardIcons)) ?? [:])
            .filter { !$0.key.isEmpty && !$0.value.isEmpty && $0.value.count <= 4 }
        var seenHiddenBoards = Set<String>()
        hiddenBoards = ((try? values.decode([String].self, forKey: .hiddenBoards)) ?? [])
            .filter { !$0.isEmpty && seenHiddenBoards.insert($0).inserted }
        var seenBoardsWithoutLabels = Set<String>()
        boardsWithoutTileLabels = ((try? values.decode([String].self, forKey: .boardsWithoutTileLabels)) ?? [])
            .filter { !$0.isEmpty && seenBoardsWithoutLabels.insert($0).inserted }
        homeBoardName = (try? values.decode(String.self, forKey: .homeBoardName)) ?? "Core"
        highContrast = try values.decodeIfPresent(Bool.self, forKey: .highContrast) ?? false
        confirmSelection = try values.decodeIfPresent(Bool.self, forKey: .confirmSelection) ?? false
        showBoardSuggestions = try values.decodeIfPresent(Bool.self, forKey: .showBoardSuggestions) ?? false
        recentPictureWordsEnabled = try values.decodeIfPresent(Bool.self, forKey: .recentPictureWordsEnabled) ?? false
        recentPhrasesEnabled = try values.decodeIfPresent(Bool.self, forKey: .recentPhrasesEnabled) ?? false
        let savedRecentPhraseIDs = try values.decodeIfPresent([UUID].self, forKey: .recentPhraseIDs) ?? []
        var seenRecentPhraseIDs = Set<UUID>()
        recentPhraseIDs = Array(savedRecentPhraseIDs.filter { seenRecentPhraseIDs.insert($0).inserted }.prefix(12))
        highlightRecentPictureWords = try values.decodeIfPresent(Bool.self, forKey: .highlightRecentPictureWords) ?? false
        let recentIDs = try values.decodeIfPresent([UUID].self, forKey: .recentPictureWordIDs) ?? []
        var seenRecentIDs = Set<UUID>()
        recentPictureWordIDs = Array(recentIDs.filter { seenRecentIDs.insert($0).inserted }.prefix(12))
        highlightWordsForTimeOfDay = try values.decodeIfPresent(Bool.self, forKey: .highlightWordsForTimeOfDay) ?? false
        timeOfDayWordUses = TimeOfDayWordUse.cleaned(
            (try? values.decode([TimeOfDayWordUse].self, forKey: .timeOfDayWordUses)) ?? [])
        progressiveVocabularyStage = (try? values.decode(VocabularyStage.self, forKey: .progressiveVocabularyStage)) ?? .off
        grammarColorScheme = (try? values.decode(GrammarColorScheme.self, forKey: .grammarColorScheme)) ?? .board
        saveHistory = try values.decodeIfPresent(Bool.self, forKey: .saveHistory) ?? false
        recordCommunicationUse = try values.decodeIfPresent(Bool.self, forKey: .recordCommunicationUse) ?? false
        historyPaused = try values.decodeIfPresent(Bool.self, forKey: .historyPaused) ?? false
        learnPrediction = try values.decodeIfPresent(Bool.self, forKey: .learnPrediction) ?? false
        saveFeelingsLog = try values.decodeIfPresent(Bool.self, forKey: .saveFeelingsLog) ?? false
        let savedPainScale = try values.decodeIfPresent(Int.self, forKey: .painScaleMaximum) ?? 5
        painScaleMaximum = savedPainScale == 10 ? 10 : 5
        scanEnabled = try values.decodeIfPresent(Bool.self, forKey: .scanEnabled) ?? false
        scanMode = (try? values.decode(ScanMode.self, forKey: .scanMode)) ?? .automatic
        scanPattern = (try? values.decode(ScanPattern.self, forKey: .scanPattern)) ?? .sequential
        scanSpokenCues = try values.decodeIfPresent(Bool.self, forKey: .scanSpokenCues) ?? false
        scanCueMode = (try? values.decode(ScanCueMode.self, forKey: .scanCueMode))
            ?? (scanSpokenCues ? .spoken : .off)
        scanCueVoiceIdentifier = try values.decodeIfPresent(String.self, forKey: .scanCueVoiceIdentifier) ?? ""
        scanInterval = min(3.0, max(0.7, try values.decodeIfPresent(Double.self, forKey: .scanInterval) ?? 1.5))
        dimmedButtonOpacity = min(0.8, max(0.15, try values.decodeIfPresent(Double.self, forKey: .dimmedButtonOpacity) ?? 0.35))
        dimmedButtonsActive = try values.decodeIfPresent(Bool.self, forKey: .dimmedButtonsActive) ?? true
        wordHoldDuration = min(1.5, max(0, try values.decodeIfPresent(Double.self, forKey: .wordHoldDuration) ?? 0))
        pointerDwellDuration = min(3.0, max(0, try values.decodeIfPresent(Double.self, forKey: .pointerDwellDuration) ?? 0))
        repeatFilterInterval = min(2.0, max(0, try values.decodeIfPresent(Double.self, forKey: .repeatFilterInterval) ?? 0))
        let language = try values.decodeIfPresent(String.self, forKey: .communicationLanguage) ?? "en"
        communicationLanguage = ["en", "es"].contains(language) ? language : "en"
        quickResponses = QuickResponse.cleaned(
            try values.decodeIfPresent([QuickResponse].self, forKey: .quickResponses)
                ?? QuickResponse.starterReplies)
        showUrgentBar = try values.decodeIfPresent(Bool.self, forKey: .showUrgentBar) ?? false
        soundBoardClips = SoundBoardClip.cleaned(
            (try? values.decode([SoundBoardClip].self, forKey: .soundBoardClips)) ?? [])
        letterOrder = (try? values.decode(LetterOrder.self, forKey: .letterOrder)) ?? .alphabetical
        let savedOrders = (try? values.decode([String: [String]].self, forKey: .customLetterOrders)) ?? [:]
        customLetterOrders = savedOrders.reduce(into: [String: [String]]()) { result, entry in
            guard entry.key == "en" || entry.key == "es" else { return }
            result[entry.key] = Self.cleanedLetters(entry.value, language: entry.key)
        }
        wordKeyboardEnabled = try values.decodeIfPresent(Bool.self, forKey: .wordKeyboardEnabled) ?? false
        wordKeyboardColumns = min(4, max(0, try values.decodeIfPresent(Int.self, forKey: .wordKeyboardColumns) ?? 0))
        let savedWordKeys = (try? values.decode([String: [WordKeyboardKey]].self, forKey: .wordKeyboardKeys)) ?? [:]
        wordKeyboardKeys = savedWordKeys.reduce(into: [String: [WordKeyboardKey]]()) { result, entry in
            guard entry.key == "en" || entry.key == "es" else { return }
            result[entry.key] = WordKeyboardKey.cleaned(entry.value)
        }
        let savedBedsideCards = (try? values.decode([String: [BedsideCard]].self, forKey: .bedsideCards)) ?? [:]
        bedsideCards = savedBedsideCards.reduce(into: [String: [BedsideCard]]()) { result, entry in
            guard entry.key == "en" || entry.key == "es" else { return }
            result[entry.key] = BedsideCard.cleaned(entry.value)
        }
        groupedKeyboardKeys = try values.decodeIfPresent(Bool.self, forKey: .groupedKeyboardKeys) ?? false
        tenKeyKeyboardEnabled = try values.decodeIfPresent(Bool.self, forKey: .tenKeyKeyboardEnabled) ?? false
        if tenKeyKeyboardEnabled { groupedKeyboardKeys = false }
        groupedPictureBoard = try values.decodeIfPresent(Bool.self, forKey: .groupedPictureBoard) ?? false
        twoBoardsEnabled = try values.decodeIfPresent(Bool.self, forKey: .twoBoardsEnabled) ?? false
        storyOneTapReading = try values.decodeIfPresent(Bool.self, forKey: .storyOneTapReading) ?? false
        storyTwoSwitchReading = try values.decodeIfPresent(Bool.self, forKey: .storyTwoSwitchReading) ?? false
        if storyTwoSwitchReading { storyOneTapReading = false }
        storyReadKey = (try? values.decode(StorySwitchKey.self, forKey: .storyReadKey)) ?? .returnKey
        storyAdvanceKey = (try? values.decode(StorySwitchKey.self, forKey: .storyAdvanceKey)) ?? .space
        if storyReadKey == storyAdvanceKey {
            storyAdvanceKey = StorySwitchKey.alternative(to: storyReadKey)
        }
        let slideshowPause = try values.decodeIfPresent(Double.self, forKey: .storySlideshowPause) ?? 1.0
        storySlideshowPause = slideshowPause.isFinite ? min(5, max(0, slideshowPause)) : 1.0
        attentionMessageEnglish = try values.decodeIfPresent(String.self, forKey: .attentionMessageEnglish) ?? ""
        attentionMessageSpanish = try values.decodeIfPresent(String.self, forKey: .attentionMessageSpanish) ?? ""
        attentionHaptics = try values.decodeIfPresent(Bool.self, forKey: .attentionHaptics) ?? false
        sensoryIntensity = (try? values.decode(SensoryIntensity.self, forKey: .sensoryIntensity)) ?? .calm
        sensoryMotionEnabled = try values.decodeIfPresent(Bool.self, forKey: .sensoryMotionEnabled) ?? true
        sensoryHapticsEnabled = try values.decodeIfPresent(Bool.self, forKey: .sensoryHapticsEnabled) ?? false
        soundscapeVolume = min(0.5, max(0, try values.decodeIfPresent(Double.self, forKey: .soundscapeVolume) ?? 0.3))
        focusWordIDs = try values.decodeIfPresent([UUID].self, forKey: .focusWordIDs) ?? []
        pronunciationRules = try values.decodeIfPresent([PronunciationRule].self, forKey: .pronunciationRules) ?? []
        singleButtonPhraseID = try values.decodeIfPresent(UUID.self, forKey: .singleButtonPhraseID)
        singleButtonLocked = try values.decodeIfPresent(Bool.self, forKey: .singleButtonLocked) ?? false
        choiceBoardEditingLocked = try values.decodeIfPresent(Bool.self, forKey: .choiceBoardEditingLocked) ?? false
        boardOnlyModeActive = try values.decodeIfPresent(Bool.self, forKey: .boardOnlyModeActive) ?? false
    }
}

struct PersonalPicture: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String
    var imageData: Data
}

struct CommunicationUsageEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case pictureButton
        case savedPhrase
        case picturePhrase

        var title: String {
            switch self {
            case .pictureButton: "Picture button"
            case .savedPhrase: "Saved phrase"
            case .picturePhrase: "Picture phrase"
            }
        }
    }

    static let maximumCount = 1_000

    var id: UUID = UUID()
    var date: Date = .now
    var kind: Kind
    var label: String
    var board: String?
    var itemID: UUID?

    init(kind: Kind, label: String, board: String? = nil, itemID: UUID? = nil) {
        self.kind = kind
        self.label = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        self.board = board.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)) }
        self.itemID = itemID
    }

    static func cleaned(_ events: [Self]) -> [Self] {
        var result: [Self] = []
        result.reserveCapacity(min(events.count, maximumCount))
        var seenIDs = Set<UUID>()
        for source in events {
            var event = source
            event.label = String(source.label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            guard !event.label.isEmpty else { continue }
            event.board = source.board.map {
                String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            }
            if !seenIDs.insert(event.id).inserted {
                repeat { event.id = UUID() } while !seenIDs.insert(event.id).inserted
            }
            result.append(event)
            if result.count == maximumCount { break }
        }
        return result
    }

    static func csv(_ events: [Self]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        func field(_ value: String) -> String {
            let clean = value.replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let safe = clean.first.map { "=+-@\t".contains($0) } == true ? "'" + clean : clean
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let rows = events.map { event in
            [field(formatter.string(from: event.date)), field(event.kind.title),
             field(event.label), field(event.board ?? "")].joined(separator: ",")
        }
        return (["Timestamp (UTC),Kind,Label,Board"] + rows).joined(separator: "\r\n") + "\r\n"
    }
}

struct StoredData: Codable {
    var items: [CommunicationItem]
    var categories: [String]
    var routines: [RoutineStep]
    var routineHistory: [RoutineRun]
    var routineTemplates: [RoutineTemplate]
    var routineReminders: [RoutineReminder]
    var phrases: [SavedPhrase]
    var jokes: [Joke]
    var history: [SpokenMessage]
    var usageEvents: [CommunicationUsageEvent]
    var notes: [CommunicationNote]
    var lifeNotebookPosts: [LifeNotebookPost]
    var savedReadingDocuments: [SavedReadingDocument]
    var learnedPrediction: LearnedPredictionModel
    var feelingsLog: [FeelingLogEntry]
    var stories: [VisualStory]
    var choiceBoards: [ChoiceBoard]
    var sceneBoards: [VisualSceneBoard]
    var weeklyPlan: WeeklyPlan
    var visualCalendar: VisualCalendar
    var rewardCharts: [RewardChart]
    var rewardCollectibles: [RewardCollectible]
    var settings: AppSettings
    var passport: CommunicationPassport
    var wordTranslations: [String: [String: WordTranslation]]
    var conversations: [ConversationDraft]
    var activeConversationID: UUID
    var drawingStrokes: [DrawingStroke]
    var speechTopics: [SpeechTopic]
    var nearbyMessages: [NearbyChatMessage]
    var nearbyChatSavingEnabled: Bool
    var pictureLibrary: [PersonalPicture]

    init(items: [CommunicationItem], categories: [String]? = nil,
         routines: [RoutineStep], routineHistory: [RoutineRun] = [],
         routineTemplates: [RoutineTemplate] = [],
         routineReminders: [RoutineReminder] = [],
         phrases: [SavedPhrase], jokes: [Joke] = [],
         history: [SpokenMessage] = [], usageEvents: [CommunicationUsageEvent] = [],
         notes: [CommunicationNote] = [], lifeNotebookPosts: [LifeNotebookPost] = [],
         savedReadingDocuments: [SavedReadingDocument] = [],
         learnedPrediction: LearnedPredictionModel = .init(),
         feelingsLog: [FeelingLogEntry] = [],
         stories: [VisualStory] = [],
         choiceBoards: [ChoiceBoard]? = nil, sceneBoards: [VisualSceneBoard] = [],
         weeklyPlan: WeeklyPlan = .init(),
         visualCalendar: VisualCalendar = .init(),
         rewardCharts: [RewardChart] = [], rewardCollectibles: [RewardCollectible] = [],
         settings: AppSettings,
         passport: CommunicationPassport = .init(),
         wordTranslations: [String: [String: WordTranslation]]? = nil,
         conversations: [ConversationDraft]? = nil, activeConversationID: UUID? = nil,
         drawingStrokes: [DrawingStroke] = [], speechTopics: [SpeechTopic] = SpeechTopic.starter,
         nearbyMessages: [NearbyChatMessage] = [], nearbyChatSavingEnabled: Bool = false,
         pictureLibrary: [PersonalPicture] = []) {
        self.items = items
        self.categories = Self.mergedCategories(categories, items: items)
        self.routines = routines
        self.routineHistory = routineHistory
        self.routineTemplates = routineTemplates
        self.routineReminders = routineReminders
        self.phrases = phrases
        self.jokes = jokes
        self.history = history
        self.usageEvents = CommunicationUsageEvent.cleaned(usageEvents)
        self.notes = notes
        self.lifeNotebookPosts = lifeNotebookPosts
        self.savedReadingDocuments = SavedReadingDocument.cleaned(savedReadingDocuments)
        self.learnedPrediction = learnedPrediction
        self.feelingsLog = feelingsLog
        self.stories = stories
        self.choiceBoards = choiceBoards ?? StarterVocabulary.choiceBoards
        self.sceneBoards = sceneBoards
        self.weeklyPlan = weeklyPlan
        self.visualCalendar = visualCalendar
        self.rewardCharts = rewardCharts
        self.rewardCollectibles = rewardCollectibles
        self.settings = settings
        self.settings.homeBoardName = HomeBoard.resolved(settings.homeBoardName,
            categories: self.categories, hiddenBoards: settings.hiddenBoards)
        self.passport = passport
        self.wordTranslations = wordTranslations ?? StarterTranslations.forItems(items)
        let suppliedDrafts = conversations ?? []
        let drafts = suppliedDrafts.isEmpty ? [ConversationDraft(name: "Conversation 1")] : suppliedDrafts
        self.conversations = drafts
        self.activeConversationID = activeConversationID.flatMap { id in
            drafts.contains(where: { $0.id == id }) ? id : nil
        } ?? drafts[0].id
        self.drawingStrokes = drawingStrokes
        self.speechTopics = speechTopics
        self.nearbyMessages = nearbyMessages
        self.nearbyChatSavingEnabled = nearbyChatSavingEnabled
        self.pictureLibrary = pictureLibrary
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        items = try values.decode([CommunicationItem].self, forKey: .items)
        categories = Self.mergedCategories(try values.decodeIfPresent([String].self, forKey: .categories), items: items)
        routines = try values.decode([RoutineStep].self, forKey: .routines)
        routineHistory = try values.decodeIfPresent([RoutineRun].self, forKey: .routineHistory) ?? []
        routineTemplates = try values.decodeIfPresent([RoutineTemplate].self, forKey: .routineTemplates) ?? []
        routineReminders = try values.decodeIfPresent([RoutineReminder].self, forKey: .routineReminders) ?? []
        phrases = try values.decode([SavedPhrase].self, forKey: .phrases)
        jokes = try values.decodeIfPresent([Joke].self, forKey: .jokes) ?? []
        history = try values.decodeIfPresent([SpokenMessage].self, forKey: .history) ?? []
        usageEvents = CommunicationUsageEvent.cleaned(
            try values.decodeIfPresent([CommunicationUsageEvent].self, forKey: .usageEvents) ?? [])
        notes = try values.decodeIfPresent([CommunicationNote].self, forKey: .notes) ?? []
        lifeNotebookPosts = try values.decodeIfPresent([LifeNotebookPost].self,
                                                      forKey: .lifeNotebookPosts) ?? []
        savedReadingDocuments = SavedReadingDocument.cleaned(
            try values.decodeIfPresent([SavedReadingDocument].self, forKey: .savedReadingDocuments) ?? [])
        learnedPrediction = try values.decodeIfPresent(LearnedPredictionModel.self, forKey: .learnedPrediction) ?? .init()
        feelingsLog = try values.decodeIfPresent([FeelingLogEntry].self, forKey: .feelingsLog) ?? []
        stories = try values.decodeIfPresent([VisualStory].self, forKey: .stories) ?? []
        choiceBoards = try values.decodeIfPresent([ChoiceBoard].self, forKey: .choiceBoards)
            ?? StarterVocabulary.choiceBoards
        sceneBoards = try values.decodeIfPresent([VisualSceneBoard].self, forKey: .sceneBoards) ?? []
        weeklyPlan = try values.decodeIfPresent(WeeklyPlan.self, forKey: .weeklyPlan) ?? .init()
        visualCalendar = try values.decodeIfPresent(VisualCalendar.self, forKey: .visualCalendar) ?? .init()
        rewardCharts = (try values.decodeIfPresent([RewardChart].self, forKey: .rewardCharts) ?? [])
            .filter(\.isValid)
        rewardCollectibles = try values.decodeIfPresent([RewardCollectible].self,
                                                       forKey: .rewardCollectibles) ?? []
        settings = try values.decode(AppSettings.self, forKey: .settings)
        settings.homeBoardName = HomeBoard.resolved(settings.homeBoardName,
            categories: categories, hiddenBoards: settings.hiddenBoards)
        passport = try values.decodeIfPresent(CommunicationPassport.self, forKey: .passport) ?? .init()
        wordTranslations = try values.decodeIfPresent([String: [String: WordTranslation]].self, forKey: .wordTranslations)
            ?? StarterTranslations.forItems(items)
        let drafts = try values.decodeIfPresent([ConversationDraft].self, forKey: .conversations) ?? []
        let resolvedDrafts = drafts.isEmpty ? [ConversationDraft(name: "Conversation 1")] : drafts
        conversations = resolvedDrafts
        let selectedID = try values.decodeIfPresent(UUID.self, forKey: .activeConversationID)
        activeConversationID = selectedID.flatMap { id in
            resolvedDrafts.contains(where: { $0.id == id }) ? id : nil
        } ?? resolvedDrafts[0].id
        drawingStrokes = try values.decodeIfPresent([DrawingStroke].self, forKey: .drawingStrokes) ?? []
        speechTopics = try values.decodeIfPresent([SpeechTopic].self, forKey: .speechTopics) ?? SpeechTopic.starter
        nearbyMessages = try values.decodeIfPresent([NearbyChatMessage].self, forKey: .nearbyMessages) ?? []
        nearbyChatSavingEnabled = try values.decodeIfPresent(Bool.self, forKey: .nearbyChatSavingEnabled) ?? false
        pictureLibrary = try values.decodeIfPresent([PersonalPicture].self, forKey: .pictureLibrary) ?? []
    }

    private static func mergedCategories(_ stored: [String]?, items: [CommunicationItem]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        let starterNames = Dictionary(uniqueKeysWithValues: StarterVocabulary.categories.map {
            ($0.folding(options: .caseInsensitive, locale: .current), $0)
        })
        let favoritesKey = "Favorites".folding(options: .caseInsensitive, locale: .current)
        func append(_ raw: String) {
            let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = clean.folding(options: .caseInsensitive, locale: .current)
            let name = starterNames[key] ?? clean
            guard !name.isEmpty, key != favoritesKey, seen.insert(key).inserted else { return }
            result.append(name)
        }
        for name in stored ?? StarterVocabulary.categories { append(name) }
        for name in StarterVocabulary.categories { append(name) }
        for item in items { append(item.category) }
        for item in items { if let destination = item.destinationBoard { append(destination) } }
        return result
    }
}
