import SwiftUI

struct SpeechCueBoardView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var mode: CueMode = .letters
    @State private var letterCue = ""
    @State private var selectedTopicID: UUID?
    @State private var showingDisplay = false
    @State private var printableCues: PDFPreviewPayload?
    @State private var partnerSession = PartnerSpellingSession(language: "en")
    @State private var partnerSignal: String?
    @State private var showingClearPartnerMessage = false

    private enum CueMode: String, CaseIterable {
        case letters = "Letters"
        case topics = "Topics"
        case partner = "Partner"
    }

    private var currentCue: String {
        switch mode {
        case .letters: letterCue.trimmingCharacters(in: .whitespacesAndNewlines)
        case .topics: store.speechTopics.first(where: { $0.id == selectedTopicID })?.text ?? ""
        case .partner: partnerSession.message.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: sizeClass == .regular ? 8 : 6)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Give a listener a clue while using your own speech, or use the voice and large display.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Cue board", selection: $mode) {
                    ForEach(CueMode.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Button("Printable cue boards", systemImage: "printer") {
                    printableCues = PDFPreviewPayload(data: PrintableSpeechCuePDF.makeData(
                        profileName: store.activeProfileName,
                        letters: store.settings.orderedLetters(language: store.settings.communicationLanguage),
                        language: store.settings.communicationLanguage,
                        topics: store.speechTopics))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("speech-cue-printable")

                cueDisplay

                if mode == .letters {
                    letterBoard
                } else if mode == .topics {
                    topicBoard
                } else {
                    partnerBoard
                }
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            if mode == .partner {
                partnerScanControls
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
            }
        }
        .navigationTitle("Speech cues")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDisplay) {
            MessageDisplayView(message: currentCue)
                .environmentObject(store)
        }
        .sheet(item: $printableCues) { payload in
            PrintableBoardsPreview(data: payload.data, title: "Printable cue boards",
                                   filename: "Open Voice Speech Cues")
        }
        .confirmationDialog("Start a new spelled message?", isPresented: $showingClearPartnerMessage) {
            Button("Start again", role: .destructive) {
                partnerSignal = nil
                partnerSession.startAgain()
            }
        }
        .onAppear {
            if partnerSession.language != store.settings.communicationLanguage {
                partnerSession = PartnerSpellingSession(language: store.settings.communicationLanguage)
                partnerSignal = nil
            }
        }
        .onChange(of: store.settings.communicationLanguage) { _, language in
            partnerSession = PartnerSpellingSession(language: language)
            partnerSignal = nil
        }
        .onChange(of: store.activeProfileID) { _, _ in
            letterCue = ""
            selectedTopicID = nil
            showingDisplay = false
            printableCues = nil
            partnerSession = PartnerSpellingSession(language: store.settings.communicationLanguage)
            partnerSignal = nil
            showingClearPartnerMessage = false
        }
    }

    private var cueDisplay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode == .letters ? "Letter clue" : mode == .topics ? "Topic clue" : "Spelled message")
                .font(.headline)
            Text(currentCue.isEmpty ? (mode == .partner ? "Spell with your partner" : "Choose letters or a topic") : currentCue)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                .multilineTextAlignment(.center)
                .foregroundStyle(currentCue.isEmpty ? .secondary : .primary)
                .accessibilityIdentifier("speech-cue-output")
            HStack {
                Button("Show to partner", systemImage: "rectangle.expand.vertical") {
                    showingDisplay = true
                }
                .disabled(currentCue.isEmpty)
                .accessibilityIdentifier("speech-cue-show-partner")
                Button("Speak cue", systemImage: "speaker.wave.2.fill") {
                    store.speak(currentCue, saveToHistory: true)
                }
                .disabled(currentCue.isEmpty)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var letterBoard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("First letters")
                .font(.title2.bold())
            Text("Point to the first letter or spell as much as helps.")
                .foregroundStyle(.secondary)
            Picker("Letter order", selection: $store.settings.letterOrder) {
                ForEach(LetterOrder.allCases, id: \.self) { order in
                    Text(order.title).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("speech-cue-letter-order")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.settings.orderedLetters(language: store.settings.communicationLanguage), id: \.self) { letter in
                    Button(letter) { letterCue.append(letter) }
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("speech-cue-letter-\(letter)")
                }
            }
            Text("Numbers")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<10, id: \.self) { number in
                    Button("\(number)") { letterCue.append(String(number)) }
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .buttonStyle(.bordered)
                }
            }
            HStack {
                Button("Space", systemImage: "space") { letterCue.append(" ") }
                Button("Question", systemImage: "questionmark") { letterCue.append("?") }
                Button("Backspace", systemImage: "delete.left") {
                    if !letterCue.isEmpty { letterCue.removeLast() }
                }
                .disabled(letterCue.isEmpty)
                Button("Clear", systemImage: "xmark.circle") { letterCue = "" }
                    .disabled(letterCue.isEmpty)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var topicBoard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Conversation topics")
                .font(.title2.bold())
            Text("Tap a topic to show and say what you are talking about.")
                .foregroundStyle(.secondary)
            if store.speechTopics.isEmpty {
                Text("Add topics you often discuss.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                         count: sizeClass == .regular ? 3 : 2), spacing: 12) {
                    ForEach(store.speechTopics) { topic in
                        Button {
                            selectedTopicID = topic.id
                            store.speak(topic.text)
                        } label: {
                            Text(topic.text)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 72)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedTopicID == topic.id ? .accentColor : .primary)
                    }
                }
            }
            NavigationLink {
                SpeechTopicEditorView()
            } label: {
                Label("Manage topics", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var partnerBoard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Partner-assisted spelling")
                .font(.title2.bold())
            Text("Agree on yes and no signals. Read the highlighted row or choice aloud, then tap Next for no or Choose for yes. Space, Delete, Wait, Please guess, and numbers are in the scan too.")
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(partnerSession.prompt)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .accessibilityIdentifier("partner-spelling-prompt")
                if partnerSession.phase == .row && partnerSession.rowIndex >= partnerSession.rows.count {
                    Text(partnerSession.currentRow.joined(separator: " · "))
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("partner-spelling-options")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .multilineTextAlignment(.center)
            .padding(12)
            .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))

            if let partnerSignal {
                Text(partnerSignal)
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("partner-spelling-signal")
            }

            Button("Hear prompt", systemImage: "speaker.wave.2") {
                store.speak(partnerSession.prompt, language: store.settings.communicationLanguage)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("partner-spelling-hear")

            if partnerSession.phase == .row {
                VStack(spacing: 8) {
                    ForEach(partnerSession.scanRows.indices, id: \.self) { index in
                        Text(partnerSession.scanRows[index].joined(separator: "   "))
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .minimumScaleFactor(0.7)
                            .background(index == partnerSession.rowIndex ?
                                        Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityLabel("Row \(index + 1), \(partnerSession.scanRows[index].joined(separator: ", "))")
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                                         count: partnerSession.isCommandRow ? 2 : partnerSession.currentRow.count),
                          spacing: 6) {
                    ForEach(partnerSession.currentRow.indices, id: \.self) { index in
                        Text(partnerSession.currentRow[index])
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .minimumScaleFactor(0.7)
                            .background(index == partnerSession.letterIndex ?
                                        Color.accentColor.opacity(0.22) : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                Button("Back to rows", systemImage: "arrow.uturn.backward") {
                    partnerSignal = nil
                    partnerSession.backToRows()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("partner-spelling-back")
            }

            HStack {
                Button("Space", systemImage: "space") {
                    partnerSignal = nil
                    partnerSession.addSpace()
                }
                    .disabled(partnerSession.message.isEmpty || partnerSession.message.last == " ")
                    .accessibilityIdentifier("partner-spelling-space")
                Button("Delete last", systemImage: "delete.left") {
                    partnerSignal = nil
                    partnerSession.deleteLast()
                }
                    .disabled(partnerSession.message.isEmpty)
                    .accessibilityIdentifier("partner-spelling-delete")
                Button("Start again", systemImage: "arrow.counterclockwise") {
                    showingClearPartnerMessage = true
                }
                .disabled(partnerSession.message.isEmpty)
                .accessibilityIdentifier("partner-spelling-clear")
            }
            .buttonStyle(.bordered)
        }
    }

    private var partnerScanControls: some View {
        HStack(spacing: 12) {
            Button("Next · no", systemImage: "arrow.right") {
                partnerSignal = nil
                partnerSession.next()
            }
            .accessibilityIdentifier("partner-spelling-next")
            Button("Choose · yes", systemImage: "checkmark") {
                partnerSignal = partnerSession.choose()
                if let partnerSignal {
                    store.speak(partnerSignal, language: store.settings.communicationLanguage)
                }
            }
            .accessibilityIdentifier("partner-spelling-choose")
        }
        .font(.headline)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: 900)
    }
}
