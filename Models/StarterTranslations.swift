import Foundation

enum StarterTranslations {
    static let spanish: [String: String] = [
        "I": "yo", "want": "quiero", "need": "necesito", "like": "me gusta",
        "don't": "no", "yes": "sí", "no": "no", "more": "más",
        "stop": "para", "go": "vamos", "help": "ayuda", "please": "por favor",
        "you": "tú", "it": "eso", "that": "eso", "do": "hacer",
        "not": "no", "all done": "ya terminé", "again": "otra vez",
        "different": "diferente", "my": "mi", "your": "tu", "here": "aquí",
        "there": "allí", "water": "agua", "bathroom": "baño", "break": "descanso",
        "rest": "descansar", "hungry": "tengo hambre", "thirsty": "tengo sed",
        "sleep": "dormir", "medicine": "medicina", "pain": "dolor",
        "too hot": "demasiado calor", "too cold": "demasiado frío",
        "quiet": "silencio", "space": "espacio", "call home": "llamar a casa",
        "happy": "feliz", "sad": "triste", "angry": "enojo",
        "scared": "tengo miedo", "worried": "preocupación",
        "excited": "emoción", "tired": "cansancio",
        "overwhelmed": "me abruma", "calm": "calma", "confused": "no entiendo",
        "proud": "orgullo", "lonely": "soledad", "okay": "bien",
        "not okay": "no estoy bien", "mom": "mamá", "dad": "papá",
        "friend": "amigo", "teacher": "maestro", "doctor": "doctor",
        "family": "familia", "me": "yo", "everyone": "todos",
        "eat": "comer", "drink": "beber", "snack": "merienda",
        "breakfast": "desayuno", "lunch": "almuerzo", "dinner": "cena",
        "fruit": "fruta", "pizza": "pizza", "sandwich": "sándwich",
        "milk": "leche", "juice": "jugo", "play": "jugar",
        "read": "leer", "music": "música", "draw": "dibujar",
        "walk": "caminar", "outside": "afuera", "game": "juego",
        "watch": "mirar", "listen": "escuchar", "learn": "aprender",
        "work": "trabajar", "swim": "nadar", "what": "qué",
        "where": "dónde", "when": "cuándo", "who": "quién",
        "why": "por qué", "how": "cómo", "can I?": "¿puedo?",
        "what's next?": "¿qué sigue?", "are you okay?": "¿estás bien?",
        "too loud": "demasiado ruido", "too bright": "demasiada luz",
        "touch hurts": "me duele cuando me tocan",
        "headphones": "audífonos", "dim lights": "baja las luces",
        "quiet room": "habitación tranquila", "deep pressure": "presión profunda",
        "no touch": "no me toques", "fidget": "objeto sensorial",
        "need movement": "necesito moverme", "home": "casa",
        "school": "escuela", "park": "parque", "store": "tienda",
        "hospital": "hospital", "inside": "adentro", "car": "carro",
        "now": "ahora", "later": "después", "today": "hoy",
        "tomorrow": "mañana", "morning": "la mañana", "night": "noche",
        "wait": "espera", "soon": "pronto"
    ]

    static func forItems(_ items: [CommunicationItem]) -> [String: [String: WordTranslation]] {
        var translations: [String: [String: WordTranslation]] = [:]
        for item in items where !item.isCustom {
            guard let spanish = spanish[item.label] else { continue }
            translations[item.id.uuidString] = ["es": WordTranslation(label: spanish, message: spanish)]
        }
        return translations
    }
}
