import Foundation

struct CommunicationNote: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var topic: String
    var text: String
    var updatedAt: Date = .now
}

struct LifeNotebookPost: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var topic: String = ""
    var text: String = ""
    var photoData: Data? = nil
    var videoData: Data? = nil
    var pictograms: [LifeNotebookPictogram]? = nil
    var replies: [LifeNotebookReply]? = nil
    var createdAt: Date = .now
    var occurredAt: Date = .now
    var updatedAt: Date = .now

    var pictureWords: String { (pictograms ?? []).map(\.label).joined(separator: " ") }

    var spokenText: String {
        if !text.isEmpty { return text }
        return pictureWords.isEmpty ? title : pictureWords
    }

    var sharedText: String {
        [title, text, pictureWords].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    var sharedConversationText: String {
        let turns = (replies ?? []).map { "\($0.speaker.title): \($0.text)" }
        return [sharedText, turns.joined(separator: "\n")]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

struct LifeNotebookPictogram: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String
    var symbol: String = ""
    var imageData: Data? = nil
    var arasaacPictogramID: Int? = nil
}

enum LifeNotebookSpeaker: String, Codable, CaseIterable, Identifiable {
    case communicator
    case partner

    var title: String { self == .communicator ? "Communicator" : "Partner" }
    var id: String { rawValue }
}

struct LifeNotebookReply: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var speaker: LifeNotebookSpeaker
    var text: String
    var createdAt: Date = .now
}
