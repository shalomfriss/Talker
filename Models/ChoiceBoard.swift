import Foundation

struct ChoiceOption: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String
    var symbol: String
    var message: String
    var imageData: Data? = nil
    var audioData: Data? = nil
    var backgroundColorHex: String? = nil
    var borderColorHex: String? = nil

    init(id: UUID = UUID(), label: String, symbol: String = "💬", message: String? = nil,
         imageData: Data? = nil, audioData: Data? = nil,
         backgroundColorHex: String? = nil, borderColorHex: String? = nil) {
        self.id = id
        self.label = label
        self.symbol = symbol
        self.message = message ?? label
        self.imageData = imageData
        self.audioData = audioData
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
    }

    init(item: CommunicationItem) {
        self.init(id: item.id, label: item.label, symbol: item.symbol, message: item.message,
                  imageData: item.imageData, audioData: item.audioData,
                  backgroundColorHex: item.backgroundColorHex, borderColorHex: item.borderColorHex)
    }

    func resolved(using items: [CommunicationItem]) -> ChoiceOption {
        guard let current = items.first(where: { $0.id == id && $0.destinationBoard == nil }) else {
            return self
        }
        var updated = ChoiceOption(item: current)
        updated.backgroundColorHex = backgroundColorHex
        updated.borderColorHex = borderColorHex
        return updated
    }

    var communicationItem: CommunicationItem {
        CommunicationItem(id: id, label: label, symbol: symbol, message: message,
                          category: "Choices", imageData: imageData, audioData: audioData,
                          backgroundColorHex: backgroundColorHex, borderColorHex: borderColorHex)
    }
}

enum ChoiceBoardLayout: String, Codable, CaseIterable {
    case grid
    case list
    case largeFirst

    var title: String {
        switch self {
        case .grid: "Grid"
        case .list: "List"
        case .largeFirst: "Large first"
        }
    }

    var explanation: String {
        switch self {
        case .grid: "Choices share equal space in a grid."
        case .list: "Each choice uses the full width of the screen."
        case .largeFirst: "The first choice is larger, with the others below. Reorder the choices to change which one is large."
        }
    }
}

struct ChoiceBoard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var options: [ChoiceOption]
    var folder: String? = nil
    var layout: ChoiceBoardLayout? = nil

    var effectiveLayout: ChoiceBoardLayout { layout ?? .grid }
}

enum ChoiceBoardTransferError: LocalizedError, Equatable {
    case tooLarge
    case unsupportedFormat
    case invalidBoard
    case editingLocked

    var errorDescription: String? {
        switch self {
        case .tooLarge: "The choice board file is too large."
        case .unsupportedFormat: "This is not a supported Open Voice choice board file."
        case .invalidBoard: "The choice board needs a title and 2 to 8 different choices."
        case .editingLocked: "Choice-board editing is locked for this profile."
        }
    }
}

struct ChoiceBoardTransfer: Codable {
    static let maxImportBytes = 64 * 1_048_576
    private static let formatName = "org.openvoice.choice-board"

    let format: String
    let version: Int
    let board: ChoiceBoard

    static func exportData(_ board: ChoiceBoard, using items: [CommunicationItem]) throws -> Data {
        let snapshot = ChoiceBoard(id: board.id, title: board.title,
                                   options: board.options.map { $0.resolved(using: items) },
                                   folder: board.folder, layout: board.layout)
        let data = try JSONEncoder().encode(Self(format: formatName, version: 1, board: snapshot))
        guard data.count <= maxImportBytes else { throw ChoiceBoardTransferError.tooLarge }
        return data
    }

    static func importBoard(_ data: Data) throws -> ChoiceBoard {
        guard data.count <= maxImportBytes else { throw ChoiceBoardTransferError.tooLarge }
        let transfer: Self
        do {
            transfer = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw ChoiceBoardTransferError.unsupportedFormat
        }
        guard transfer.format == formatName, transfer.version == 1 else {
            throw ChoiceBoardTransferError.unsupportedFormat
        }
        let title = transfer.board.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = transfer.board.options
        let names = options.map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
        guard !title.isEmpty, (2...8).contains(options.count),
              names.allSatisfy({ !$0.isEmpty }), Set(names).count == names.count,
              options.allSatisfy({ !$0.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ChoiceBoardTransferError.invalidBoard
        }
        return ChoiceBoard(title: title, options: options.map { option in
            var copy = option
            copy.id = UUID()
            copy.backgroundColorHex = option.backgroundColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
            copy.borderColorHex = option.borderColorHex.flatMap { ButtonColorValue(text: $0)?.hex }
            return copy
        }, folder: transfer.board.folder, layout: transfer.board.layout)
    }
}

struct QuickChoiceDraft {
    let question: String
    let choices: String

    var labels: [String] {
        choices.components(separatedBy: CharacterSet(charactersIn: "\n,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var isValid: Bool {
        (2...8).contains(labels.count) &&
        Set(labels.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }).count == labels.count
    }

    func board(using items: [CommunicationItem]) -> ChoiceBoard? {
        guard isValid else { return nil }
        let title = question.trimmingCharacters(in: .whitespacesAndNewlines)
        return ChoiceBoard(title: title.isEmpty ? "Make a choice" : title, options: labels.map { label in
            if let item = items.first(where: {
                $0.destinationBoard == nil && $0.label.localizedCaseInsensitiveCompare(label) == .orderedSame
            }) {
                return ChoiceOption(item: item)
            }
            return ChoiceOption(label: label)
        })
    }
}
