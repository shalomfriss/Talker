import SwiftUI
import UniformTypeIdentifiers

struct LanguageSampleView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var showingPartnerEntry = false
    @State private var showingFileExporter = false
    @State private var showingCSVFileExporter = false
    @State private var partnerText = ""
    @State private var exportError: String?

    private var orderedEntries: [SpokenMessage] {
        store.history.sorted { $0.date < $1.date }
    }

    private var transcript: String {
        LanguageSampleTranscript.render(entries: store.history, profileName: store.activeProfileName)
    }

    private var csv: String {
        LanguageSampleTranscript.renderCSV(entries: store.history, profileName: store.activeProfileName)
    }

    var body: some View {
        List {
            Section {
                Text("This sample uses only messages saved with History on. It holds up to 50 recent entries. Add partner turns manually if useful, and review the transcript before sharing it.")
                    .foregroundStyle(.secondary)
                if store.settings.saveHistory && !store.settings.historyPaused &&
                    !store.isPrivateConversationActive {
                    Button("Add partner turn", systemImage: "person.badge.plus") {
                        partnerText = ""
                        showingPartnerEntry = true
                    }
                    .accessibilityIdentifier("add-partner-turn")
                }
            }
            Section("Saved entries") {
                ForEach(orderedEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.text).font(.body)
                        Text("\(entry.speaker?.title ?? "Speaker not recorded") · \(entry.inputMode?.title ?? "Input not recorded")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.date, format: .dateTime.year().month().day().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Language sample")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: transcript) {
                        Label("Share transcript text", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("share-language-sample")
                    Button("Save text file", systemImage: "doc.text") {
                        showingFileExporter = true
                    }
                    .accessibilityIdentifier("save-language-sample-file")
                    Button("Save CSV file", systemImage: "tablecells") {
                        showingCSVFileExporter = true
                    }
                    .accessibilityIdentifier("save-language-sample-csv-file")
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("export-language-sample")
                .disabled(store.history.isEmpty)
            }
        }
        .sheet(isPresented: $showingPartnerEntry) {
            NavigationStack {
                Form {
                    TextField("What did the partner say?", text: $partnerText, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("partner-turn-text")
                    Text("This is a manual note. It will be labeled as a partner turn in the transcript and will not teach word prediction.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Partner turn")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingPartnerEntry = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if store.addPartnerTurn(partnerText) { showingPartnerEntry = false }
                        }
                        .disabled(partnerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  partnerText.count > 1_000)
                        .accessibilityIdentifier("save-partner-turn")
                    }
                }
            }
        }
        .fileExporter(isPresented: $showingFileExporter,
                      document: LanguageSampleTextDocument(text: transcript),
                      contentType: .plainText,
                      defaultFilename: "Open Voice language sample") { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .fileExporter(isPresented: $showingCSVFileExporter,
                      document: LanguageSampleTextDocument(text: csv),
                      contentType: .commaSeparatedText,
                      defaultFilename: "Open Voice language sample") { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert("Could not save transcript", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "Try sharing the transcript text instead.")
        }
    }
}

struct LanguageSampleTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
