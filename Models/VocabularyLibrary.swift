import Foundation

enum VocabularyLibraryGroup: String, CaseIterable, Identifiable {
    case dailyLife = "Daily life"
    case community = "Community"
    case support = "Support and safety"

    var id: String { rawValue }
}

struct VocabularyLibraryWord: Equatable {
    let label: String
    let symbol: String
    let spanishLabel: String

    init(_ label: String, _ symbol: String, _ spanishLabel: String) {
        self.label = label
        self.symbol = symbol
        self.spanishLabel = spanishLabel
    }
}

struct VocabularyLibraryPage: Identifiable {
    let id: String
    let title: String
    let icon: String
    let group: VocabularyLibraryGroup
    let summary: String
    let words: [VocabularyLibraryWord]
}

struct LibraryPageAddResult: Equatable {
    let boardName: String
    let addedCount: Int
    let createdBoard: Bool
}

struct VocabularyLibraryTemplate: Identifiable {
    let id: String
    let title: String
    let icon: String
    let summary: String
    let pageIDs: [String]
}

struct LibraryTemplateAddResult: Equatable {
    let profileName: String
    let pageCount: Int
    let buttonCount: Int
}

enum LibraryTemplateApplyMode: String, CaseIterable {
    case keepPersonalBoards
    case replacePersonalBoards
}

struct LibraryTemplateApplyResult: Equatable {
    let pageCount: Int
    let buttonCount: Int
    let removedBoardCount: Int
    let backupID: UUID
    let backupName: String
}

enum LibraryTemplateApplyError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "This template is unavailable."
    }
}

enum VocabularyLibrary {
    static let templates: [VocabularyLibraryTemplate] = [
        .init(id: "school-day", title: "School day", icon: "🎒",
              summary: "Learning, conversation, meals, and safety.",
              pageIDs: ["school", "conversation", "meals", "safety"]),
        .init(id: "daily-independence", title: "Daily independence", icon: "🏡",
              summary: "Everyday conversations, travel, work, meals, and personal care.",
              pageIDs: ["conversation", "travel", "work", "meals", "personal-care", "safety"]),
        .init(id: "health-and-support", title: "Health and support", icon: "🩺",
              summary: "Appointments, care, getting around, and safety.",
              pageIDs: ["health", "personal-care", "travel", "safety"]),
        .init(id: "social-and-interests", title: "Social and interests", icon: "🎨",
              summary: "Conversation, relationships, hobbies, and devices.",
              pageIDs: ["conversation", "friends-family", "hobbies-play", "technology"]),
        .init(id: "community-errands", title: "Community errands", icon: "🛍️",
              summary: "Travel, shopping, meals, and sensory needs.",
              pageIDs: ["travel", "shopping", "meals", "sensory-needs"]),
        .init(id: "self-advocacy", title: "Self advocacy", icon: "🗣️",
              summary: "Choices, consent, sensory needs, health, and safety.",
              pageIDs: ["rights-choices", "sensory-needs", "health", "safety"]),
        .init(id: "young-communicator", title: "Young communicator", icon: "🧸",
              summary: "Choices, play, help, and communication repair.",
              pageIDs: ["early-choices", "hobbies-play", "at-home", "communication-repair", "safety"]),
        .init(id: "teen-conversations", title: "Teen conversations", icon: "🎒",
              summary: "School transitions, friends, privacy, technology, and self advocacy.",
              pageIDs: ["school-transitions", "friends-family", "privacy-boundaries",
                        "technology", "rights-choices", "communication-repair"]),
        .init(id: "adult-independence", title: "Adult independence", icon: "🧭",
              summary: "Work, appointments, travel, personal care, and communication repair.",
              pageIDs: ["work", "appointments-paperwork", "travel", "personal-care",
                        "rights-choices", "communication-repair"])
    ]

    static func template(id: String) -> VocabularyLibraryTemplate? {
        templates.first { $0.id == id }
    }

    static let pages: [VocabularyLibraryPage] = [
        .init(id: "school", title: "At school", icon: "🏫", group: .community,
              summary: "Classroom, learning, and school-day requests.", words: [
                .init("I need help", "🙋", "Necesito ayuda"),
                .init("I don't understand", "❓", "No entiendo"),
                .init("Please repeat", "🔁", "Repite, por favor"),
                .init("I finished", "✅", "Terminé"),
                .init("My turn", "🖐️", "Mi turno"),
                .init("Your turn", "👉", "Tu turno"),
                .init("I need a break", "⏸️", "Necesito un descanso"),
                .init("Too loud", "🔊", "Hay demasiado ruido"),
                .init("Lunch", "🥪", "Almuerzo"),
                .init("Library", "📚", "Biblioteca"),
                .init("Homework", "📝", "Tarea"),
                .init("Go home", "🏠", "Ir a casa")
              ]),
        .init(id: "health", title: "Health visit", icon: "🩺", group: .support,
              summary: "Say what feels wrong and ask questions during an appointment.", words: [
                .init("It hurts", "🩹", "Me duele"),
                .init("Here", "📍", "Aquí"),
                .init("How much longer?", "⏱️", "¿Cuánto falta?"),
                .init("I feel sick", "🤒", "Me siento mal"),
                .init("I feel dizzy", "💫", "Tengo mareos"),
                .init("I need water", "💧", "Necesito agua"),
                .init("Please explain", "💬", "Explícamelo, por favor"),
                .init("I need a break", "⏸️", "Necesito un descanso"),
                .init("I am scared", "😟", "Tengo miedo"),
                .init("No touch", "✋", "No me toques"),
                .init("Yes, I agree", "✅", "Sí, estoy de acuerdo"),
                .init("No, I do not agree", "🚫", "No estoy de acuerdo")
              ]),
        .init(id: "conversation", title: "Conversation", icon: "💬", group: .dailyLife,
              summary: "Start, continue, and pause a social conversation.", words: [
                .init("Hello", "👋", "Hola"),
                .init("Goodbye", "👋", "Adiós"),
                .init("How are you?", "🙂", "¿Cómo estás?"),
                .init("My name is", "🙋", "Me llamo"),
                .init("Tell me more", "👂", "Cuéntame más"),
                .init("Please wait", "⏳", "Espera, por favor"),
                .init("I agree", "✅", "Estoy de acuerdo"),
                .init("I disagree", "🚫", "No estoy de acuerdo"),
                .init("Thank you", "🙏", "Gracias"),
                .init("Sorry", "💙", "Lo siento"),
                .init("Let's talk later", "🕒", "Hablemos luego"),
                .init("I need space", "↔️", "Necesito espacio")
              ]),
        .init(id: "travel", title: "Getting around", icon: "🚌", group: .community,
              summary: "Travel, directions, and asking for help away from home.", words: [
                .init("Where are we going?", "🧭", "¿A dónde vamos?"),
                .init("I want to go home", "🏠", "Quiero ir a casa"),
                .init("Bus", "🚌", "Autobús"),
                .init("Train", "🚆", "Tren"),
                .init("Car", "🚗", "Coche"),
                .init("Stop here", "🛑", "Para aquí"),
                .init("Turn left", "⬅️", "Gira a la izquierda"),
                .init("Turn right", "➡️", "Gira a la derecha"),
                .init("I am lost", "🗺️", "No sé dónde estoy"),
                .init("Please call someone", "📞", "Llama a alguien, por favor"),
                .init("Bathroom", "🚻", "Baño"),
                .init("I need help", "🆘", "Necesito ayuda")
              ]),
        .init(id: "work", title: "At work", icon: "💼", group: .community,
              summary: "Tasks, instructions, and breaks at work or volunteering.", words: [
                .init("I can start", "✅", "Puedo empezar"),
                .init("What is next?", "⏭️", "¿Qué sigue?"),
                .init("Please show me", "👀", "Muéstrame, por favor"),
                .init("I need instructions", "📋", "Necesito instrucciones"),
                .init("I need a break", "⏸️", "Necesito un descanso"),
                .init("I finished", "✅", "Terminé"),
                .init("I need more time", "⌛", "Necesito más tiempo"),
                .init("Too noisy", "🔊", "Hay demasiado ruido"),
                .init("Can you repeat?", "🔁", "¿Puedes repetirlo?"),
                .init("Let's meet", "🤝", "Reunámonos"),
                .init("I disagree", "🚫", "No estoy de acuerdo"),
                .init("Thank you", "🙏", "Gracias")
              ]),
        .init(id: "meals", title: "Meals", icon: "🍽️", group: .dailyLife,
              summary: "Food choices, comfort, and dietary needs.", words: [
                .init("I am hungry", "🍽️", "Tengo hambre"),
                .init("I am thirsty", "🥤", "Tengo sed"),
                .init("I want this", "👆", "Quiero esto"),
                .init("I don't want this", "🚫", "No quiero esto"),
                .init("More, please", "➕", "Más, por favor"),
                .init("All done", "🏁", "Terminé"),
                .init("I have an allergy", "⚠️", "Tengo una alergia"),
                .init("Is this safe for me?", "❓", "¿Esto es seguro para mí?"),
                .init("Too hot", "🌡️", "Está demasiado caliente"),
                .init("Too cold", "🥶", "Está demasiado frío"),
                .init("I need a spoon", "🥄", "Necesito una cuchara"),
                .init("Water, please", "💧", "Agua, por favor")
              ]),
        .init(id: "personal-care", title: "Personal care", icon: "🪥", group: .dailyLife,
              summary: "Daily care, privacy, and asking for help.", words: [
                .init("Wash hands", "🧼", "Lavar las manos"),
                .init("Brush teeth", "🪥", "Cepillar los dientes"),
                .init("Shower", "🚿", "Ducha"),
                .init("Get dressed", "👕", "Vestirse"),
                .init("Change clothes", "👚", "Cambiarse de ropa"),
                .init("Bathroom", "🚻", "Baño"),
                .init("I need privacy", "🚪", "Necesito privacidad"),
                .init("Please help me", "🙋", "Ayúdame, por favor"),
                .init("I can do it", "💪", "Puedo hacerlo"),
                .init("I need more time", "⏳", "Necesito más tiempo"),
                .init("It is uncomfortable", "😣", "Es incómodo"),
                .init("Stop, please", "✋", "Para, por favor")
              ]),
        .init(id: "safety", title: "Safety", icon: "🛟", group: .support,
              summary: "Urgent requests, boundaries, and finding support.", words: [
                .init("I need help now", "🆘", "Necesito ayuda ahora"),
                .init("Call my caregiver", "📞", "Llama a quien me cuida"),
                .init("I feel unsafe", "⚠️", "Necesito estar a salvo"),
                .init("Stop", "✋", "Para"),
                .init("Do not touch me", "🚫", "No me toques"),
                .init("I need a quiet place", "🤫", "Necesito un lugar tranquilo"),
                .init("I need water", "💧", "Necesito agua"),
                .init("I am hurt", "🩹", "Me hice daño"),
                .init("I am lost", "🧭", "No sé dónde estoy"),
                .init("Where is the exit?", "🚪", "¿Dónde está la salida?"),
                .init("Please stay with me", "🤝", "Quédate conmigo, por favor"),
                .init("Call emergency services", "🚑", "Llama a emergencias")
              ]),
        .init(id: "at-home", title: "At home", icon: "🏡", group: .dailyLife,
              summary: "Comfort, shared tasks, privacy, and everyday choices.", words: [
                .init("I want to rest", "🛋️", "Quiero descansar"),
                .init("Let's make a plan", "📋", "Hagamos un plan"),
                .init("I can do it myself", "💪", "Puedo hacerlo por mi cuenta"),
                .init("Please knock first", "🚪", "Toca la puerta antes de entrar, por favor"),
                .init("I need time alone", "🧘", "Necesito tiempo a solas"),
                .init("Turn off the light", "💡", "Apaga la luz"),
                .init("Open the window", "🪟", "Abre la ventana"),
                .init("Close the door", "🚪", "Cierra la puerta"),
                .init("Where is my bag?", "👜", "¿Dónde está mi bolso?"),
                .init("Help me clean up", "🧹", "Ayúdame a ordenar"),
                .init("I want to help", "🤝", "Quiero ayudar"),
                .init("Let's do this together", "🫶", "Hagamos esto en equipo")
              ]),
        .init(id: "shopping", title: "Shopping", icon: "🛍️", group: .community,
              summary: "Ask, choose, decline, and take a break while shopping.", words: [
                .init("I want to look", "👀", "Quiero mirar"),
                .init("How much is it?", "💰", "¿Cuánto cuesta?"),
                .init("I want this one", "👆", "Quiero esto"),
                .init("I need a different size", "📏", "Necesito otra talla"),
                .init("Can we leave?", "🚪", "¿Podemos irnos?"),
                .init("It is too crowded", "👥", "Hay demasiada gente"),
                .init("Please wait for me", "⏳", "Espérame, por favor"),
                .init("Where is the bathroom?", "🚻", "¿Dónde está el baño?"),
                .init("I need to pay", "💳", "Necesito pagar"),
                .init("I changed my mind", "🔄", "Cambié de opinión"),
                .init("I have a question", "❓", "Tengo una pregunta"),
                .init("Let's come back later", "🕒", "Volvamos más tarde")
              ]),
        .init(id: "friends-family", title: "Friends and family", icon: "💛", group: .dailyLife,
              summary: "Connect, share feelings, and set social boundaries.", words: [
                .init("I missed you", "💛", "Te extrañé"),
                .init("I want to spend time with you", "🤝", "Quiero pasar tiempo contigo"),
                .init("I want to talk", "💬", "Quiero hablar"),
                .init("I need a pause", "⏸️", "Necesito una pausa"),
                .init("Please listen", "👂", "Escúchame, por favor"),
                .init("I want a hug", "🫂", "Quiero un abrazo"),
                .init("No hug, please", "✋", "No quiero un abrazo, por favor"),
                .init("I need privacy", "🚪", "Necesito privacidad"),
                .init("Let's make plans", "📅", "Hagamos planes"),
                .init("That was funny", "😄", "Eso fue divertido"),
                .init("I feel left out", "😔", "Siento que no me incluyen"),
                .init("I appreciate you", "🙏", "Te aprecio")
              ]),
        .init(id: "hobbies-play", title: "Hobbies and play", icon: "🎨", group: .dailyLife,
              summary: "Share interests, ideas, and choices during activities.", words: [
                .init("I want to play", "🎲", "Quiero jugar"),
                .init("Let's choose a game", "🎮", "Elijamos un juego"),
                .init("I like this", "👍", "Me gusta esto"),
                .init("I want something different", "🔄", "Quiero algo diferente"),
                .init("Show me how", "👀", "Muéstrame cómo"),
                .init("Let's take turns", "🔁", "Tomemos turnos"),
                .init("I want to stop", "🛑", "Quiero parar"),
                .init("That is fun", "😄", "Eso es divertido"),
                .init("Can we try again?", "↩️", "¿Podemos intentarlo otra vez?"),
                .init("I have an idea", "💡", "Tengo una idea"),
                .init("I want to make something", "🛠️", "Quiero crear algo"),
                .init("Tell me about your interest", "👂", "Cuéntame sobre lo que te interesa")
              ]),
        .init(id: "sensory-needs", title: "Sensory needs", icon: "🎧", group: .support,
              summary: "Describe sensory discomfort and ask for adjustments.", words: [
                .init("The light is too bright", "💡", "La luz es demasiado fuerte"),
                .init("The sound hurts", "🔊", "El sonido me duele"),
                .init("I need headphones", "🎧", "Necesito auriculares"),
                .init("I need a quiet place", "🤫", "Necesito un lugar tranquilo"),
                .init("I need less touch", "✋", "No quiero que me toquen tanto"),
                .init("I want to move", "🚶", "Quiero moverme"),
                .init("I need a break", "⏸️", "Necesito un descanso"),
                .init("Tell me before touching me", "💬", "Avísame antes de tocarme"),
                .init("I want my comfort item", "🧸", "Quiero mi objeto de consuelo"),
                .init("Please dim the lights", "🔅", "Baja la intensidad de las luces, por favor"),
                .init("I feel overwhelmed", "😣", "Esto es demasiado para mí"),
                .init("I am ready to return", "✅", "Ya puedo volver")
              ]),
        .init(id: "technology", title: "Technology", icon: "📱", group: .community,
              summary: "Devices, communication access, and online activities.", words: [
                .init("My device is not working", "📱", "Mi dispositivo no funciona"),
                .init("I need my charger", "🔌", "Necesito mi cargador"),
                .init("Please give me my device", "🤲", "Dame mi dispositivo, por favor"),
                .init("I want to type", "⌨️", "Quiero escribir"),
                .init("The screen is too bright", "🔆", "La pantalla brilla demasiado"),
                .init("I need Wi-Fi", "📶", "Necesito wifi"),
                .init("Can you send me the link?", "🔗", "¿Puedes enviarme el enlace?"),
                .init("I want to call", "📞", "Quiero llamar"),
                .init("I want to watch", "▶️", "Quiero verlo"),
                .init("I need help with the app", "🛠️", "Necesito ayuda con la aplicación"),
                .init("Please don't take my device", "✋", "No te lleves mi dispositivo, por favor"),
                .init("I want to save this", "💾", "Quiero guardar esto")
              ]),
        .init(id: "communication-repair", title: "Communication repair", icon: "💬", group: .support,
              summary: "Ask for time, clarify a message, and keep control of a conversation.", words: [
                .init("I am still talking", "💬", "Todavía estoy hablando"),
                .init("That is not what I meant", "↩️", "Eso no es lo que quise decir"),
                .init("Ask me one question at a time", "☝️", "Hazme una pregunta a la vez"),
                .init("Give me time to answer", "⏳", "Dame tiempo para responder"),
                .init("Please repeat that", "🔁", "Repítelo, por favor"),
                .init("Please say it another way", "🔄", "Dilo de otra manera, por favor"),
                .init("I want to try again", "↪️", "Quiero intentarlo otra vez"),
                .init("I use this device to speak", "📱", "Uso este dispositivo para hablar"),
                .init("Please do not speak for me", "✋", "No hables por mí, por favor"),
                .init("Check that you understood me", "✅", "Confirma que me entendiste"),
                .init("I need my communication device", "🗣️", "Necesito mi dispositivo de comunicación"),
                .init("Please lower the background noise", "🔉", "Baja el ruido de fondo, por favor")
              ]),
        .init(id: "early-choices", title: "Early choices", icon: "🧸", group: .dailyLife,
              summary: "Short, flexible messages for choices, play, and help.", words: [
                .init("I want more", "➕", "Quiero más"),
                .init("I want to stop", "🛑", "Quiero parar"),
                .init("I like it", "❤️", "Me gusta"),
                .init("I do not like it", "💔", "No me gusta"),
                .init("My turn", "🙋", "Mi turno"),
                .init("Your turn", "👉", "Tu turno"),
                .init("Help me", "🆘", "Ayúdame"),
                .init("I can do it", "💪", "Puedo hacerlo"),
                .init("Look at this", "👀", "Mira esto"),
                .init("Let's play", "🎲", "Vamos a jugar"),
                .init("I need a break", "⏸️", "Necesito un descanso"),
                .init("I want something else", "🔀", "Quiero otra cosa")
              ]),
        .init(id: "school-transitions", title: "School transitions", icon: "🗓️", group: .community,
              summary: "Prepare for changes, movement, and the next school activity.", words: [
                .init("What happens next?", "⏭️", "¿Qué pasa después?"),
                .init("Tell me before plans change", "📢", "Avísame antes de cambiar los planes"),
                .init("Show me the schedule", "🗓️", "Muéstrame el horario"),
                .init("Warn me before we leave", "⏰", "Avísame antes de irnos"),
                .init("I need time to finish", "⌛", "Necesito tiempo para terminar"),
                .init("Where are we going?", "🧭", "¿A dónde vamos?"),
                .init("I want a break first", "⏸️", "Primero quiero un descanso"),
                .init("Please explain the change", "🔄", "Explícame el cambio, por favor"),
                .init("I am ready to move on", "✅", "Ya puedo seguir"),
                .init("I need my headphones", "🎧", "Necesito mis auriculares"),
                .init("I want to stay here", "📍", "Quiero quedarme aquí"),
                .init("Help me find my class", "🏫", "Ayúdame a encontrar mi clase")
              ]),
        .init(id: "appointments-paperwork", title: "Appointments and forms", icon: "📋", group: .community,
              summary: "Ask questions, understand options, and make decisions at appointments.", words: [
                .init("What is this form for?", "📄", "¿Para qué sirve este formulario?"),
                .init("Please explain this in simple words", "💬", "Explícame esto con palabras sencillas"),
                .init("I need a copy", "📋", "Necesito una copia"),
                .init("I need more time to decide", "⏳", "Necesito más tiempo para decidir"),
                .init("Please write that down", "✍️", "Escríbelo, por favor"),
                .init("Who can help me with this?", "🙋", "¿Quién puede ayudarme con esto?"),
                .init("I want to ask a question", "❓", "Quiero hacer una pregunta"),
                .init("I do not understand the options", "🔀", "No entiendo las opciones"),
                .init("Please speak to me directly", "👀", "Háblame directamente, por favor"),
                .init("I want someone with me", "🤝", "Quiero que alguien me acompañe"),
                .init("I agree to this", "✅", "Estoy de acuerdo con esto"),
                .init("I do not agree to this", "🚫", "No estoy de acuerdo con esto")
              ]),
        .init(id: "privacy-boundaries", title: "Privacy and boundaries", icon: "🛡️", group: .support,
              summary: "Set personal boundaries and say how support should be given.", words: [
                .init("Ask before touching me", "✋", "Pregunta antes de tocarme"),
                .init("I need a private conversation", "🔒", "Necesito hablar en privado"),
                .init("Do not share this", "🚫", "No compartas esto"),
                .init("I want the door closed", "🚪", "Quiero que la puerta esté cerrada"),
                .init("I do not want to answer", "🤐", "No quiero responder"),
                .init("I want to say no", "🙅", "Quiero decir que no"),
                .init("Please stop now", "🛑", "Para ahora, por favor"),
                .init("I want to choose who helps me", "🗳️", "Quiero elegir quién me ayuda"),
                .init("I need some space", "↔️", "Necesito espacio"),
                .init("I will tell you when I am ready", "⏱️", "Te avisaré cuando pueda continuar"),
                .init("I want this person to leave", "🚶", "Quiero que esta persona se vaya"),
                .init("I want help without being touched", "🤝", "Quiero ayuda sin que me toquen")
              ]),
        .init(id: "rights-choices", title: "Rights and choices", icon: "🗣️", group: .support,
              summary: "Consent, decisions, information, and personal boundaries.", words: [
                .init("I decide", "🗳️", "Yo decido"),
                .init("Ask me first", "🙋", "Pregúntame primero"),
                .init("I need more information", "ℹ️", "Necesito más información"),
                .init("I do not consent", "🚫", "No doy mi consentimiento"),
                .init("I can change my mind", "🔄", "Puedo cambiar de opinión"),
                .init("Please speak to me directly", "💬", "Háblame directamente, por favor"),
                .init("I want someone with me", "🤝", "Quiero que alguien me acompañe"),
                .init("I want to be alone", "🧘", "Quiero estar a solas"),
                .init("I need time to answer", "⏳", "Necesito tiempo para responder"),
                .init("Please respect my choice", "✅", "Respeta mi decisión, por favor"),
                .init("I want a different option", "🔀", "Quiero otra opción"),
                .init("Stop now", "🛑", "Para ahora")
              ])
    ]

    static func page(id: String) -> VocabularyLibraryPage? {
        pages.first { $0.id == id }
    }
}
