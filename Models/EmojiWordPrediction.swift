import Foundation

enum EmojiWordPrediction {
    private static let english: [String: [String]] = [
        "🛸": ["UFO", "alien", "flying saucer"],
        "🚽": ["bathroom", "toilet", "restroom"],
        "🚻": ["bathroom", "restroom"],
        "🏥": ["hospital", "doctor", "medical help"],
        "👩‍⚕": ["doctor", "health worker"],
        "👨‍⚕": ["doctor", "health worker"],
        "🏫": ["school", "classroom"],
        "🏠": ["home", "house"],
        "🛏": ["bed", "rest", "sleep"],
        "💧": ["water", "drink"],
        "🥤": ["drink", "juice"],
        "🍽": ["food", "eat", "meal"],
        "🍔": ["burger", "food", "hungry"],
        "🍎": ["apple", "food"],
        "🤒": ["sick", "fever", "unwell"],
        "🤕": ["hurt", "injured", "pain"],
        "💊": ["medicine", "pill"],
        "😢": ["sad", "crying"],
        "😡": ["angry", "upset"],
        "😰": ["anxious", "worried"],
        "😴": ["tired", "sleepy"],
        "😀": ["happy", "smiling"],
        "❤": ["love", "heart"],
        "🤝": ["help", "together"],
        "👋": ["hello", "goodbye", "wave"],
        "🛑": ["stop", "wait"],
        "❓": ["question", "what"],
        "⚠": ["warning", "careful"],
        "🚗": ["car", "drive"],
        "🚌": ["bus", "ride"],
        "📱": ["phone", "call"],
        "📚": ["books", "read"],
        "🎉": ["celebrate", "party"],
        "🐕": ["dog", "pet"],
        "🐈": ["cat", "pet"]
    ]

    private static let spanish: [String: [String]] = [
        "🛸": ["ovni", "extraterrestre"],
        "🚽": ["baño", "inodoro"],
        "🚻": ["baño"],
        "🏥": ["hospital", "médico", "ayuda médica"],
        "👩‍⚕": ["médica", "doctora"],
        "👨‍⚕": ["médico", "doctor"],
        "🏫": ["escuela", "clase"],
        "🏠": ["casa", "hogar"],
        "🛏": ["cama", "descansar", "dormir"],
        "💧": ["agua", "beber"],
        "🥤": ["bebida", "jugo"],
        "🍽": ["comida", "comer"],
        "🍔": ["hamburguesa", "comida"],
        "🍎": ["manzana", "comida"],
        "🤒": ["enfermo", "fiebre"],
        "🤕": ["dolor", "herido"],
        "💊": ["medicina", "pastilla"],
        "😢": ["triste", "llorando"],
        "😡": ["enojado", "molesto"],
        "😰": ["ansioso", "preocupado"],
        "😴": ["cansado", "sueño"],
        "😀": ["feliz", "sonriendo"],
        "❤": ["amor", "corazón"],
        "🤝": ["ayuda", "juntos"],
        "👋": ["hola", "adiós"],
        "🛑": ["alto", "espera"],
        "🚗": ["coche", "auto"],
        "🚌": ["autobús"],
        "📱": ["teléfono", "llamar"],
        "📚": ["libros", "leer"],
        "🐕": ["perro", "mascota"],
        "🐈": ["gato", "mascota"]
    ]

    static func trailingEmoji(in text: String) -> String? {
        guard let last = text.last else { return nil }
        let scalars = String(last).unicodeScalars
        guard scalars.contains(where: { $0.properties.isEmojiPresentation || $0.value == 0xFE0F }) else {
            return nil
        }
        return String(last)
    }

    static func suggestions(for text: String, language: String = "en", limit: Int = 5) -> [String] {
        guard let emoji = trailingEmoji(in: text), limit > 0 else { return [] }
        let key = normalized(emoji)
        var candidates = (language == "es" ? spanish : english)[key] ?? []
        if let region = flagRegion(emoji),
           let name = Locale(identifier: language == "es" ? "es_ES" : "en_US")
            .localizedString(forRegionCode: region) {
            candidates.append(name)
        } else if language != "es", let name = unicodeName(emoji) {
            candidates.append(name)
        }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.lowercased()).inserted }.prefix(limit).map { $0 }
    }

    static func replacingTrailingEmoji(in text: String, with word: String) -> String {
        guard trailingEmoji(in: text) != nil else { return text }
        return String(text.dropLast()) + word + " "
    }

    static func keepingTrailingEmoji(in text: String) -> String {
        trailingEmoji(in: text) == nil ? text : text + " "
    }

    private static func normalized(_ emoji: String) -> String {
        String(String.UnicodeScalarView(emoji.unicodeScalars.filter {
            $0.value != 0xFE0E && $0.value != 0xFE0F && !(0x1F3FB...0x1F3FF).contains($0.value)
        }))
    }

    private static func flagRegion(_ emoji: String) -> String? {
        let scalars = Array(emoji.unicodeScalars)
        guard scalars.count == 2,
              scalars.allSatisfy({ (0x1F1E6...0x1F1FF).contains($0.value) }) else { return nil }
        let letters = scalars.map { Character(UnicodeScalar($0.value - 0x1F1E6 + 65)!) }
        return String(letters)
    }

    private static func unicodeName(_ emoji: String) -> String? {
        guard let transformed = emoji.applyingTransform(.toUnicodeName, reverse: false) else { return nil }
        let names = transformed.components(separatedBy: "\\N{").dropFirst().compactMap { part -> String? in
            guard let end = part.firstIndex(of: "}") else { return nil }
            let name = String(part[..<end])
            guard name != "ZERO WIDTH JOINER", !name.hasPrefix("VARIATION SELECTOR"),
                  !name.hasPrefix("EMOJI MODIFIER"), name != "COMBINING ENCLOSING KEYCAP" else {
                return nil
            }
            return name.lowercased()
        }
        guard !names.isEmpty else { return nil }
        let label = names.joined(separator: " ")
        return label.count <= 48 ? label : nil
    }
}
