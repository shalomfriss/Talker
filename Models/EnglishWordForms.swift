import Foundation

enum EnglishWordForms {
    enum Kind: String, CaseIterable, Identifiable {
        case base
        case pluralOrPresent
        case ongoing
        case past
        case future

        var id: String { rawValue }

        var title: String {
            switch self {
            case .base: "Original"
            case .pluralOrPresent: "More than one / someone does it"
            case .ongoing: "Happening now"
            case .past: "Happened before"
            case .future: "Will happen"
            }
        }
    }

    struct Option: Identifiable {
        let kind: Kind
        let text: String
        var title: String { customTitle ?? kind.title }
        var language: String = "en"
        var customTitle: String? = nil
        var id: Kind { kind }
    }

    private static let irregular: [String: (present: String, ongoing: String, past: String)] = [
        "be": ("is", "being", "was"),
        "buy": ("buys", "buying", "bought"),
        "come": ("comes", "coming", "came"),
        "do": ("does", "doing", "did"),
        "drink": ("drinks", "drinking", "drank"),
        "eat": ("eats", "eating", "ate"),
        "feel": ("feels", "feeling", "felt"),
        "find": ("finds", "finding", "found"),
        "get": ("gets", "getting", "got"),
        "give": ("gives", "giving", "gave"),
        "go": ("goes", "going", "went"),
        "have": ("has", "having", "had"),
        "know": ("knows", "knowing", "knew"),
        "leave": ("leaves", "leaving", "left"),
        "make": ("makes", "making", "made"),
        "put": ("puts", "putting", "put"),
        "read": ("reads", "reading", "read"),
        "run": ("runs", "running", "ran"),
        "say": ("says", "saying", "said"),
        "see": ("sees", "seeing", "saw"),
        "sit": ("sits", "sitting", "sat"),
        "sleep": ("sleeps", "sleeping", "slept"),
        "take": ("takes", "taking", "took"),
        "think": ("thinks", "thinking", "thought"),
        "write": ("writes", "writing", "wrote")
    ]
    private static let irregularPlurals: [String: String] = [
        "child": "children", "person": "people", "foot": "feet",
        "tooth": "teeth", "mouse": "mice"
    ]
    private static let doubledFinalConsonant: Set<String> = [
        "chat", "clap", "drop", "get", "hug", "plan", "run", "shop", "sit", "stop", "swim"
    ]
    private static let unavailableWords: Set<String> = [
        "a", "an", "and", "he", "i", "it", "no", "of", "or", "please",
        "she", "the", "they", "to", "we", "yes", "you"
    ]

    static func options(for word: String) -> [Option] {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        guard word.count >= 2, word.unicodeScalars.allSatisfy(allowed.contains),
              !unavailableWords.contains(word.lowercased()) else { return [] }
        let base = word.lowercased()
        let forms = irregular[base]
        let present = irregularPlurals[base] ?? forms?.present ?? regularPresent(base)
        let ongoing = forms?.ongoing ?? regularOngoing(base)
        let past = forms?.past ?? regularPast(base)
        let values: [(Kind, String)] = [
            (.base, base), (.pluralOrPresent, present), (.ongoing, ongoing),
            (.past, past), (.future, "will \(base)")
        ]
        return values.map { kind, value in Option(kind: kind, text: applyCase(of: word, to: value)) }
    }

    private static func regularPresent(_ word: String) -> String {
        if word.hasSuffix("y"), let before = word.dropLast().last, !"aeiou".contains(before) {
            return String(word.dropLast()) + "ies"
        }
        if ["s", "sh", "ch", "x", "z"].contains(where: word.hasSuffix) { return word + "es" }
        return word + "s"
    }

    private static func regularOngoing(_ word: String) -> String {
        if word.hasSuffix("ie") { return String(word.dropLast(2)) + "ying" }
        if doubledFinalConsonant.contains(word), let last = word.last { return word + String(last) + "ing" }
        if word.hasSuffix("e"), !word.hasSuffix("ee") { return String(word.dropLast()) + "ing" }
        return word + "ing"
    }

    private static func regularPast(_ word: String) -> String {
        if word.hasSuffix("e") { return word + "d" }
        if word.hasSuffix("y"), let before = word.dropLast().last, !"aeiou".contains(before) {
            return String(word.dropLast()) + "ied"
        }
        if doubledFinalConsonant.contains(word), let last = word.last { return word + String(last) + "ed" }
        return word + "ed"
    }

    private static func applyCase(of source: String, to value: String) -> String {
        if source == source.uppercased() { return value.uppercased() }
        if source.first?.isUppercase == true {
            return value.prefix(1).uppercased() + value.dropFirst()
        }
        return value
    }
}

// The existing word-form control shares its five actions across both languages.
// Spanish options name their subject and number explicitly so a speaker can choose safely.
enum SpanishWordForms {
    enum Role {
        case automatic, verb, noun
    }

    private typealias Option = EnglishWordForms.Option
    private typealias Kind = EnglishWordForms.Kind

    private static let regularVerbs: Set<String> = [
        "amar", "aprender", "beber", "buscar", "caminar", "cantar", "comer",
        "comprar", "correr", "descansar", "dibujar", "escuchar", "esperar",
        "hablar", "lavar", "limpiar", "llamar", "mirar", "nadar",
        "necesitar", "pasear", "preguntar", "saltar", "terminar", "trabajar",
        "usar", "vivir"
    ]

    private static let irregularVerbs: [String: (present: String, ongoing: String, past: String, future: String)] = [
        "dar": ("doy", "estoy dando", "di", "daré"),
        "decir": ("digo", "estoy diciendo", "dije", "diré"),
        "dormir": ("duermo", "estoy durmiendo", "dormí", "dormiré"),
        "estar": ("estoy", "estoy estando", "estuve", "estaré"),
        "hacer": ("hago", "estoy haciendo", "hice", "haré"),
        "ir": ("voy", "estoy yendo", "fui", "iré"),
        "jugar": ("juego", "estoy jugando", "jugué", "jugaré"),
        "leer": ("leo", "estoy leyendo", "leí", "leeré"),
        "poder": ("puedo", "estoy pudiendo", "pude", "podré"),
        "querer": ("quiero", "estoy queriendo", "quise", "querré"),
        "ser": ("soy", "estoy siendo", "fui", "seré"),
        "tener": ("tengo", "estoy teniendo", "tuve", "tendré"),
        "venir": ("vengo", "estoy viniendo", "vine", "vendré"),
        "ver": ("veo", "estoy viendo", "vi", "veré")
    ]

    private static let unavailableWords: Set<String> = [
        "a", "al", "de", "del", "el", "ella", "ellos", "en", "es", "esa", "eso",
        "esta", "está", "esto", "hay", "la", "las", "lo", "los", "me", "mi",
        "más", "muy", "no", "nos", "para", "por", "que", "se", "si", "sí",
        "su", "te", "tú", "un", "una", "uno", "vamos", "yo", "quiero",
        "necesito", "puedo", "tengo", "voy", "soy", "estoy", "hago"
    ]

    private static let exceptionalPlurals: [String: String] = [
        "autobús": "autobuses", "camión": "camiones", "canción": "canciones",
        "corazón": "corazones", "lápiz": "lápices", "mes": "meses",
        "país": "países", "régimen": "regímenes"
    ]

    private static let conjugatedVerbWords: Set<String> = {
        let verbs = regularVerbs.union(irregularVerbs.keys)
        return Set(verbs.flatMap { verb -> [String] in
            guard let forms = verbForms(for: verb) else { return [] }
            return [forms.present, forms.past, forms.future]
        })
    }()

    static func options(for word: String, role: Role = .automatic) -> [EnglishWordForms.Option] {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZáéíóúüñÁÉÍÓÚÜÑ")
        guard word.count >= 2, word.unicodeScalars.allSatisfy(allowed.contains) else { return [] }
        let base = word.lowercased()

        if role == .noun, verbForms(for: base) != nil { return [] }

        if role != .noun, let forms = verbForms(for: base) {
            let values: [(Kind, String, String)] = [
                (.base, base, "Infinitive"),
                (.pluralOrPresent, forms.present, "I do it now (yo)"),
                (.ongoing, forms.ongoing, "I am doing it (yo)"),
                (.past, forms.past, "I did it (yo)"),
                (.future, forms.future, "I will do it (yo)")
            ]
            return values.map { kind, value, title in
                Option(kind: kind, text: applyCase(of: word, to: value), language: "es", customTitle: title)
            }
        }
        guard role != .verb, !unavailableWords.contains(base),
              (role == .noun || !conjugatedVerbWords.contains(base)),
              !base.hasSuffix("ando"), !base.hasSuffix("iendo"),
              let plural = plural(of: base), plural != base else { return [] }
        return [
            Option(kind: .base, text: word, language: "es", customTitle: "One / original"),
            Option(kind: .pluralOrPresent, text: applyCase(of: word, to: plural),
                   language: "es", customTitle: "More than one")
        ]
    }

    private static func verbForms(for word: String)
        -> (present: String, ongoing: String, past: String, future: String)? {
        if let irregular = irregularVerbs[word] { return irregular }
        guard regularVerbs.contains(word) else { return nil }
        let stem = String(word.dropLast(2))
        if word.hasSuffix("ar") {
            let past: String
            if word.hasSuffix("car") { past = String(stem.dropLast()) + "qué" }
            else if word.hasSuffix("gar") { past = String(stem.dropLast()) + "gué" }
            else if word.hasSuffix("zar") { past = String(stem.dropLast()) + "cé" }
            else { past = stem + "é" }
            return (stem + "o", "estoy " + stem + "ando", past, word + "é")
        }
        if word.hasSuffix("er") || word.hasSuffix("ir") {
            return (stem + "o", "estoy " + stem + "iendo", stem + "í", word + "é")
        }
        return nil
    }

    private static func plural(of word: String) -> String? {
        if let exceptional = exceptionalPlurals[word] { return exceptional }
        guard let last = word.last else { return nil }
        if "aeiouáéó".contains(last) { return word + "s" }
        if last == "z" { return String(word.dropLast()) + "ces" }
        if last == "í" || last == "ú" { return word + "es" }
        if "lnrdj".contains(last), !word.unicodeScalars.contains(where: { "áéíóú".unicodeScalars.contains($0) }) {
            return word + "es"
        }
        return nil
    }

    private static func applyCase(of source: String, to value: String) -> String {
        if source == source.uppercased() { return value.uppercased() }
        if source.first?.isUppercase == true { return value.prefix(1).uppercased() + value.dropFirst() }
        return value
    }
}
