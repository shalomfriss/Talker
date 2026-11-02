import Foundation

struct BedsideCard: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var symbol: String
    var label: String
    var message: String

    init(id: UUID = UUID(), symbol: String, label: String, message: String) {
        self.id = id
        self.symbol = symbol
        self.label = label
        self.message = message
    }

    static func starterCards(language: String) -> [BedsideCard] {
        language == "es" ? spanishStarterCards : englishStarterCards
    }

    static func cleaned(_ cards: [BedsideCard]) -> [BedsideCard] {
        var seen = Set<UUID>()
        return Array(cards.filter {
            !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.symbol.count <= 4 && $0.label.count <= 40 && $0.message.count <= 160
                && seen.insert($0.id).inserted
        }.prefix(24))
    }

    private static let englishStarterCards: [BedsideCard] = [
        BedsideCard(symbol: "🆘", label: "Help now", message: "I need help now."),
        BedsideCard(symbol: "🧑‍⚕️", label: "Call staff", message: "Please call a member of my care team."),
        BedsideCard(symbol: "🫁", label: "Breathing", message: "I am having trouble breathing."),
        BedsideCard(symbol: "🤕", label: "Pain", message: "I am in pain."),
        BedsideCard(symbol: "💧", label: "Water", message: "May I have some water?"),
        BedsideCard(symbol: "🚻", label: "Bathroom", message: "I need to use the bathroom."),
        BedsideCard(symbol: "↔️", label: "Move me", message: "Please help me change position."),
        BedsideCard(symbol: "🥵", label: "Too hot", message: "I am too hot."),
        BedsideCard(symbol: "🥶", label: "Too cold", message: "I am too cold."),
        BedsideCard(symbol: "✅", label: "Yes", message: "Yes."),
        BedsideCard(symbol: "❌", label: "No", message: "No."),
        BedsideCard(symbol: "⏳", label: "Please wait", message: "Please give me time to respond.")
    ]

    private static let spanishStarterCards: [BedsideCard] = [
        BedsideCard(symbol: "🆘", label: "Ayuda ahora", message: "Necesito ayuda ahora."),
        BedsideCard(symbol: "🧑‍⚕️", label: "Llame al personal", message: "Por favor, llame a alguien de mi equipo de atención."),
        BedsideCard(symbol: "🫁", label: "Respirar", message: "Me cuesta respirar."),
        BedsideCard(symbol: "🤕", label: "Dolor", message: "Tengo dolor."),
        BedsideCard(symbol: "💧", label: "Agua", message: "¿Puedo tomar agua?"),
        BedsideCard(symbol: "🚻", label: "Baño", message: "Necesito ir al baño."),
        BedsideCard(symbol: "↔️", label: "Moverme", message: "Por favor, ayúdeme a cambiar de posición."),
        BedsideCard(symbol: "🥵", label: "Mucho calor", message: "Tengo demasiado calor."),
        BedsideCard(symbol: "🥶", label: "Mucho frío", message: "Tengo demasiado frío."),
        BedsideCard(symbol: "✅", label: "Sí", message: "Sí."),
        BedsideCard(symbol: "❌", label: "No", message: "No."),
        BedsideCard(symbol: "⏳", label: "Espere", message: "Por favor, deme tiempo para responder.")
    ]
}
