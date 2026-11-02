import Foundation

struct VisualMessagePart: Equatable {
    var text: String
    var itemID: UUID?
    var symbol: String?
    var imageData: Data?
}

enum VisualMessagePictureSelection: Equatable {
    case textOnly
    case item(UUID)
}

enum VisualMessageConversion {
    static func convert(_ text: String, items: [CommunicationItem],
                        label: (CommunicationItem) -> String,
                        message: (CommunicationItem) -> String,
                        pictureSelections: [Int: VisualMessagePictureSelection] = [:]) -> [VisualMessagePart] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        let normalized = words.map(normalize)
        let candidates = items.filter {
            $0.effectiveAction == .addToMessage && $0.boardVisibility != .hidden
        }.flatMap { item -> [(item: CommunicationItem, words: [String])] in
            let names = [label(item), message(item)]
            return Array(Set(names)).compactMap { name in
                let parts = name.split(whereSeparator: \.isWhitespace).map { normalize(String($0)) }
                return parts.isEmpty || parts.contains("") ? nil : (item, parts)
            }
        }.sorted { left, right in
            if left.words.count != right.words.count { return left.words.count > right.words.count }
            let leftScore = (left.item.imageData == nil ? 0 : 4) + (left.item.isCustom ? 2 : 0)
                + (left.item.symbol.isEmpty ? 0 : 1)
            let rightScore = (right.item.imageData == nil ? 0 : 4) + (right.item.isCustom ? 2 : 0)
                + (right.item.symbol.isEmpty ? 0 : 1)
            if leftScore != rightScore { return leftScore > rightScore }
            return left.item.id.uuidString < right.item.id.uuidString
        }

        var result: [VisualMessagePart] = []
        var index = 0
        while index < words.count {
            if let match = candidates.first(where: { candidate in
                let end = index + candidate.words.count
                return end <= words.count && normalized[index..<end].elementsEqual(candidate.words)
            }) {
                let end = index + match.words.count
                result.append(VisualMessagePart(text: words[index..<end].joined(separator: " "),
                                                itemID: match.item.id, symbol: match.item.symbol,
                                                imageData: match.item.imageData))
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
            case .item(let id):
                let selected = items.first {
                    $0.id == id && $0.effectiveAction == .addToMessage && $0.boardVisibility != .hidden
                }
                result[index].itemID = selected?.id
                result[index].symbol = selected?.symbol
                result[index].imageData = selected?.imageData
            }
        }
        return result
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
