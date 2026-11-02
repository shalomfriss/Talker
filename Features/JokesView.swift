import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct JokesView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var showingAdd = false
    @State private var editingJoke: Joke?

    var body: some View {
        List {
            if store.jokes.isEmpty {
                ContentUnavailableView {
                    Label("No jokes yet", systemImage: "theatermasks")
                } description: {
                    Text("Create a setup and punch line to share at your own pace.")
                } actions: {
                    Button("Add joke") { showingAdd = true }
                }
            } else {
                ForEach(store.jokes) { joke in
                    NavigationLink {
                        JokeSessionView(jokeID: joke.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(joke.title).font(.headline)
                            Text(joke.setup).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                        }
                        .frame(minHeight: 55, alignment: .leading)
                    }
                    .accessibilityIdentifier("joke-\(joke.id.uuidString)")
                    .swipeActions(edge: .leading) {
                        Button("Edit", systemImage: "pencil") { editingJoke = joke }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.deleteJoke(joke) }
                    }
                    .contextMenu {
                        Button("Edit joke", systemImage: "pencil") { editingJoke = joke }
                        Button("Delete joke", systemImage: "trash", role: .destructive) { store.deleteJoke(joke) }
                    }
                }
            }
        }
        .navigationTitle("Jokes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add joke", systemImage: "plus") { showingAdd = true }
                    .accessibilityIdentifier("add-joke")
            }
        }
        .sheet(isPresented: $showingAdd) { JokeEditorView() }
        .sheet(item: $editingJoke) { JokeEditorView(joke: $0) }
        .onChange(of: store.activeProfileID) { _, _ in
            showingAdd = false
            editingJoke = nil
        }
    }
}

private struct JokeEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    private let joke: Joke?
    @State private var title: String
    @State private var setup: String
    @State private var punchline: String
    @State private var soundEffectData: Data?
    @State private var showingAudioImporter = false
    @State private var errorMessage = ""

    init(joke: Joke? = nil) {
        self.joke = joke
        _title = State(initialValue: joke?.title ?? "")
        _setup = State(initialValue: joke?.setup ?? "")
        _punchline = State(initialValue: joke?.punchline ?? "")
        _soundEffectData = State(initialValue: joke?.soundEffectData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Joke") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("joke-title")
                    TextField("Setup", text: $setup, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("joke-setup")
                    TextField("Punch line", text: $punchline, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("joke-punchline")
                }
                Section("Sound effect (optional)") {
                    Button(soundEffectData == nil ? "Import an audio effect" : "Replace audio effect",
                           systemImage: "waveform") { showingAudioImporter = true }
                    if soundEffectData != nil {
                        Button("Remove audio effect", role: .destructive) { soundEffectData = nil }
                    }
                    Text("After the punch line, a separate large button plays this effect. Choose an audio file up to 5 MB.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(joke == nil ? "New joke" : "Edit joke")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || setup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || punchline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("save-joke")
                }
            }
            .fileImporter(isPresented: $showingAudioImporter, allowedContentTypes: [.audio]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    guard data.count <= 5_000_000, (try? AVAudioPlayer(data: data)) != nil else {
                        errorMessage = "Choose a playable audio file no larger than 5 MB."
                        return
                    }
                    soundEffectData = data
                    errorMessage = ""
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func save() {
        let saved: Bool
        if let joke {
            var updated = joke
            updated.title = title
            updated.setup = setup
            updated.punchline = punchline
            updated.soundEffectData = soundEffectData
            saved = store.updateJoke(updated)
        } else {
            saved = store.addJoke(title: title, setup: setup, punchline: punchline,
                                  soundEffectData: soundEffectData)
        }
        if saved { dismiss() }
        else { errorMessage = "Use a unique title and complete both lines." }
    }
}

private struct PartnerLine: Identifiable {
    let id = UUID()
    let text: String
}

private struct JokeSessionView: View {
    @EnvironmentObject private var store: CommunicationStore
    let jokeID: UUID
    @State private var stage: Stage = .setup
    @State private var setupShared = false
    @State private var partnerLine: PartnerLine?

    private enum Stage {
        case setup, punchline, finished
    }

    private var joke: Joke? { store.jokes.first { $0.id == jokeID } }

    var body: some View {
        ScrollView {
            if let joke {
                VStack(alignment: .leading, spacing: 22) {
                    Text(joke.title).font(.largeTitle.bold())
                    Text("Share the setup, pause for a response, then share the punch line.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(stage == .setup ? "Setup" : stage == .punchline ? "Punch line" : "Joke complete")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(stage == .setup ? joke.setup : joke.punchline)
                            .font(.system(.title, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                            .accessibilityIdentifier("joke-current-line")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

                    if stage == .setup {
                        Button("Speak setup", systemImage: "speaker.wave.2.fill") {
                            store.speak(joke.setup, saveToHistory: true)
                            setupShared = true
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("joke-speak-setup")
                        Button("Show setup to partner", systemImage: "rectangle.expand.vertical") {
                            partnerLine = PartnerLine(text: joke.setup)
                            setupShared = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("joke-show-setup")
                        if setupShared {
                            Button("Continue to punch line", systemImage: "arrow.right") {
                                store.stopSpeaking()
                                stage = .punchline
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("joke-next")
                        }
                    } else if stage == .punchline {
                        Text("Pause for your listener before sharing the punch line.")
                            .foregroundStyle(.secondary)
                        Button("Speak punch line", systemImage: "speaker.wave.2.fill") {
                            store.speak(joke.punchline, saveToHistory: true)
                            stage = .finished
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("joke-speak-punchline")
                        Button("Show punch line to partner", systemImage: "rectangle.expand.vertical") {
                            partnerLine = PartnerLine(text: joke.punchline)
                            stage = .finished
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("joke-show-punchline")
                    } else {
                        if joke.soundEffectData != nil {
                            Button("Play sound effect", systemImage: "waveform") {
                                store.playJokeSoundEffect(joke)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("joke-play-effect")
                        }
                        Button("Tell it again", systemImage: "arrow.counterclockwise") {
                            store.stopSpeaking()
                            stage = .setup
                            setupShared = false
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("joke-repeat")
                        ShareLink(item: joke.setup + "\n" + joke.punchline) {
                            Label("Share joke text", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                    Button("Stop speaking", systemImage: "stop.fill") { store.stopSpeaking() }
                        .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(20)
            } else {
                ContentUnavailableView("Joke unavailable", systemImage: "theatermasks",
                                       description: Text("This joke is not in the current profile."))
            }
        }
        .navigationTitle("Tell a joke")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $partnerLine) { line in
            MessageDisplayView(message: line.text)
        }
        .onChange(of: store.activeProfileID) { _, _ in
            store.stopSpeaking()
            stage = .setup
            setupShared = false
            partnerLine = nil
        }
    }
}
