import Foundation

struct BoardNavigator {
    private(set) var currentBoard = "Core"
    private(set) var history: [String] = []
    private var visitDepths: [Int] = []

    init(startingBoard: String = "Core") {
        currentBoard = startingBoard
    }

    mutating func open(_ destination: String, behavior: BoardLinkBehavior,
                       availableBoards: [String]) -> Bool {
        guard destination != currentBoard, availableBoards.contains(destination) else { return false }
        history.append(currentBoard)
        currentBoard = destination
        if behavior == .visit { visitDepths.append(history.count) }
        return true
    }

    mutating func selectWord() {
        guard let depth = visitDepths.first else { return }
        guard history.indices.contains(depth - 1) else { goTo("Core"); return }
        currentBoard = history[depth - 1]
        history.removeSubrange((depth - 1)..<history.count)
        visitDepths.removeAll()
    }

    mutating func back() {
        guard let previous = history.popLast() else { return }
        currentBoard = previous
        visitDepths.removeAll { $0 > history.count }
    }

    mutating func goTo(_ board: String) {
        currentBoard = board
        history.removeAll()
        visitDepths.removeAll()
    }

    mutating func reconcile(availableBoards: [String], homeBoard: String = "Core") {
        let allBoards = availableBoards + ["Favorites"]
        if !allBoards.contains(currentBoard) || history.contains(where: { !allBoards.contains($0) }) {
            goTo(allBoards.contains(homeBoard) ? homeBoard : "Core")
        }
    }
}
