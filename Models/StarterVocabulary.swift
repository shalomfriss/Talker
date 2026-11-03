import Foundation

enum StarterVocabulary {
    static let categories = ["Core", "Needs", "Feelings", "People", "Food", "Activities", "Questions", "Sensory", "Places", "Time"]

    static let items: [CommunicationItem] = {
        let rows: [(String, String)] = [
            ("Core", "I|🙋, want|🤲, need|🫶, like|❤️, don't|🚫, yes|✅, no|❌, more|➕, stop|✋, go|➡️, help|🆘, please|🙏, you|👉, it|🔵, that|👆, do|💪, not|⛔️, all done|🏁, again|🔁, different|🔀, my|🫵, your|🤝, here|📍, there|🧭"),
            ("Needs", "water|💧, bathroom|🚻, break|⏸️, rest|🛋️, hungry|🍽️, thirsty|🥤, sleep|🛏️, medicine|💊, pain|🩹, too hot|🌡️, too cold|🥶, quiet|🤫, space|↔️, call home|📞"),
            ("Feelings", "happy|😊, sad|😢, angry|😠, scared|😨, worried|😟, excited|🤩, tired|😴, overwhelmed|😣, calm|😌, confused|😕, proud|🥰, lonely|😔, okay|🙂, not okay|😞"),
            ("People", "mom|👩, dad|👨, friend|🧑‍🤝‍🧑, teacher|🧑‍🏫, doctor|🧑‍⚕️, family|🏠, me|🙋, everyone|👥"),
            ("Food", "eat|🍽️, drink|🥤, snack|🍪, breakfast|🥣, lunch|🥪, dinner|🍲, fruit|🍎, pizza|🍕, sandwich|🥪, milk|🥛, juice|🧃, water|💧"),
            ("Activities", "play|🧸, read|📖, music|🎵, draw|🎨, walk|🚶, outside|🌳, game|🎮, watch|👀, listen|👂, learn|🧠, work|📝, swim|🏊"),
            ("Questions", "what|❓, where|🧭, when|🕒, who|👤, why|🤔, how|💭, can I?|🙋, what's next?|⏭️, are you okay?|💙"),
            ("Sensory", "too loud|🔊, too bright|☀️, touch hurts|✋, headphones|🎧, dim lights|💡, quiet room|🚪, deep pressure|🫂, no touch|🚫, fidget|🌀, need movement|🏃"),
            ("Places", "home|🏠, school|🏫, park|🌳, store|🏪, hospital|🏥, outside|🌤️, inside|🚪, car|🚙"),
            ("Time", "now|⏰, later|⌛️, today|📅, tomorrow|🗓️, morning|🌅, night|🌙, wait|✋, soon|⏱️")
        ]
        let phraseExamples: [String: [CardPhrase]] = [
            "Core/different": [
                CardPhrase(text: "I want something different.", spanishText: "Quiero algo diferente."),
                CardPhrase(text: "Please show me another option.", spanishText: "Muéstrame otra opción, por favor.")
            ],
            "Activities/music": [
                CardPhrase(text: "I want to listen to music.", spanishText: "Quiero escuchar música."),
                CardPhrase(text: "Please change the music.", spanishText: "Cambia la música, por favor.")
            ],
            "Questions/what": [
                CardPhrase(text: "What is happening?", spanishText: "¿Qué está pasando?"),
                CardPhrase(text: "What does that mean?", spanishText: "¿Qué significa eso?")
            ]
        ]
        let wordItems = rows.flatMap { category, entry in
            entry.split(separator: ",").map { part in
                let bits = part.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                return CommunicationItem(label: bits[0], symbol: bits[1], message: bits[0],
                                         category: category, phraseOptions: phraseExamples["\(category)/\(bits[0])"])
            }
        }
        return wordItems + [CommunicationItem(label: "Current time", symbol: "🕒",
                                              message: "Current time", category: "Time",
                                              action: .speakCurrentTime)]
    }()

    static let routines: [RoutineStep] = [
        .init(title: "Get dressed", symbol: "👕"),
        .init(title: "Eat breakfast", symbol: "🥣"),
        .init(title: "Brush teeth", symbol: "🪥"),
        .init(title: "Pack bag", symbol: "🎒")
    ]

    static let phrases: [SavedPhrase] = [
        .init(text: "I need a break."),
        .init(text: "Please give me time to answer."),
        .init(text: "I do not want to be touched."),
        .init(text: "I am overwhelmed. Please help me find a quiet place."),
        .init(text: "I have something to say.")
    ]

    static let choiceBoards: [ChoiceBoard] = [
        ChoiceBoard(title: "What do you need?", options: ["water", "bathroom", "break", "help"]
            .compactMap { label in items.first { $0.label == label }.map(ChoiceOption.init(item:)) }),
        ChoiceBoard(title: "What would you like to do?", options: ["play", "read", "music", "walk"]
            .compactMap { label in items.first { $0.label == label }.map(ChoiceOption.init(item:)) })
    ]
}
