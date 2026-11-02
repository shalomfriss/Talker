import Foundation

struct CalmNeed: Identifiable, Equatable {
    let id: String
    let symbol: String
    let english: String
    let spanish: String

    func text(language: String) -> String {
        language == "es" ? spanish : english
    }

    static let all: [CalmNeed] = [
        CalmNeed(id: "quiet", symbol: "🔇", english: "I need quiet.", spanish: "Necesito silencio."),
        CalmNeed(id: "leave", symbol: "🚪", english: "I need to leave.", spanish: "Necesito salir."),
        CalmNeed(id: "touch", symbol: "✋", english: "Please don't touch me.", spanish: "Por favor, no me toques."),
        CalmNeed(id: "break", symbol: "⏸️", english: "I need a break.", spanish: "Necesito un descanso."),
        CalmNeed(id: "space", symbol: "↔️", english: "I need space.", spanish: "Necesito espacio."),
        CalmNeed(id: "overwhelmed", symbol: "🌧️", english: "I'm overwhelmed.", spanish: "Me siento abrumado."),
        CalmNeed(id: "time", symbol: "⌛", english: "Please give me time to answer.", spanish: "Por favor, dame tiempo para responder.")
    ]
}
