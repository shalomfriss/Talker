import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: BackupDocument?
    @State private var backupError: String?
    @State private var pendingBackup: PendingBackupImport?
    @State private var showingProfiles = false
    @State private var showingPassport = false
    @State private var showingBoardOnlySetup = false
    @State private var printableBoardsDocument: PrintableBoardsDocument?
    @State private var personalVoiceStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var isAdjustingSettings = false

    private var voices: [AVSpeechSynthesisVoice] {
        let language = store.settings.communicationLanguage
        return availableVoices
            .filter { $0.language.hasPrefix(language) }
            .sorted { $0.name < $1.name }
    }

    private var switchAccessSection: some View {
        Section("Switch access") {
            Toggle("Scan the communication board", isOn: $store.settings.scanEnabled)
            if store.settings.scanEnabled {
                Picker("Scanning mode", selection: $store.settings.scanMode) {
                    Text("Auto").tag(ScanMode.automatic)
                    Text("Step").tag(ScanMode.step)
                }
                .accessibilityIdentifier("scanning-mode")
                Picker("Scanning pattern", selection: $store.settings.scanPattern) {
                    Text("One at a time").tag(ScanPattern.sequential)
                    Text("Row then button").tag(ScanPattern.rowColumn)
                    Text("Column then button").tag(ScanPattern.columnRow)
                }
                .accessibilityIdentifier("scanning-pattern")
                Picker("Scan cue", selection: $store.settings.scanCueMode) {
                    Text("Off").tag(ScanCueMode.off)
                    Text("Spoken preview").tag(ScanCueMode.spoken)
                    Text("Blip").tag(ScanCueMode.blip)
                    Text("Woodblock").tag(ScanCueMode.woodblock)
                }
                .accessibilityIdentifier("scan-cue-mode")
                if store.settings.scanCueMode == .spoken {
                    Picker("Cue voice", selection: $store.settings.scanCueVoiceIdentifier) {
                        Text("System voice").tag("")
                        ForEach(voices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                        }
                    }
                    .accessibilityIdentifier("scan-cue-voice")
                    Text("The highlighted choice is spoken before selection. Cues use a separate, quicker voice and stop when a message speaks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if store.settings.scanCueMode != .off {
                    Text("A short sound plays when the highlight moves. Use this when you want an audio signal without hearing each label.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if store.settings.scanMode == .automatic {
                    VStack(alignment: .leading) {
                        Text("Seconds per choice: \(store.settings.scanInterval, specifier: "%.1f")")
                        Slider(value: $store.settings.scanInterval, in: 0.7...3.0, step: 0.1,
                               onEditingChanged: settingsAdjustmentChanged)
                            .accessibilityLabel("Scanning speed")
                    }
                }
                Text(store.settings.scanMode == .automatic
                     ? "The highlight moves automatically. Select by touching Select or using a keyboard switch that sends Space. N moves to the next choice."
                     : "The highlight moves only when you touch Next or use a keyboard switch that sends N. Touch Select or send Space to choose. No scan timer runs in Step mode.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Choose one button at a time, or choose a row or column first. iOS Switch Control can also scan the app’s buttons directly. Physical switch mappings still need device testing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Communicator") {
                    LabeledContent("Current profile", value: store.activeProfileName)
                    Button("Manage profiles", systemImage: "person.2") { showingProfiles = true }
                    Button("My communication passport", systemImage: "person.text.rectangle") { showingPassport = true }
                }
                Section("Board-only mode") {
                    Button("Set a PIN and start board-only mode", systemImage: "lock.rectangle") {
                        showingBoardOnlySetup = true
                    }
                    .accessibilityIdentifier("board-only-setup")
                    Text("This mode keeps the Speak board, typing, quick choices, and photo scenes available. It hides editing controls and other tabs. Use the PIN, or device authentication when available, to leave.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Choice board editing") {
                    Toggle("Lock choice-board editing", isOn: $store.settings.choiceBoardEditingLocked)
                        .accessibilityIdentifier("choice-board-edit-lock")
                    Text("When locked, you can still use saved boards and offer quick choices. Creating, changing, deleting, and saving boards are paused. Turn this off here to edit again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Quick replies") {
                    NavigationLink {
                        QuickResponsesEditorView(responses: store.settings.quickResponses)
                    } label: {
                        Label("Edit quick replies", systemImage: "text.bubble")
                    }
                    .accessibilityIdentifier("edit-quick-replies")
                    Text("Choose up to six one-tap phrases. Each communicator has their own replies.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Vocabulary visibility") {
                    Toggle("Dimmed buttons can be selected", isOn: $store.settings.dimmedButtonsActive)
                        .accessibilityIdentifier("dimmed-buttons-active")
                    VStack(alignment: .leading) {
                        Text("Dimmed button opacity: \(Int(store.settings.dimmedButtonOpacity * 100))%")
                        Slider(value: $store.settings.dimmedButtonOpacity, in: 0.15...0.8, step: 0.05,
                               onEditingChanged: settingsAdjustmentChanged)
                            .accessibilityLabel("Dimmed button opacity")
                            .accessibilityIdentifier("dimmed-button-opacity")
                    }
                    Text("Edit a word to show, dim, or hide its picture button. Hidden buttons keep their position in the grid.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Vocabulary growth") {
                    Picker("Word stage", selection: $store.settings.progressiveVocabularyStage) {
                        ForEach(VocabularyStage.allCases) { stage in
                            Text(stage.title).tag(stage)
                        }
                    }
                    .accessibilityIdentifier("vocabulary-stage")
                    Text("Start and Grow reveal starter words in steps without moving their board positions. Personal buttons, favorites, and quick words remain available. Explore all on Speak temporarily shows the full board; search can always find a word. This choice stays with the current profile and its backup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Recent picture words") {
                    Toggle("Keep a Recent board", isOn: $store.settings.recentPictureWordsEnabled)
                        .accessibilityIdentifier("recent-picture-words-setting")
                    Toggle("Highlight recently used words on boards", isOn: $store.settings.highlightRecentPictureWords)
                        .accessibilityIdentifier("recent-word-highlights-setting")
                    Text("Both choices are off by default. The Recent board gathers the last 12 distinct picture words you choose. Highlighting gently outlines the three most recent words where they already sit on their boards. Either choice can keep the local list updated; turning both off stops new entries. Clear the list below to remove saved entries. The choices and list stay with this profile and its backup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !store.settings.recentPictureWordIDs.isEmpty {
                        Button("Clear recent picture words", role: .destructive) {
                            store.clearRecentPictureWords()
                        }
                        .accessibilityIdentifier("clear-recent-picture-words")
                    }
                }
                Section("Time-of-day picture words") {
                    Toggle("Highlight words often used at this time", isOn: $store.settings.highlightWordsForTimeOfDay)
                        .accessibilityIdentifier("time-of-day-highlights-setting")
                    Text("When on, picture words chosen repeatedly in the morning, afternoon, evening, or night gain a gentle outline at that time. Up to two words per board are outlined in their usual positions. Learning stays with this profile and its backup. Turn this off to stop learning; clear below to erase the pattern.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !store.settings.timeOfDayWordUses.isEmpty {
                        Button("Clear time-of-day learning", role: .destructive) {
                            store.clearTimeOfDayWordUses()
                        }
                        .accessibilityIdentifier("clear-time-of-day-learning")
                    }
                }
                Section("Picture word colors") {
                    Picker("Color scheme", selection: $store.settings.grammarColorScheme) {
                        ForEach(GrammarColorScheme.allCases) { scheme in
                            Text(scheme.title).tag(scheme)
                        }
                    }
                    .accessibilityIdentifier("grammar-color-scheme")
                    Text("Grammar colors group people, actions, little words, describing words, things, and places. A button’s personal colors take priority. High contrast uses black and white.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                switchAccessSection
                Section("Board language") {
                    Picker("Communication language", selection: $store.settings.communicationLanguage) {
                        Text("English").tag("en")
                        Text("Español").tag("es")
                    }
                    Text("Starter picture words are available in English and Spanish. Edit a personal button to add its Spanish label and speech. App menus, category names, choice-board titles, saved phrases, jokes, routines, and stories remain in the language they were written.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Speech") {
                    Button(store.settings.speechMuted ? "Unmute speech" : "Mute speech",
                           systemImage: store.settings.speechMuted ? "speaker.wave.2.fill" : "speaker.slash.fill") {
                        store.settings.speechMuted.toggle()
                    }
                    .accessibilityValue(store.settings.speechMuted ? "Muted" : "On")
                    .accessibilityIdentifier("settings-speech-mute-button")
                    VStack(alignment: .leading) {
                        Text("App speech volume: \(Int(store.settings.speechVolume * 100))%")
                        Slider(value: $store.settings.speechVolume, in: 0.1...1.0, step: 0.05,
                               onEditingChanged: settingsAdjustmentChanged)
                            .accessibilityLabel("App speech volume")
                            .accessibilityIdentifier("settings-speech-volume")
                    }
                    Text("Open the speech sound button on Speak to adjust volume quickly. Device volume buttons still control the overall sound level.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Voice", selection: $store.settings.voiceIdentifier) {
                        Text("System default").tag("")
                        ForEach(voices, id: \.identifier) { voice in
                            Text("\(voice.voiceTraits.contains(.isPersonalVoice) ? "Personal Voice: " : "")\(voice.name) (\(voice.language))")
                                .tag(voice.identifier)
                        }
                    }
                    .accessibilityIdentifier("voice-picker")
                    NavigationLink {
                        PronunciationsView()
                    } label: {
                        Label("Pronunciation corrections", systemImage: "text.bubble")
                    }
                    .accessibilityIdentifier("pronunciations-link")
                    Toggle("Speak each button when tapped", isOn: $store.settings.speakOnTap)
                    Toggle("Start a new picture message after speaking", isOn: $store.settings.autoClearAfterSpeaking)
                        .accessibilityIdentifier("auto-clear-picture-message")
                    Text("The spoken message stays visible so you can repeat it. The next picture word or phrase starts a new message. Undo or changing a word form keeps editing the current message.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Speak typed characters", isOn: $store.settings.speakTypedCharacters)
                    Toggle("Speak completed words", isOn: $store.settings.speakTypedWords)
                    Toggle("Speak completed sentences", isOn: $store.settings.speakTypedSentences)
                    Text("Typing previews speak individual keys added at the end of a message. They are not saved in recent messages.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Voice speed")
                        Slider(value: $store.settings.speechRate, in: 0.35...0.6,
                               onEditingChanged: settingsAdjustmentChanged)
                            .accessibilityLabel("Voice speed")
                    }
                    Button("Try voice", systemImage: "speaker.wave.2") {
                        store.speak(store.settings.communicationLanguage == "es"
                                    ? "Hola. Tengo algo que decir."
                                    : "Hello. I have something to say.")
                    }
                    Button("Stop speaking", systemImage: "stop.fill") { store.stopSpeaking() }
                }
                Section("Personal Voice") {
                    switch personalVoiceStatus {
                    case .notDetermined:
                        Text("If you created a Personal Voice in device Accessibility settings, allow Open Voice to use it for speech. Your voice stays managed by the device.")
                            .foregroundStyle(.secondary)
                        Button("Allow Personal Voice", systemImage: "person.wave.2") {
                            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                                Task { @MainActor in
                                    personalVoiceStatus = status
                                    refreshVoices()
                                }
                            }
                        }
                        .accessibilityIdentifier("personal-voice-request")
                    case .authorized:
                        if voices.contains(where: { $0.voiceTraits.contains(.isPersonalVoice) }) {
                            Text("Your Personal Voice is available in the Voice picker above.")
                        } else {
                            Text("Access is allowed. Create a Personal Voice in device Accessibility settings to add it to the Voice picker.")
                        }
                    case .denied:
                        Text("Personal Voice access is off. You can change it in the device’s Settings for Open Voice.")
                    case .unsupported:
                        Text("Personal Voice is not supported on this device.")
                    @unknown default:
                        Text("Personal Voice is unavailable right now.")
                    }
                }
                Section("Phone and video calls") {
                    NavigationLink {
                        CallAudioView()
                    } label: {
                        Label("Call audio", systemImage: "phone.arrow.up.right")
                    }
                    .accessibilityIdentifier("call-audio-link")
                    Text("Choose whether Open Voice sound can be heard in a supported call. The device asks for permission before adding audio.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Get attention") {
                    Text("The bell on Speak immediately says this message and shows it in large type. It does not add words to your message.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("English attention message", text: $store.settings.attentionMessageEnglish,
                              axis: .vertical)
                    TextField("Spanish attention message", text: $store.settings.attentionMessageSpanish,
                              axis: .vertical)
                    Text("Leave either field blank to use its default phrase.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Add a haptic alert", isOn: $store.settings.attentionHaptics)
                    Button("Try attention message", systemImage: "bell.fill") {
                        store.speak(store.settings.attentionMessage)
                    }
                }
                Section("Access") {
                    Toggle("Show urgent communication bar", isOn: $store.settings.showUrgentBar)
                        .accessibilityIdentifier("show-urgent-bar-setting")
                    Text("Keep the first bedside card available across the main app. It speaks immediately without changing your message. More opens all bedside cards. Edit the first card in Bedside communication to choose its words.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Home board", selection: $store.settings.homeBoardName) {
                        ForEach(store.visibleBoards, id: \.self) { board in
                            Text(board).tag(board)
                        }
                    }
                    .accessibilityIdentifier("home-board-setting")
                    Text("Choose the first picture board for this profile. Home buttons return here, and the choice stays in local backups.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Letter order", selection: $store.settings.letterOrder) {
                        ForEach(LetterOrder.allCases, id: \.self) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    NavigationLink("Edit custom letter order") {
                        CustomLetterOrderView()
                    }
                    .accessibilityIdentifier("edit-custom-letter-order")
                    Text("The large-key keyboard, speech-cue board, and printable cues share this order. QWERTY uses three rows; Spanish adds Ñ. Custom sequences are saved separately for English and Spanish in this profile. Switching the order keeps your message.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Grouped keyboard keys", isOn: Binding(
                        get: { store.settings.groupedKeyboardKeys },
                        set: { store.settings.selectGroupedKeyboardKeys($0) }
                    ))
                    Text("Choose one of six large key groups, then choose an enlarged letter or symbol. The message and cursor stay in place.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Ten Key keyboard", isOn: Binding(
                        get: { store.settings.tenKeyKeyboardEnabled },
                        set: { store.settings.selectTenKeyKeyboard($0) }
                    ))
                    .accessibilityIdentifier("ten-key-keyboard-setting")
                    Text("Six large letter groups and four large action keys make a ten-target keyboard. Choose a group, then choose a letter; it returns to the ten targets after each letter. Numbers and punctuation are under 123.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Grouped picture buttons", isOn: $store.settings.groupedPictureBoard)
                        .accessibilityIdentifier("grouped-picture-board-setting")
                    Text("Choose one of six large groups, then a larger picture button. The full grid remains available during search and switch scanning. Groups keep the current button order and stay with this profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Keep Core beside topic boards", isOn: $store.settings.twoBoardsEnabled)
                        .accessibilityIdentifier("two-boards-setting")
                    Text("Core stays beside a topic board on iPad, or above it on iPhone. Search and switch scanning use one board at a time. This choice stays with the profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                Picker("Default picture button size", selection: $store.settings.tileSize) {
                        Text("Compact").tag(TileSize.compact)
                        Text("Standard").tag(TileSize.standard)
                        Text("Large").tag(TileSize.large)
                    }
                    Toggle("High contrast", isOn: $store.settings.highContrast)
                    Toggle("Confirm before adding a word", isOn: $store.settings.confirmSelection)
                    Toggle("Suggest next picture words", isOn: $store.settings.showBoardSuggestions)
                    Text("When a picture message has words, matching buttons and board tabs are outlined in place. Suggestions use saved phrases, card phrases, and recent messages only when message history is on. Hints can also be switched from Speak.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Hold picture tiles to select", selection: $store.settings.wordHoldDuration) {
                        Text("Off").tag(0.0)
                        Text("0.5 seconds").tag(0.5)
                        Text("1 second").tag(1.0)
                        Text("1.5 seconds").tag(1.5)
                    }
                    .accessibilityIdentifier("picture-hold-duration")
                    Picker("Pointer dwell to select", selection: $store.settings.pointerDwellDuration) {
                        Text("Off").tag(0.0)
                        Text("0.8 seconds").tag(0.8)
                        Text("1.2 seconds").tag(1.2)
                        Text("2 seconds").tag(2.0)
                        Text("3 seconds").tag(3.0)
                    }
                    .accessibilityIdentifier("pointer-dwell-duration")
                    Picker("Ignore repeated word taps", selection: $store.settings.repeatFilterInterval) {
                        Text("Off").tag(0.0)
                        Text("0.4 seconds").tag(0.4)
                        Text("0.8 seconds").tag(0.8)
                        Text("2 seconds").tag(2.0)
                    }
                    Text("Pointer dwell selects a picture button, choice tile, or large-key keyboard target after the pointer stays there. Moving away cancels it; moving within a target restarts its timer. A progress ring shows the wait. Touch and VoiceOver still work normally. Hold applies to picture tiles on Speak, scenes, and choice boards. Repeat protection applies to the same word; a different word responds immediately.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Your data") {
                    Text("The current profile’s words, photos, scenes, recordings, phrases, jokes, choice boards, routines, weekly plan, feelings log, and communication passport are stored on this device. No account is needed.")
                        .foregroundStyle(.secondary)
                    Toggle("Save spoken messages on this device", isOn: $store.settings.saveHistory)
                    Text("Off by default. When on, the most recent 50 complete messages appear under Phrases. You can pause new entries from Speak; the pause stays with this profile. Existing entries remain until you delete them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !store.history.isEmpty {
                        Button("Delete all recent messages", role: .destructive) { store.clearHistory() }
                    }
                    Toggle("Learn word and sentence suggestions from spoken messages", isOn: $store.settings.learnPrediction)
                        .accessibilityIdentifier("learn-prediction-toggle")
                    Text("Off by default. When on, short word patterns from messages you speak are saved on this device for this profile, even if message history is off. Repeated patterns can complete short sentences. The Speak pause stops new learning. Turning learning off keeps existing patterns until you clear them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !store.learnedPrediction.entries.isEmpty {
                        Button("Clear learned suggestions", role: .destructive) { store.clearLearnedPrediction() }
                            .accessibilityIdentifier("clear-learned-prediction")
                    }
                    Toggle("Keep a private feelings log", isOn: $store.settings.saveFeelingsLog)
                    Text("Off by default. When on, use Save check-in in How I feel. Speaking and sharing do not save a check-in. Turning this off keeps existing entries until you delete them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !store.feelingsLog.isEmpty {
                        NavigationLink {
                            FeelingsHistoryView()
                        } label: {
                            Label("Review saved check-ins", systemImage: "heart.text.square")
                        }
                    }
                    NavigationLink {
                        LocalBackupsView()
                    } label: {
                        Label("Local backups", systemImage: "archivebox")
                    }
                    .accessibilityIdentifier("open-local-backups")
                    Button("Export current profile", systemImage: "square.and.arrow.up") {
                        do {
                            exportDocument = BackupDocument(data: try store.backupData())
                            showingExporter = true
                        } catch { backupError = error.localizedDescription }
                    }
                    Button("Import into current profile", systemImage: "square.and.arrow.down") { showingImporter = true }
                }
                Section("Printable communication boards") {
                    Text("Create a paper copy of this profile’s boards in the selected board language for times when the device is unavailable. Your photos and linked board page numbers are included.")
                        .foregroundStyle(.secondary)
                    Button("Preview printable boards", systemImage: "doc.richtext") {
                        let data = PrintableBoardPDF.makeData(
                            profileName: store.activeProfileName,
                            categories: store.categories,
                            items: store.items,
                            choiceBoards: store.choiceBoards,
                            language: store.settings.communicationLanguage,
                            wordTranslations: store.wordTranslations)
                        printableBoardsDocument = PrintableBoardsDocument(data: data)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { refreshVoices() }
            .onDisappear { settingsAdjustmentChanged(false) }
            .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
                refreshVoices()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshVoices() }
                else {
                    settingsAdjustmentChanged(false)
                    store.flushPersistence()
                }
            }
            .onChange(of: store.settings.communicationLanguage) { _, _ in
                store.settings.voiceIdentifier = ""
                store.settings.scanCueVoiceIdentifier = ""
            }
            .sheet(isPresented: $showingProfiles) { ProfileManagerView() }
            .sheet(isPresented: $showingPassport) { CommunicationPassportView() }
            .sheet(isPresented: $showingBoardOnlySetup) { BoardOnlySetupView() }
            .sheet(item: $pendingBackup) { backup in
                BackupImportView(backup: backup)
                    .environmentObject(store)
            }
            .sheet(item: $printableBoardsDocument) { document in
                PrintableBoardsPreview(data: document.data)
            }
            .fileExporter(isPresented: $showingExporter, document: exportDocument,
                          contentType: .json, defaultFilename: "open-voice-backup") { result in
                if case .failure(let error) = result { backupError = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    let preview = try JSONDecoder().decode(StoredData.self, from: data)
                    guard !preview.items.isEmpty else { throw BackupError.emptyVocabulary }
                    pendingBackup = PendingBackupImport(data: data, preview: preview)
                } catch { backupError = error.localizedDescription }
            }
            .alert("File error", isPresented: Binding(
                get: { backupError != nil }, set: { if !$0 { backupError = nil } }
            )) {
                Button("OK") { backupError = nil }
            } message: {
                Text(backupError ?? "Unknown error")
            }
        }
    }

    private func settingsAdjustmentChanged(_ editing: Bool) {
        guard editing != isAdjustingSettings else { return }
        isAdjustingSettings = editing
        if editing { store.beginSettingsAdjustment() }
        else { store.endSettingsAdjustment() }
    }

    private func refreshVoices() {
        personalVoiceStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
    }
}

private struct PrintableBoardsDocument: Identifiable {
    let id = UUID()
    let data: Data
}

struct CustomLetterOrderView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var language = "en"

    private var letters: [String] {
        AppSettings.cleanedLetters(store.settings.customLetterOrders[language] ?? [], language: language)
    }

    var body: some View {
        List {
            Section {
                Picker("Language", selection: $language) {
                    Text("English").tag("en")
                    Text("Español").tag("es")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("custom-letter-language")
                Text("Move a letter with the arrows. The custom order applies to the large-key keyboard, speech cues, and printed cues for this profile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("A–Z") { usePreset(.alphabetical) }
                    Spacer()
                    Button("Common first") { usePreset(.commonFirst) }
                    Spacer()
                    Button("QWERTY") { usePreset(.qwerty) }
                }
                .buttonStyle(.bordered)
            }
            Section("Letter sequence") {
                ForEach(Array(letters.enumerated()), id: \.element) { index, letter in
                    HStack {
                        Text("\(index + 1)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .leading)
                        Text(letter)
                            .font(.title3.bold())
                        Spacer()
                        Button("Move \(letter) up", systemImage: "arrow.up") {
                            move(letter, by: -1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(index == 0)
                        .accessibilityIdentifier("custom-letter-up-\(letter)")
                        Button("Move \(letter) down", systemImage: "arrow.down") {
                            move(letter, by: 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(index == letters.count - 1)
                        .accessibilityIdentifier("custom-letter-down-\(letter)")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Custom letter order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear { language = store.settings.communicationLanguage }
    }

    private func usePreset(_ order: LetterOrder) {
        store.settings.setCustomLetters(order.letters(language: language), language: language)
    }

    private func move(_ letter: String, by offset: Int) {
        var updated = letters
        guard let index = updated.firstIndex(of: letter),
              updated.indices.contains(index + offset) else { return }
        updated.swapAt(index, index + offset)
        store.settings.setCustomLetters(updated, language: language)
    }
}
