import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

extension UTType {
    static let openBoard = UTType(exportedAs: "org.openvoice.open-board-format", conformingTo: .json)
    static let openBoardArchive = UTType(exportedAs: "org.openvoice.open-board-archive", conformingTo: .zip)
}

struct OpenBoardDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.openBoard, .openBoardArchive] }
    static var writableContentTypes: [UTType] { [.openBoard, .openBoardArchive] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ImportedOpenBoards {
    var categories: [String]
    var items: [CommunicationItem]
    var layouts: [String: BoardGridLayout]
    var emptyPositions: [String: [Int]]
    var skippedActions: Int
    var missingLinks: Int
    var missingMedia: Int
}

enum OpenBoardError: LocalizedError {
    case invalidFile
    case unsupportedVersion
    case invalidLayout
    case tooLarge
    case invalidArchive
    case unsafeArchivePath
    case emptyBoardSet

    var errorDescription: String? {
        switch self {
        case .invalidFile: "This is not a readable Open Board Format file."
        case .unsupportedVersion: "This Open Board Format version is not supported."
        case .invalidLayout: "A board has an invalid grid or duplicate button identifiers."
        case .tooLarge: "The board file is too large to import safely."
        case .invalidArchive: "The board archive is missing its manifest or a listed board."
        case .unsafeArchivePath: "The board archive contains an unsafe file path."
        case .emptyBoardSet: "There are no boards to export."
        }
    }
}

private struct OBFID: Codable, Hashable {
    var value: String

    init(_ value: String) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else { value = String(try container.decode(Int.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

private struct OBFLink: Codable {
    var id: OBFID?
    var name: String?
    var path: String?
}

private struct OBFButton: Codable {
    var id: OBFID
    var label: String
    var vocalization: String?
    var imageID: OBFID?
    var soundID: OBFID?
    var loadBoard: OBFLink?
    var action: String?
    var actions: [String]?
    var symbol: String?
    var favorite: Bool?
    var linkBehavior: String?
    var openVoiceAction: String?
    var arasaacPictogramID: Int? = nil
    var backgroundColor: String? = nil
    var borderColor: String? = nil
    var videoData: Data? = nil
    var videoPosterData: Data? = nil
    var webURL: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, label, vocalization, action, actions
        case imageID = "image_id"
        case soundID = "sound_id"
        case loadBoard = "load_board"
        case symbol = "ext_openvoice_symbol"
        case favorite = "ext_openvoice_favorite"
        case linkBehavior = "ext_openvoice_link_behavior"
        case openVoiceAction = "ext_openvoice_action"
        case arasaacPictogramID = "ext_openvoice_arasaac_pictogram_id"
        case backgroundColor = "background_color"
        case borderColor = "border_color"
        case videoData = "ext_openvoice_video_data"
        case videoPosterData = "ext_openvoice_video_poster_data"
        case webURL = "ext_openvoice_web_url"
    }
}

private struct OBFGrid: Codable {
    var rows: Int
    var columns: Int
    var order: [[OBFID?]]
}

private struct OBFMedia: Codable {
    var id: OBFID
    var data: String?
    var path: String?
    var contentType: String?
    var attribution: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, data, path
        case contentType = "content_type"
        case attribution = "ext_openvoice_attribution"
    }
}

private struct OBFBoard: Codable {
    var format: String
    var id: OBFID
    var name: String
    var locale: String?
    var buttons: [OBFButton]
    var grid: OBFGrid
    var images: [OBFMedia]
    var sounds: [OBFMedia]
    var pageColumns: Int?
    var pageRows: Int?

    enum CodingKeys: String, CodingKey {
        case format, id, name, locale, buttons, grid, images, sounds
        case pageColumns = "ext_openvoice_page_columns"
        case pageRows = "ext_openvoice_page_rows"
    }

    init(id: String, name: String, locale: String, buttons: [OBFButton], grid: OBFGrid,
         images: [OBFMedia] = [], sounds: [OBFMedia] = [],
         pageColumns: Int? = nil, pageRows: Int? = nil) {
        format = "open-board-0.1"
        self.id = OBFID(id)
        self.name = name
        self.locale = locale
        self.buttons = buttons
        self.grid = grid
        self.images = images
        self.sounds = sounds
        self.pageColumns = pageColumns
        self.pageRows = pageRows
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        format = try values.decode(String.self, forKey: .format)
        id = try values.decode(OBFID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        locale = try values.decodeIfPresent(String.self, forKey: .locale)
        buttons = try values.decode([OBFButton].self, forKey: .buttons)
        grid = try values.decode(OBFGrid.self, forKey: .grid)
        images = try values.decodeIfPresent([OBFMedia].self, forKey: .images) ?? []
        sounds = try values.decodeIfPresent([OBFMedia].self, forKey: .sounds) ?? []
        pageColumns = try values.decodeIfPresent(Int.self, forKey: .pageColumns)
        pageRows = try values.decodeIfPresent(Int.self, forKey: .pageRows)
    }
}

private struct OBFManifest: Codable {
    var format: String
    var root: String
    var paths: Paths

    struct Paths: Codable {
        var boards: [String: String]
        var images: [String: String]
        var sounds: [String: String]

        init(boards: [String: String], images: [String: String], sounds: [String: String]) {
            self.boards = boards
            self.images = images
            self.sounds = sounds
        }

        enum CodingKeys: String, CodingKey { case boards, images, sounds }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            boards = try values.decode([String: String].self, forKey: .boards)
            images = try values.decodeIfPresent([String: String].self, forKey: .images) ?? [:]
            sounds = try values.decodeIfPresent([String: String].self, forKey: .sounds) ?? [:]
        }
    }
}

enum OpenBoardFormat {
    static let maxImportBytes = 100_000_000
    private static let maxExpandedBytes = 200_000_000
    private static let maxMediaBytes = 10_000_000
    private static let maxBoardBytes = 80_000_000

    static func exportBoard(name: String, items: [CommunicationItem], language: String,
                            layout: BoardGridLayout? = nil,
                            emptyPositions: Set<Int> = []) throws -> Data {
        try validateMediaSizes(items)
        let boardItems = items.filter { $0.category == name }
        guard BoardSlotLayout.slots(for: boardItems, emptyPositions: emptyPositions).count <= 10_000 else {
            throw OpenBoardError.tooLarge
        }
        var resources: [String: Data] = [:]
        let board = makeBoard(id: "board-1", name: name, items: boardItems,
                              language: language, linkedBoards: [:], inlineMedia: true,
                              layout: layout, emptyPositions: emptyPositions, resources: &resources)
        let data = try encode(board)
        guard data.count <= maxBoardBytes else { throw OpenBoardError.tooLarge }
        return data
    }

    static func exportArchive(profileName: String, categories: [String], items: [CommunicationItem],
                              language: String, layouts: [String: BoardGridLayout] = [:],
                              defaultLayout: BoardGridLayout? = nil,
                              emptyPositions: [String: [Int]] = [:]) throws -> Data {
        let names = orderedBoardNames(categories: categories, items: items)
        guard !names.isEmpty else { throw OpenBoardError.emptyBoardSet }
        guard names.count <= 100, items.count <= 20_000 else { throw OpenBoardError.tooLarge }
        let boardCounts = Dictionary(grouping: items, by: \.category).mapValues(\.count)
        guard boardCounts.values.allSatisfy({ $0 <= 10_000 }) else { throw OpenBoardError.tooLarge }
        guard names.allSatisfy({ name in
            BoardSlotLayout.slots(for: items.filter { $0.category == name },
                                  emptyPositions: Set(emptyPositions[name] ?? [])).count <= 10_000
        }) else { throw OpenBoardError.tooLarge }
        try validateMediaSizes(items)
        let paths = Dictionary(uniqueKeysWithValues: names.enumerated().map {
            ("board-\($0.offset + 1)", "boards/\(String(format: "%04d", $0.offset + 1)).obf")
        })
        let links = Dictionary(uniqueKeysWithValues: names.enumerated().map {
            ($0.element, ("board-\($0.offset + 1)", paths["board-\($0.offset + 1)"]!))
        })
        var resources: [String: Data] = [:]
        var boards: [(String, OBFBoard)] = []
        let homeButtons = names.enumerated().map { index, name in
            let link = links[name]!
            return OBFButton(id: OBFID("home-\(index + 1)"), label: name, vocalization: nil,
                             imageID: nil, soundID: nil,
                             loadBoard: OBFLink(id: OBFID(link.0), name: name, path: link.1),
                             action: nil, actions: nil, symbol: nil, favorite: nil,
                             linkBehavior: nil, openVoiceAction: nil)
        }
        let home = OBFBoard(id: "home", name: "\(profileName) boards", locale: language,
                            buttons: homeButtons, grid: grid(for: homeButtons, columns: 3))
        boards.append(("boards/0000-home.obf", home))
        for (index, name) in names.enumerated() {
            let board = makeBoard(id: "board-\(index + 1)", name: name,
                                  items: items.filter { $0.category == name }, language: language,
                                  linkedBoards: links, inlineMedia: false,
                                  layout: layouts[name] ?? defaultLayout,
                                  emptyPositions: Set(emptyPositions[name] ?? []),
                                  resources: &resources)
            boards.append((paths["board-\(index + 1)"]!, board))
        }
        let imagePaths = Dictionary(uniqueKeysWithValues: resources.keys.filter { $0.hasPrefix("images/") }.map {
            (String($0.dropFirst("images/".count).split(separator: ".").first ?? ""), $0)
        })
        let soundPaths = Dictionary(uniqueKeysWithValues: resources.keys.filter { $0.hasPrefix("sounds/") }.map {
            (String($0.dropFirst("sounds/".count).split(separator: ".").first ?? ""), $0)
        })
        let manifest = OBFManifest(format: "open-board-0.1", root: "boards/0000-home.obf",
                                   paths: .init(boards: paths.merging(["home": "boards/0000-home.obf"]) { first, _ in first },
                                                images: imagePaths, sounds: soundPaths))
        let archive = try Archive(accessMode: .create)
        try add(encode(manifest), path: "manifest.json", to: archive)
        for (path, board) in boards { try add(encode(board), path: path, to: archive) }
        for path in resources.keys.sorted() { try add(resources[path]!, path: path, to: archive) }
        guard let data = archive.data, data.count <= maxImportBytes else { throw OpenBoardError.tooLarge }
        return data
    }

    static func importData(_ data: Data, fileExtension: String) throws -> ImportedOpenBoards {
        guard data.count <= maxImportBytes else { throw OpenBoardError.tooLarge }
        if fileExtension.lowercased() == "obz" || data.starts(with: [0x50, 0x4B]) {
            return try importArchive(data)
        }
        let board = try decodeBoard(data)
        return try convert([board], archive: nil, boardPaths: [:])
    }

    private static func importArchive(_ data: Data) throws -> ImportedOpenBoards {
        let archive = try Archive(data: data, accessMode: .read)
        let entries = Array(archive)
        guard entries.count <= 2_000 else { throw OpenBoardError.tooLarge }
        guard Set(entries.map(\.path)).count == entries.count else { throw OpenBoardError.invalidArchive }
        var total: UInt64 = 0
        for entry in entries {
            guard safePath(entry.path), entry.type != .symlink else { throw OpenBoardError.unsafeArchivePath }
            guard entry.uncompressedSize <= maxExpandedBytes else { throw OpenBoardError.tooLarge }
            total += entry.uncompressedSize
            guard total <= maxExpandedBytes else { throw OpenBoardError.tooLarge }
        }
        guard let manifestEntry = archive["manifest.json"] else { throw OpenBoardError.invalidArchive }
        let manifest = try JSONDecoder().decode(OBFManifest.self, from: read(manifestEntry, in: archive, limit: maxBoardBytes))
        guard manifest.format == "open-board-0.1" else { throw OpenBoardError.unsupportedVersion }
        guard manifest.paths.boards.values.contains(manifest.root),
              manifest.paths.boards.count <= 101 else { throw OpenBoardError.invalidArchive }
        var boards: [OBFBoard] = []
        var boardPaths: [String: String] = [:]
        let orderedPaths = manifest.paths.boards.values.sorted { left, right in
            if left == manifest.root { return true }
            if right == manifest.root { return false }
            return left < right
        }
        for path in orderedPaths {
            guard safePath(path), let entry = archive[path] else { throw OpenBoardError.invalidArchive }
            let board = try decodeBoard(read(entry, in: archive, limit: maxBoardBytes))
            guard manifest.paths.boards[board.id.value] == path else { throw OpenBoardError.invalidArchive }
            boards.append(board)
            boardPaths[path] = board.id.value
        }
        return try convert(boards, archive: archive, boardPaths: boardPaths)
    }

    private static func convert(_ boards: [OBFBoard], archive: Archive?,
                                boardPaths: [String: String]) throws -> ImportedOpenBoards {
        guard !boards.isEmpty else { throw OpenBoardError.emptyBoardSet }
        var names: [String] = []
        var nameByID: [String: String] = [:]
        for (index, board) in boards.enumerated() {
            let base = board.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let preferred = base.isEmpty ? "Imported board \(index + 1)" : String(base.prefix(80))
            var name = preferred
            var number = 2
            while names.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                name = "\(preferred) \(number)"
                number += 1
            }
            names.append(name)
            nameByID[board.id.value] = name
        }
        var items: [CommunicationItem] = []
        var layouts: [String: BoardGridLayout] = [:]
        var emptyPositions: [String: [Int]] = [:]
        var skippedActions = 0
        var missingLinks = 0
        var missingMedia = 0
        for (boardIndex, board) in boards.enumerated() {
            try validate(board)
            let boardName = names[boardIndex]
            let columns = board.pageColumns.flatMap { (1...BoardGridLayout.maximumColumns).contains($0) ? $0 : nil }
                ?? board.grid.columns
            let rows = board.pageRows.flatMap { (1...BoardGridLayout.maximumRows).contains($0) ? $0 : nil }
                ?? board.grid.rows
            layouts[boardName] = BoardGridLayout(columns: columns, rows: rows)
            let buttonsByID = Dictionary(uniqueKeysWithValues: board.buttons.map { ($0.id.value, $0) })
            let orderedIDs = board.grid.order.flatMap { $0.compactMap { $0?.value } }
            var seenIDs: Set<String> = []
            let allIDs = (orderedIDs + board.buttons.map(\.id.value)).filter { seenIDs.insert($0).inserted }
            let images = Dictionary(uniqueKeysWithValues: board.images.map { ($0.id.value, $0) })
            let sounds = Dictionary(uniqueKeysWithValues: board.sounds.map { ($0.id.value, $0) })
            var acceptedIDs: Set<String> = []
            for id in allIDs {
                guard let button = buttonsByID[id] else { continue }
                let action = supportedAction(for: button)
                if (button.action != nil || button.actions != nil) && action == nil {
                    skippedActions += 1
                    continue
                }
                let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty else { continue }
                var destination: String?
                if let link = button.loadBoard {
                    destination = link.id.flatMap { nameByID[$0.value] }
                        ?? link.path.flatMap { boardPaths[$0] }.flatMap { nameByID[$0] }
                    if destination == nil { missingLinks += 1; continue }
                }
                if destination != nil && action != nil { skippedActions += 1; continue }
                let image = button.imageID.flatMap { images[$0.value] }
                let sound = button.soundID.flatMap { sounds[$0.value] }
                let imageData = image.flatMap { mediaData($0, archive: archive) }
                let soundData = sound.flatMap { mediaData($0, archive: archive) }
                if image != nil && imageData == nil { missingMedia += 1 }
                if sound != nil && soundData == nil { missingMedia += 1 }
                if action == .playVideo {
                    let videoItem = CommunicationItem(label: label, symbol: "▶️", message: label,
                        category: names[boardIndex], videoData: button.videoData,
                        videoPosterData: button.videoPosterData)
                    guard videoItem.videoData != nil, videoItem.hasValidVideoMedia else {
                        missingMedia += 1
                        continue
                    }
                }
                let webURL = action == .openWebPage ? ButtonWebLink.normalized(button.webURL) : nil
                if action == .openWebPage && webURL == nil {
                    skippedActions += 1
                    continue
                }
                items.append(CommunicationItem(label: String(label.prefix(120)),
                                               symbol: button.symbol ?? (destination == nil ? "text.bubble" : "square.grid.2x2"),
                                               message: String((button.vocalization ?? label).prefix(500)),
                                               category: names[boardIndex], isFavorite: button.favorite ?? false,
                                               imageData: imageData,
                                               arasaacPictogramID: imageData == nil ? nil :
                                                   button.arasaacPictogramID.flatMap {
                                                       (1...10_000_000).contains($0) ? $0 : nil
                                                   },
                                               audioData: soundData,
                                               videoData: action == .playVideo ? button.videoData : nil,
                                               videoPosterData: action == .playVideo ? button.videoPosterData : nil,
                                               webURL: webURL,
                                               destinationBoard: destination,
                                               linkBehavior: BoardLinkBehavior(rawValue: button.linkBehavior ?? "navigate"),
                                               isCustom: true,
                                               action: action,
                                               backgroundColorHex: button.backgroundColor
                                                   .flatMap { ButtonColorValue(text: $0)?.hex },
                                               borderColorHex: button.borderColor
                                                   .flatMap { ButtonColorValue(text: $0)?.hex }))
                acceptedIDs.insert(id)
                guard items.count <= 20_000 else { throw OpenBoardError.tooLarge }
            }
            let gridIDs = board.grid.order.flatMap { $0.map { $0?.value } }
            var placedIDs: Set<String> = []
            let occupiedPositions = Set(gridIDs.enumerated().compactMap { position, id -> Int? in
                guard let id, acceptedIDs.contains(id), placedIDs.insert(id).inserted else { return nil }
                return position
            })
            let lastPosition = acceptedIDs == placedIDs
                ? occupiedPositions.max() : gridIDs.indices.last
            if let lastPosition {
                let gaps = (0...lastPosition).filter { !occupiedPositions.contains($0) }
                if !gaps.isEmpty { emptyPositions[boardName] = gaps }
            }
        }
        return ImportedOpenBoards(categories: names, items: items,
                                  layouts: layouts, emptyPositions: emptyPositions,
                                  skippedActions: skippedActions, missingLinks: missingLinks,
                                  missingMedia: missingMedia)
    }

    private static func makeBoard(id: String, name: String, items: [CommunicationItem], language: String,
                                  linkedBoards: [String: (String, String)], inlineMedia: Bool,
                                  layout: BoardGridLayout? = nil, emptyPositions: Set<Int> = [],
                                  resources: inout [String: Data]) -> OBFBoard {
        var buttons: [OBFButton] = []
        var images: [OBFMedia] = []
        var sounds: [OBFMedia] = []
        for item in items {
            let imageID = item.imageData.map { _ in OBFID("image-\(item.id.uuidString)") }
            let soundID = item.audioData.map { _ in OBFID("sound-\(item.id.uuidString)") }
            if let imageData = item.imageData, let imageID {
                let media = mediaRecord(id: imageID, data: imageData, isImage: true,
                                        inline: inlineMedia,
                                        attribution: item.arasaacPictogramID == nil ? nil :
                                            ARASAACPictogramService.attribution,
                                        resources: &resources)
                images.append(media)
            }
            if let audioData = item.audioData, let soundID {
                let media = mediaRecord(id: soundID, data: audioData, isImage: false,
                                        inline: inlineMedia, resources: &resources)
                sounds.append(media)
            }
            let link = item.destinationBoard.flatMap { target -> OBFLink? in
                guard let linked = linkedBoards[target] else { return nil }
                return OBFLink(id: OBFID(linked.0), name: target, path: linked.1)
            }
            buttons.append(OBFButton(id: OBFID(item.id.uuidString), label: item.label,
                                     vocalization: item.message == item.label ? nil : item.message,
                                     imageID: imageID, soundID: soundID, loadBoard: link,
                                     action: standardAction(for: item.effectiveAction), actions: nil,
                                     symbol: item.symbol, favorite: item.isFavorite,
                                     linkBehavior: item.linkBehavior?.rawValue,
                                     openVoiceAction: item.effectiveAction == .addToMessage
                                         || item.effectiveAction == .openScene
                                         || item.effectiveAction.requiresDestination
                                         ? nil : item.effectiveAction.rawValue,
                                     arasaacPictogramID: item.imageData == nil ? nil :
                                         item.arasaacPictogramID,
                                     backgroundColor: item.backgroundColorHex,
                                     borderColor: item.borderColorHex,
                                     videoData: item.effectiveAction == .playVideo ? item.videoData : nil,
                                     videoPosterData: item.effectiveAction == .playVideo ? item.videoPosterData : nil,
                                     webURL: item.effectiveAction == .openWebPage ? item.webURL : nil))
        }
        let slots = BoardSlotLayout.slots(for: items, emptyPositions: emptyPositions)
        let slotIDs = slots.map { $0.map { OBFID($0.id.uuidString) } }
        return OBFBoard(id: id, name: name, locale: language, buttons: buttons,
                        grid: grid(for: slotIDs, columns: layout?.columns ?? 4,
                                   minimumRows: layout?.rows ?? 1),
                        images: images, sounds: sounds,
                        pageColumns: layout?.columns, pageRows: layout?.rows)
    }

    private static func standardAction(for action: ButtonAction) -> String? {
        switch action {
        case .clearMessage: ":clear"
        case .speakMessage: ":speak"
        default: nil
        }
    }

    private static func supportedAction(for button: OBFButton) -> ButtonAction? {
        let commands = ([button.action].compactMap { $0 }) + (button.actions ?? [])
        guard commands.count <= 1 else { return nil }
        let standard: ButtonAction?
        switch commands.first {
        case nil: standard = nil
        case ":clear": standard = .clearMessage
        case ":speak": standard = .speakMessage
        default: return nil
        }
        if let raw = button.openVoiceAction, let custom = ButtonAction(rawValue: raw),
           !custom.requiresDestination, custom != .addToMessage, custom != .openScene {
            return standard == nil || standard == custom ? custom : nil
        }
        return standard
    }

    private static func mediaRecord(id: OBFID, data: Data, isImage: Bool, inline: Bool,
                                    attribution: String? = nil,
                                    resources: inout [String: Data]) -> OBFMedia {
        let type = mediaType(data, isImage: isImage)
        if inline {
            return OBFMedia(id: id, data: "data:\(type.mime);base64,\(data.base64EncodedString())",
                            path: nil, contentType: type.mime, attribution: attribution)
        }
        let path = "\(isImage ? "images" : "sounds")/\(id.value).\(type.ext)"
        resources[path] = data
        return OBFMedia(id: id, data: nil, path: path, contentType: type.mime,
                        attribution: attribution)
    }

    private static func mediaType(_ data: Data, isImage: Bool) -> (mime: String, ext: String) {
        if isImage {
            if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return ("image/png", "png") }
            if data.starts(with: [0xFF, 0xD8]) { return ("image/jpeg", "jpg") }
            return ("image/png", "png")
        }
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) { return ("audio/wav", "wav") }
        if data.starts(with: [0x49, 0x44, 0x33]) { return ("audio/mpeg", "mp3") }
        if data.starts(with: [0x63, 0x61, 0x66, 0x66]) { return ("audio/x-caf", "caf") }
        return ("audio/mp4", "m4a")
    }

    private static func mediaData(_ media: OBFMedia, archive: Archive?) -> Data? {
        if let dataURI = media.data, let comma = dataURI.firstIndex(of: ","),
           dataURI[..<comma].contains(";base64") {
            let encoded = dataURI[dataURI.index(after: comma)...]
            guard encoded.count <= maxMediaBytes * 2 else { return nil }
            return Data(base64Encoded: String(encoded)).flatMap { $0.count <= maxMediaBytes ? $0 : nil }
        }
        if let path = media.path, safePath(path), let archive, let entry = archive[path] {
            return try? read(entry, in: archive, limit: maxMediaBytes)
        }
        return nil
    }

    private static func grid(for buttons: [OBFButton], columns: Int) -> OBFGrid {
        grid(for: buttons.map { Optional($0.id) }, columns: columns)
    }

    private static func grid(for slots: [OBFID?], columns desiredColumns: Int,
                             minimumRows: Int = 1) -> OBFGrid {
        let cellCount = max(slots.count, desiredColumns * minimumRows)
        let columns = min(100, max(1, max(desiredColumns, (cellCount + 99) / 100)))
        let rows = max(1, max(minimumRows, (cellCount + columns - 1) / columns))
        var order: [[OBFID?]] = []
        for row in 0..<rows {
            order.append((0..<columns).map { column in
                let index = row * columns + column
                return index < slots.count ? slots[index] : nil
            })
        }
        return OBFGrid(rows: rows, columns: columns, order: order)
    }

    private static func orderedBoardNames(categories: [String], items: [CommunicationItem]) -> [String] {
        var result: [String] = []
        for name in categories + items.map(\.category) + items.compactMap(\.destinationBoard) {
            if !name.isEmpty && !result.contains(name) { result.append(name) }
        }
        return result
    }

    private static func validateMediaSizes(_ items: [CommunicationItem]) throws {
        guard items.allSatisfy({ ($0.imageData?.count ?? 0) <= maxMediaBytes &&
                                 ($0.audioData?.count ?? 0) <= maxMediaBytes &&
                                 $0.hasValidVideoMedia &&
                                 ($0.effectiveAction != .playVideo || $0.videoData != nil) }) else {
            throw OpenBoardError.tooLarge
        }
    }

    private static func validate(_ board: OBFBoard) throws {
        guard board.format == "open-board-0.1" else { throw OpenBoardError.unsupportedVersion }
        guard (1...100).contains(board.grid.rows), (1...100).contains(board.grid.columns),
              board.grid.order.count == board.grid.rows,
              board.grid.order.allSatisfy({ $0.count == board.grid.columns }),
              Set(board.buttons.map(\.id.value)).count == board.buttons.count,
              board.buttons.count <= 10_000 else { throw OpenBoardError.invalidLayout }
    }

    private static func decodeBoard(_ data: Data) throws -> OBFBoard {
        guard data.count <= maxBoardBytes else { throw OpenBoardError.tooLarge }
        guard let board = try? JSONDecoder().decode(OBFBoard.self, from: data) else { throw OpenBoardError.invalidFile }
        try validate(board)
        return board
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func add(_ data: Data, path: String, to archive: Archive) throws {
        guard safePath(path) else { throw OpenBoardError.unsafeArchivePath }
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count),
                             compressionMethod: .deflate) { offset, size in
            data.subdata(in: Int(offset)..<Int(offset) + size)
        }
    }

    private static func read(_ entry: Entry, in archive: Archive, limit: Int) throws -> Data {
        guard entry.type == .file, entry.uncompressedSize <= limit else { throw OpenBoardError.tooLarge }
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            guard data.count + chunk.count <= limit else { throw OpenBoardError.tooLarge }
            data.append(chunk)
        }
        return data
    }

    private static func safePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\")
            && !path.contains("//") && !path.contains(":")
            && !path.split(separator: "/").contains("..")
    }
}
