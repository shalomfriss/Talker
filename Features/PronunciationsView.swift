import SwiftUI

private struct PronunciationEditorTarget: Identifiable {
    let id: UUID
    let rule: PronunciationRule?

    init(rule: PronunciationRule?) {
        self.id = rule?.id ?? UUID()
        self.rule = rule
    }
}

struct PronunciationsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var editor: PronunciationEditorTarget?

    var body: some View {
        Form {
            Section {
                Text("Keep the written message the same while changing what the system voice says. Corrections apply to spoken words and phrases in the selected language.")
                    .foregroundStyle(.secondary)
            }
            Section("English") {
                ForEach(store.settings.pronunciationRules.filter { $0.language == "en" }) { rule in
                    ruleRow(rule)
                }
            }
            Section("Español") {
                ForEach(store.settings.pronunciationRules.filter { $0.language == "es" }) { rule in
                    ruleRow(rule)
                }
            }
        }
        .navigationTitle("Pronunciations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add correction", systemImage: "plus") { editor = .init(rule: nil) }
                    .accessibilityIdentifier("add-pronunciation")
            }
        }
        .sheet(item: $editor) { target in
            PronunciationRuleEditorView(rule: target.rule)
        }
        .onChange(of: store.activeProfileID) { _, _ in editor = nil }
    }

    private func ruleRow(_ rule: PronunciationRule) -> some View {
        HStack(spacing: 12) {
            Button {
                editor = .init(rule: rule)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.written)
                        .font(.headline)
                    Text("Sounds like: \(rule.spoken)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button("Try \(rule.written)", systemImage: "speaker.wave.2") {
                store.speak(rule.written, language: rule.language)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("try-pronunciation-\(rule.id.uuidString)")
        }
        .swipeActions {
            Button("Delete", role: .destructive) { store.deletePronunciationRule(rule) }
        }
        .contextMenu {
            Button("Edit correction", systemImage: "pencil") { editor = .init(rule: rule) }
            Button("Delete correction", systemImage: "trash", role: .destructive) {
                store.deletePronunciationRule(rule)
            }
        }
    }
}

private struct PronunciationRuleEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var written: String
    @State private var spoken: String
    @State private var language: String
    @State private var errorText = ""

    let rule: PronunciationRule?

    init(rule: PronunciationRule?) {
        self.rule = rule
        _written = State(initialValue: rule?.written ?? "")
        _spoken = State(initialValue: rule?.spoken ?? "")
        _language = State(initialValue: rule?.language ?? "en")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Correction") {
                    TextField("Written word or phrase", text: $written)
                        .accessibilityIdentifier("pronunciation-written")
                    TextField("Say it as", text: $spoken)
                        .accessibilityIdentifier("pronunciation-spoken")
                    Picker("Language", selection: $language) {
                        Text("English").tag("en")
                        Text("Español").tag("es")
                    }
                    Text("Example: write AAC and say A A C. Messages still show and share the original text.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !errorText.isEmpty {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle(rule == nil ? "Add pronunciation" : "Edit pronunciation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = PronunciationRule(id: rule?.id ?? UUID(), written: written,
                                                        spoken: spoken, language: language)
                        if store.savePronunciationRule(updated) { dismiss() }
                        else { errorText = "Enter a unique word or phrase and a spoken version for this language." }
                    }
                    .disabled(written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: store.activeProfileID) { _, _ in dismiss() }
    }
}
