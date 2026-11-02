import Foundation

struct SpeechTopic: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String

    static let starter: [SpeechTopic] = [
        "People", "Food and drink", "Places", "Health", "Plans", "Feelings"
    ].map { SpeechTopic(text: $0) }
}

struct PartnerSpellingSession: Equatable {
    enum Phase: Equatable {
        case row
        case letter
    }

    let language: String
    let rows: [[String]]
    private(set) var phase: Phase = .row
    private(set) var rowIndex = 0
    private(set) var letterIndex = 0
    private(set) var message = ""

    var scanRows: [[String]] {
        rows + [
            ["0", "1", "2", "3", "4"],
            ["5", "6", "7", "8", "9"],
            language == "es" ? ["Espacio", "Borrar", "Espera", "Adivina"] :
                ["Space", "Delete", "Wait", "Please guess"]
        ]
    }

    var isCommandRow: Bool { rowIndex == scanRows.count - 1 }

    init(language: String) {
        let selectedLanguage = language == "es" ? "es" : "en"
        self.language = selectedLanguage
        rows = [
            ["A", "B", "C", "D"],
            ["E", "F", "G", "H"],
            selectedLanguage == "es" ? ["I", "J", "K", "L", "M", "N", "Ñ"] :
                ["I", "J", "K", "L", "M", "N"],
            ["O", "P", "Q", "R", "S", "T"],
            ["U", "V", "W", "X", "Y", "Z"]
        ]
    }

    var currentRow: [String] { scanRows[rowIndex] }
    var currentLetter: String { currentRow[letterIndex] }
    var prompt: String {
        switch phase {
        case .row:
            if rowIndex < rows.count {
                return language == "es" ?
                    "¿Tu letra está en \(currentRow.joined(separator: ", "))?" :
                    "Is your letter in \(currentRow.joined(separator: ", "))?"
            }
            if isCommandRow {
                return language == "es" ? "¿Necesitas una acción?" : "Do you need an action?"
            }
            return language == "es" ?
                "¿Tu número está entre \(currentRow.first!) y \(currentRow.last!)?" :
                "Is your number between \(currentRow.first!) and \(currentRow.last!)?"
        case .letter:
            return language == "es" ? "¿Es \(currentLetter)?" : "Is it \(currentLetter)?"
        }
    }

    mutating func next() {
        switch phase {
        case .row: rowIndex = (rowIndex + 1) % scanRows.count
        case .letter: letterIndex = (letterIndex + 1) % currentRow.count
        }
    }

    @discardableResult
    mutating func choose() -> String? {
        switch phase {
        case .row:
            phase = .letter
            letterIndex = 0
            return nil
        case .letter:
            let selectedRow = rowIndex
            let selectedIndex = letterIndex
            let selectedChoice = currentLetter
            backToRows()
            if selectedRow < rows.count + 2 {
                message += selectedChoice
                return nil
            }
            switch selectedIndex {
            case 0:
                addSpace()
                return nil
            case 1:
                deleteLast()
                return nil
            case 2:
                return language == "es" ? "Espera, por favor." : "Please wait."
            default:
                return language == "es" ? "Por favor, adivina." : "Please guess."
            }
        }
    }

    mutating func backToRows() {
        phase = .row
        rowIndex = 0
        letterIndex = 0
    }

    mutating func addSpace() {
        guard !message.isEmpty, message.last != " " else { return }
        message += " "
        backToRows()
    }

    mutating func deleteLast() {
        if !message.isEmpty { message.removeLast() }
    }

    mutating func startAgain() {
        message = ""
        backToRows()
    }
}
