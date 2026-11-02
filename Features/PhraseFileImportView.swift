import SwiftUI

struct PendingPhraseFileImport: Identifiable {
    let id = UUID()
    let profileID: UUID
    let collection: PhraseCollectionTransfer
}

struct PhraseFileImportView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let pending: PendingPhraseFileImport
    let onImport: (PhraseCollectionImportResult) -> Void

    private var counts: (new: Int, matching: Int, repeated: Int) {
        pending.collection.counts(against: store.phrases)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Phrase file") {
                    LabeledContent("Collection", value: pending.collection.name)
                    LabeledContent("Phrases", value: "\(pending.collection.phrases.count)")
                    LabeledContent("New", value: "\(counts.new)")
                    LabeledContent("Matching", value: "\(counts.matching)")
                    if counts.repeated > 0 {
                        Text("\(counts.repeated) repeated phrases in this file will be skipped.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Preview") {
                    ForEach(Array(pending.collection.phrases.prefix(30).enumerated()), id: \.offset) { _, phrase in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(phrase.displayLabel).font(.headline)
                            if phrase.displayLabel != phrase.text { Text(phrase.text) }
                            if let folder = phrase.folder {
                                Text(folder).font(.caption).foregroundStyle(.secondary)
                            }
                            if let languageCode = phrase.languageCode {
                                Text(PhraseLanguage.title(for: languageCode))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if let action = phrase.tapActionOverride {
                                Text("Tap: \(action.title)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if pending.collection.phrases.count > 30 {
                        Text("Showing the first 30 phrases.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Add missing phrases", systemImage: "plus") {
                        importCollection(.addMissing)
                    }
                    .disabled(counts.new == 0)
                    .accessibilityIdentifier("phrase-file-add-missing")
                    Button("Add and update matching phrases", systemImage: "arrow.triangle.2.circlepath") {
                        importCollection(.updateMatching)
                    }
                    .disabled(counts.new + counts.matching == 0)
                    .accessibilityIdentifier("phrase-file-update-matching")
                } footer: {
                    Text("Updating keeps each matching phrase's place and identity, and replaces its label, folder, shortcut, picture, color, recording, spoken language, and tap action. Other profile content stays in place.")
                }
            }
            .navigationTitle("Import phrases")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: store.activeProfileID) { _, _ in dismiss() }
        }
    }

    private func importCollection(_ mode: PhraseCollectionMergeMode) {
        guard store.activeProfileID == pending.profileID else { dismiss(); return }
        let result = store.importPhraseCollection(pending.collection, mode: mode)
        onImport(result)
        dismiss()
    }
}
