import Foundation

enum SceneBoardTransferError: LocalizedError, Equatable {
    case tooLarge
    case unsupportedFormat
    case invalidScene
    case editingLocked

    var errorDescription: String? {
        switch self {
        case .tooLarge: "The scene file is too large."
        case .unsupportedFormat: "This is not a supported Open Voice scene file."
        case .invalidScene: "The scene needs a name, a photo or video, and 1 to 12 valid words."
        case .editingLocked: "Scene editing is locked for this profile."
        }
    }
}

struct SceneBoardTransfer: Codable {
    static let maxImportBytes = 64 * 1_048_576
    private static let formatName = "org.openvoice.visual-scene"

    let format: String
    let version: Int
    let board: VisualSceneBoard
    let linkedScenes: [VisualSceneBoard]?

    static func exportData(_ board: VisualSceneBoard, using items: [CommunicationItem],
                           allBoards: [VisualSceneBoard] = []) throws -> Data {
        let byID = Dictionary(uniqueKeysWithValues: allBoards.map { ($0.id, $0) })
        var collected = [board]
        var visited: Set<UUID> = [board.id]
        var index = 0
        while index < collected.count {
            for hotspot in collected[index].hotspots {
                guard let id = hotspot.destinationSceneID, let linked = byID[id],
                      visited.insert(id).inserted else { continue }
                collected.append(linked)
            }
            index += 1
        }
        let snapshots = collected.map { scene in
            var copy = scene
            copy.hotspots = scene.hotspots.map { hotspot in
                var word = hotspot
                word.option = hotspot.option.resolved(using: items)
                return word
            }
            return copy
        }
        let data = try JSONEncoder().encode(Self(format: formatName, version: 1,
                                                 board: snapshots[0],
                                                 linkedScenes: Array(snapshots.dropFirst())))
        guard data.count <= maxImportBytes else { throw SceneBoardTransferError.tooLarge }
        return data
    }

    static func importBoard(_ data: Data) throws -> VisualSceneBoard {
        try importBundle(data)[0]
    }

    static func importBundle(_ data: Data) throws -> [VisualSceneBoard] {
        guard data.count <= maxImportBytes else { throw SceneBoardTransferError.tooLarge }
        let transfer: Self
        do {
            transfer = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw SceneBoardTransferError.unsupportedFormat
        }
        guard transfer.format == formatName, transfer.version == 1 else {
            throw SceneBoardTransferError.unsupportedFormat
        }
        let sources = [transfer.board] + (transfer.linkedScenes ?? [])
        guard Set(sources.map(\.id)).count == sources.count,
              sources.allSatisfy({ scene in
                  !scene.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  !scene.imageData.isEmpty &&
                  scene.hasValidMedia &&
                  (1...12).contains(scene.hotspots.count) &&
                  Set(scene.hotspots.map(\.id)).count == scene.hotspots.count &&
                  scene.hotspots.allSatisfy({ hotspot in
                      hotspot.hasValidPosition && hotspot.hasValidMedia &&
                      hotspot.destinationSceneID != scene.id &&
                      !hotspot.option.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                      !hotspot.option.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  })
              }) else {
            throw SceneBoardTransferError.invalidScene
        }
        let ids = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, UUID()) })
        return sources.map { scene in
            var copy = scene
            copy.id = ids[scene.id]!
            copy.title = scene.title.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.hotspots = scene.hotspots.map { hotspot in
                var word = hotspot
                word.id = UUID()
                word.option.id = UUID()
                word.destinationSceneID = hotspot.destinationSceneID.flatMap { ids[$0] }
                return word
            }
            return copy
        }
    }
}
