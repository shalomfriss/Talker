import Foundation

enum LanyardCatalog {
    static func items(in board: String, from items: [CommunicationItem],
                      dimmedButtonsActive: Bool) -> [CommunicationItem] {
        items.filter { item in
            let onBoard = board == "Favorites" ? item.isFavorite : item.category == board
            guard onBoard, item.isBoardSelectable(dimmedButtonsActive: dimmedButtonsActive),
                  item.destinationBoard == nil,
                  !item.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            return item.effectiveAction == .addToMessage || item.effectiveAction == .speakImmediately
        }
    }
}
