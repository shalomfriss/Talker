import Foundation

struct VisualMessagePart: Equatable {
    var text: String
    var itemID: UUID?
    var symbol: String?
    var imageData: Data?
    var arasaacPictogramID: Int? = nil
}

enum VisualMessagePictureSelection: Equatable {
    case textOnly
    case item(UUID)
    case pictogram(Data, Int)
}

enum VisualMessageConversion {
    private final class MatchNode {
        var children: [String: MatchNode] = [:]
        var item: CommunicationItem?
    }

    static func convert(_ text: String, items: [CommunicationItem],
                        label: (CommunicationItem) -> String,
                        message: (CommunicationItem) -> String,
                        pictureSelections: [Int: VisualMessagePictureSelection] = [:]) -> [VisualMessagePart] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        let normalized = words.map(normalize)
        let root = MatchNode()
        var selectableItems: [UUID: CommunicationItem] = [:]
        for item in items where item.effectiveAction == .addToMessage && item.boardVisibility != .hidden {
            if selectableItems[item.id] == nil { selectableItems[item.id] = item }
            for name in Set([label(item), message(item)]) {
                let parts = name.split(whereSeparator: \.isWhitespace).map { normalize(String($0)) }
                guard !parts.isEmpty && !parts.contains("") else { continue }
                var node = root
                for part in parts {
                    if node.children[part] == nil { node.children[part] = MatchNode() }
                    node = node.children[part]!
                }
                if let current = node.item {
                    if isPreferred(item, over: current) { node.item = item }
                } else {
                    node.item = item
                }
            }
        }

        var result: [VisualMessagePart] = []
        var index = 0
        while index < words.count {
            var node = root
            var cursor = index
            var match: (item: CommunicationItem, end: Int)?
            while cursor < words.count, let child = node.children[normalized[cursor]] {
                node = child
                cursor += 1
                if let item = node.item { match = (item, cursor) }
            }
            if let match {
                let end = match.end
                result.append(VisualMessagePart(text: words[index..<end].joined(separator: " "),
                                                itemID: match.item.id, symbol: match.item.symbol,
                                                imageData: match.item.imageData,
                                                arasaacPictogramID: match.item.arasaacPictogramID))
                index = end
            } else {
                result.append(VisualMessagePart(text: words[index], itemID: nil,
                                                symbol: nil, imageData: nil))
                index += 1
            }
        }
        for (index, selection) in pictureSelections where result.indices.contains(index) {
            switch selection {
            case .textOnly:
                result[index].itemID = nil
                result[index].symbol = nil
                result[index].imageData = nil
                result[index].arasaacPictogramID = nil
            case .item(let id):
                let selected = selectableItems[id]
                result[index].itemID = selected?.id
                result[index].symbol = selected?.symbol
                result[index].imageData = selected?.imageData
                result[index].arasaacPictogramID = selected?.arasaacPictogramID
            case .pictogram(let data, let id):
                result[index].itemID = nil
                result[index].symbol = nil
                result[index].imageData = data
                result[index].arasaacPictogramID = id
            }
        }
        return result
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func isPreferred(_ candidate: CommunicationItem, over current: CommunicationItem) -> Bool {
        func score(_ item: CommunicationItem) -> Int {
            (item.imageData == nil ? 0 : 4) + (item.isCustom ? 2 : 0) + (item.symbol.isEmpty ? 0 : 1)
        }
        let candidateScore = score(candidate)
        let currentScore = score(current)
        if candidateScore != currentScore { return candidateScore > currentScore }
        return candidate.id.uuidString < current.id.uuidString
    }
}
