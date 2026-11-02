import Foundation

enum PracticeActivity: String, CaseIterable, Identifiable {
    case talkAboutInterests
    case shareNews
    case makeAPlan
    case playTogether

    struct Idea {
        let partner: String
        let communicator: String
    }

    var id: String { rawValue }

    func title(language: String) -> String {
        switch (self, language == "es") {
        case (.talkAboutInterests, false): "Things we like"
        case (.talkAboutInterests, true): "Cosas que nos gustan"
        case (.shareNews, false): "Share news"
        case (.shareNews, true): "Contar novedades"
        case (.makeAPlan, false): "Make a plan"
        case (.makeAPlan, true): "Hacer un plan"
        case (.playTogether, false): "Play together"
        case (.playTogether, true): "Jugar juntos"
        }
    }

    func detail(language: String) -> String {
        switch (self, language == "es") {
        case (.talkAboutInterests, false): "Say what you enjoy, notice, or want to know."
        case (.talkAboutInterests, true): "Hablen de lo que les gusta, notan o quieren saber."
        case (.shareNews, false): "Tell each other something that happened."
        case (.shareNews, true): "Cuéntense algo que pasó."
        case (.makeAPlan, false): "Choose what to do, where to go, or what to change."
        case (.makeAPlan, true): "Elijan qué hacer, adónde ir o qué cambiar."
        case (.playTogether, false): "Take turns in a game or shared activity."
        case (.playTogether, true): "Tomen turnos en un juego o actividad."
        }
    }

    func ideas(language: String) -> [Idea] {
        if language == "es" {
            return switch self {
            case .talkAboutInterests: [
                Idea(partner: "Muestra algo que te gusta.", communicator: "Cuenta lo que te gusta o no te gusta."),
                Idea(partner: "Comenta algo que ves o escuchas.", communicator: "Comenta algo que notas."),
                Idea(partner: "Pregunta qué piensa la otra persona.", communicator: "Haz una pregunta o comparte tu opinión.")
            ]
            case .shareNews: [
                Idea(partner: "Cuenta algo que pasó hoy.", communicator: "Cuenta algo que pasó hoy."),
                Idea(partner: "Muestra cómo te sentiste.", communicator: "Di cómo te sentiste, si quieres."),
                Idea(partner: "Pregunta qué pasó después.", communicator: "Agrega más detalles o cambia de tema.")
            ]
            case .makeAPlan: [
                Idea(partner: "Sugiere algo que podrían hacer.", communicator: "Elige, sugiere otra idea o di que no."),
                Idea(partner: "Pregunta cuándo o dónde.", communicator: "Di cuándo, dónde o qué necesitas."),
                Idea(partner: "Propón un cambio al plan.", communicator: "Acepta, cambia el plan o pide una pausa.")
            ]
            case .playTogether: [
                Idea(partner: "Muestra cómo pedir un turno.", communicator: "Pide un turno, espera o elige otra cosa."),
                Idea(partner: "Comenta lo que está pasando.", communicator: "Comenta el juego o pide ayuda."),
                Idea(partner: "Pregunta si quieren seguir.", communicator: "Di otra vez, cambia de juego o termina.")
            ]
            }
        }
        return switch self {
        case .talkAboutInterests: [
            Idea(partner: "Show something you like.", communicator: "Say what you like or do not like."),
            Idea(partner: "Comment on something you see or hear.", communicator: "Comment on something you notice."),
            Idea(partner: "Ask what the other person thinks.", communicator: "Ask a question or share your opinion.")
        ]
        case .shareNews: [
            Idea(partner: "Tell something that happened today.", communicator: "Tell something that happened today."),
            Idea(partner: "Show how you felt about it.", communicator: "Say how you felt, if you want to."),
            Idea(partner: "Ask what happened next.", communicator: "Add more details or change the topic.")
        ]
        case .makeAPlan: [
            Idea(partner: "Suggest something you could do.", communicator: "Choose, suggest another idea, or say no."),
            Idea(partner: "Ask when or where.", communicator: "Say when, where, or what you need."),
            Idea(partner: "Offer a change to the plan.", communicator: "Agree, change the plan, or ask for a break.")
        ]
        case .playTogether: [
            Idea(partner: "Show how to ask for a turn.", communicator: "Ask for a turn, wait, or choose something else."),
            Idea(partner: "Comment on what is happening.", communicator: "Comment on the game or ask for help."),
            Idea(partner: "Ask if you should continue.", communicator: "Say again, change games, or finish.")
        ]
        }
    }
}
