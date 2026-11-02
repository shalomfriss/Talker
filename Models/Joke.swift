import Foundation

struct Joke: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var setup: String
    var punchline: String
    var soundEffectData: Data? = nil
}
