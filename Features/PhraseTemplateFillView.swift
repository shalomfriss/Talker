import SwiftUI

struct PhraseTemplateFillView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]
    @State private var showingDisplay = false
    @FocusState private var focusedField: String?

    let phrase: SavedPhrase
    var onInsert: ((String) -> Void)? = nil

    private var fields: [String] { PhraseTemplate.fields(in: phrase.text) }
    private var completedText: String? { PhraseTemplate.render(phrase.text, values: values) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Phrase") {
                    Text(phrase.text)
                    Text("Fill each named blank to make this phrase your own.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Fill in") {
                    ForEach(fields, id: \.self) { field in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(field.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Enter \(field)", text: Binding(
                                get: { values[field] ?? "" },
                                set: { values[field] = $0 }
                            ))
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: field)
                            .accessibilityIdentifier("phrase-template-field-\(field)")
                        }
                    }
                }
                Section("Completed phrase") {
                    Text(completedText ?? "Fill every blank to continue.")
                        .font(.title3)
                        .accessibilityIdentifier("phrase-template-preview")
                }
                Section {
                    Button("Speak completed phrase", systemImage: "speaker.wave.2.fill") {
                        guard let completedText else { return }
                        store.speak(completedText, saveToHistory: true,
                                    languageCode: phrase.languageCode)
                        store.recordRecentPhrase(phrase)
                    }
                    .disabled(completedText == nil)
                    Button("Add to current message", systemImage: "text.badge.plus") {
                        guard let completedText else { return }
                        store.appendCompletedPhrase(completedText,
                                                    languageCode: phrase.languageCode)
                        store.recordRecentPhrase(phrase)
                        dismiss()
                    }
                    .disabled(completedText == nil)
                    if let onInsert {
                        Button("Insert into typed message", systemImage: "keyboard") {
                            guard let completedText else { return }
                            onInsert(completedText)
                            dismiss()
                        }
                        .disabled(completedText == nil)
                    }
                    Button("Show to partner", systemImage: "rectangle.expand.vertical") {
                        focusedField = nil
                        showingDisplay = true
                    }
                    .disabled(completedText == nil)
                    ShareLink(item: completedText ?? "") {
                        Label("Share completed phrase", systemImage: "square.and.arrow.up")
                    }
                    .disabled(completedText == nil)
                }
            }
            .navigationTitle("Complete phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Show to partner", systemImage: "rectangle.expand.vertical") {
                        focusedField = nil
                        showingDisplay = true
                    }
                    .disabled(completedText == nil)
                    .accessibilityIdentifier("phrase-template-show-partner")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hide keyboard") { focusedField = nil }
                }
            }
        }
        .fullScreenCover(isPresented: $showingDisplay) {
            MessageDisplayView(message: completedText ?? "")
                .environmentObject(store)
        }
        .onChange(of: store.activeProfileID) { _, _ in dismiss() }
    }
}
