import Foundation

struct ClearedPictureMessage: Codable, Equatable {
    var parts: [String]
    var languages: [String]
    var bases: [String]
    var itemIDs: [UUID?]? = nil
}

struct ConversationDraft: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var messageParts: [String] = []
    var messagePartLanguages: [String] = []
    var messagePartBases: [String]? = nil
    var messagePartItemIDs: [UUID?]? = nil
    var clearOnNextSelection: Bool? = nil
    var clearedPictureMessage: ClearedPictureMessage? = nil
    var typedMessage: String = ""
    var typedCursorOffset: Int? = nil
    var pendingPhrasePrefix: String? = nil
    var updatedAt: Date = .now

    init(id: UUID = UUID(), name: String, messageParts: [String] = [],
         messagePartLanguages: [String] = [], messagePartBases: [String]? = nil,
         messagePartItemIDs: [UUID?]? = nil, clearOnNextSelection: Bool? = nil,
         clearedPictureMessage: ClearedPictureMessage? = nil, typedMessage: String = "",
         typedCursorOffset: Int? = nil,
         pendingPhrasePrefix: String? = nil, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.messageParts = messageParts
        self.messagePartLanguages = messagePartLanguages
        self.messagePartBases = messagePartBases
        self.messagePartItemIDs = messagePartItemIDs
        self.clearOnNextSelection = clearOnNextSelection
        self.clearedPictureMessage = clearedPictureMessage
        self.typedMessage = typedMessage
        self.typedCursorOffset = typedCursorOffset
        self.pendingPhrasePrefix = pendingPhrasePrefix
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decode(String.self, forKey: .name)
        messageParts = try values.decodeIfPresent([String].self, forKey: .messageParts) ?? []
        messagePartLanguages = try values.decodeIfPresent([String].self, forKey: .messagePartLanguages) ?? []
        messagePartBases = try values.decodeIfPresent([String].self, forKey: .messagePartBases)
        messagePartItemIDs = try values.decodeIfPresent([UUID?].self, forKey: .messagePartItemIDs)
        clearOnNextSelection = try values.decodeIfPresent(Bool.self, forKey: .clearOnNextSelection)
        clearedPictureMessage = try values.decodeIfPresent(ClearedPictureMessage.self, forKey: .clearedPictureMessage)
        typedMessage = try values.decodeIfPresent(String.self, forKey: .typedMessage) ?? ""
        typedCursorOffset = try values.decodeIfPresent(Int.self, forKey: .typedCursorOffset)
        pendingPhrasePrefix = try values.decodeIfPresent(String.self, forKey: .pendingPhrasePrefix)
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    var preview: String {
        let picture = messageParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let typed = typedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !picture.isEmpty && !typed.isEmpty { return "Pictures: \(picture) · Typed: \(typed)" }
        if !picture.isEmpty { return picture }
        if !typed.isEmpty { return typed }
        return "Empty conversation"
    }
}
