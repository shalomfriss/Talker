import Foundation

enum ScanGroup: String {
    case words
    case line
    case boards
    case message

    var title: String {
        switch self {
        case .words: "Words"
        case .line: "Buttons"
        case .boards: "Boards"
        case .message: "Message"
        }
    }
}

enum ScanAxis: Hashable {
    case row
    case column
}

enum ScanTarget: Hashable {
    case chooseBoards
    case messageControls
    case returnToWords
    case returnToLines
    case line(ScanAxis, Int)
    case quickWord(UUID, String)
    case word(UUID, String)
    case board(String)
    case back
    case previousPage
    case nextPage
    case speak
    case attention
    case conversations
    case focusWords
    case undo
    case clear

    var label: String {
        switch self {
        case .chooseBoards: "Choose board"
        case .messageControls: "Message controls"
        case .returnToWords: "Return to words"
        case .returnToLines: "Return to rows or columns"
        case .line(.row, let index): "Row \(index + 1)"
        case .line(.column, let index): "Column \(index + 1)"
        case .quickWord(_, let label): "Quick \(label)"
        case .word(_, let label): label
        case .board(let name): name
        case .back: "Previous board"
        case .previousPage: "Previous page"
        case .nextPage: "Next page"
        case .speak: "Speak message"
        case .attention: "Get attention"
        case .conversations: "Conversations"
        case .focusWords: "Focus words"
        case .undo: "Undo last word"
        case .clear: "Clear message"
        }
    }
}

struct ScanCue: Equatable {
    let text: String
    let language: String

    static func forTarget(_ target: ScanTarget, language: String) -> ScanCue {
        let spanish = language == "es"
        let text: String
        switch target {
        case .chooseBoards: text = spanish ? "Elegir tablero" : "Choose board"
        case .messageControls: text = spanish ? "Controles del mensaje" : "Message controls"
        case .returnToWords: text = spanish ? "Volver a las palabras" : "Return to words"
        case .returnToLines: text = spanish ? "Volver a filas o columnas" : "Return to rows or columns"
        case .line(.row, let index): text = spanish ? "Fila \(index + 1)" : "Row \(index + 1)"
        case .line(.column, let index): text = spanish ? "Columna \(index + 1)" : "Column \(index + 1)"
        case .quickWord(_, let label), .word(_, let label): text = label
        case .board(let name): text = name
        case .back: text = spanish ? "Tablero anterior" : "Previous board"
        case .previousPage: text = spanish ? "Página anterior" : "Previous page"
        case .nextPage: text = spanish ? "Página siguiente" : "Next page"
        case .speak: text = spanish ? "Decir mensaje" : "Speak message"
        case .attention: text = spanish ? "Llamar la atención" : "Get attention"
        case .conversations: text = spanish ? "Conversaciones" : "Conversations"
        case .focusWords: text = spanish ? "Palabras destacadas" : "Focus words"
        case .undo: text = spanish ? "Deshacer última palabra" : "Undo last word"
        case .clear: text = spanish ? "Borrar mensaje" : "Clear message"
        }
        return ScanCue(text: text, language: spanish ? "es" : "en")
    }

    static func forConfirmation(_ label: String, language: String) -> ScanCue {
        let spanish = language == "es"
        return ScanCue(text: spanish ? "Selecciona de nuevo para agregar \(label)" : "Select again to add \(label)",
                       language: spanish ? "es" : "en")
    }
}

struct BoardScanner {
    private(set) var group: ScanGroup = .words
    private(set) var index = 0
    private(set) var selectedLine = 0
    var isPaused = false

    static func columnCount(availableWidth: CGFloat, minimumTileWidth: CGFloat,
                            spacing: CGFloat = 10, horizontalPadding: CGFloat = 16) -> Int {
        let contentWidth = max(0, availableWidth - horizontalPadding * 2)
        return max(1, Int((contentWidth + spacing) / (minimumTileWidth + spacing)))
    }

    func targets(quickWords: [CommunicationItem], boardItems: [CommunicationItem],
                 emptyPositions: Set<Int> = [],
                 boards: [String], hasBack: Bool, hasMessage: Bool,
                 pattern: ScanPattern = .sequential, columns: Int = 3,
                 hasPreviousPage: Bool = false, hasNextPage: Bool = false,
                 dimmedButtonsActive: Bool = true) -> [ScanTarget] {
        let columnCount = max(1, columns)
        let axis: ScanAxis = pattern == .columnRow ? .column : .row
        let boardSlots = BoardSlotLayout.slots(for: boardItems, emptyPositions: emptyPositions)
        let availablePositions = boardSlots.enumerated().compactMap { position, item in
            item?.isBoardSelectable(dimmedButtonsActive: dimmedButtonsActive) == true ? position : nil
        }
        switch group {
        case .words:
            let controls: [ScanTarget] = [.chooseBoards, .messageControls]
                + (hasPreviousPage ? [.previousPage] : [])
                + (hasNextPage ? [.nextPage] : [])
                + quickWords.filter { $0.isBoardSelectable(dimmedButtonsActive: dimmedButtonsActive) }
                    .map { .quickWord($0.id, $0.label) }
            if pattern == .sequential {
                return controls + availablePositions.map { position in
                    let item = boardSlots[position]!
                    return .word(item.id, item.label)
                }
            }
            let lines = Set(availablePositions.map { position in
                axis == .row ? position / columnCount : position % columnCount
            }).sorted()
            return controls + lines.map { .line(axis, $0) }
        case .line:
            return [.returnToLines] + boardSlots.enumerated().compactMap { offset, item in
                let line = axis == .row ? offset / columnCount : offset % columnCount
                guard line == selectedLine, let item,
                      item.isBoardSelectable(dimmedButtonsActive: dimmedButtonsActive) else { return nil }
                return .word(item.id, item.label)
            }
        case .boards:
            return [.returnToWords]
                + (hasBack ? [.back] : [])
                + boards.map(ScanTarget.board)
                + [.board("Favorites")]
        case .message:
            return [.returnToWords, .attention, .conversations, .focusWords]
                + (hasMessage ? [.speak, .undo, .clear] : [])
        }
    }

    func highlighted(in targets: [ScanTarget]) -> ScanTarget? {
        guard !targets.isEmpty else { return nil }
        return targets[min(index, targets.count - 1)]
    }

    mutating func advance(targetCount: Int) {
        guard targetCount > 0 else { index = 0; return }
        index = (index + 1) % targetCount
    }

    mutating func enter(_ newGroup: ScanGroup) {
        group = newGroup
        index = 0
        if newGroup != .line { selectedLine = 0 }
    }

    mutating func enterLine(_ line: Int) {
        selectedLine = max(0, line)
        group = .line
        index = 0
    }

    mutating func reset() {
        group = .words
        index = 0
        selectedLine = 0
        isPaused = false
    }

    mutating func reconcile(targetCount: Int) {
        if index >= targetCount { index = 0 }
    }
}
