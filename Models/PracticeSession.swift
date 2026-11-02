import Foundation

enum PracticeTurn {
    case partner
    case communicator
}

struct PracticeSession {
    let activity: PracticeActivity
    private(set) var ideaIndex = 0
    private(set) var turn: PracticeTurn = .partner

    init(activity: PracticeActivity) {
        self.activity = activity
    }

    func prompt(language: String) -> String {
        let ideas = activity.ideas(language: language)
        let idea = ideas[ideaIndex % ideas.count]
        return turn == .partner ? idea.partner : idea.communicator
    }

    mutating func switchTurn() {
        turn = turn == .partner ? .communicator : .partner
    }

    mutating func nextIdea() {
        ideaIndex = (ideaIndex + 1) % activity.ideas(language: "en").count
    }
}
