import SwiftUI

struct WordFormsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose the form that says what you mean. Preview speaks a form before you use it.")
                        .foregroundStyle(.secondary)
                }
                Section("Last picture word") {
                    ForEach(store.lastWordFormOptions) { option in
                        HStack(spacing: 12) {
                            Button {
                                if store.changeLastWordForm(to: option.kind) { dismiss() }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.text).font(.title3.weight(.semibold))
                                    Text(option.title).font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use \(option.text), \(option.title)")
                            .accessibilityIdentifier("word-form-\(option.kind.rawValue)")
                            Button("Preview \(option.text)", systemImage: "speaker.wave.2") {
                                store.speak(option.text, language: option.language)
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Preview \(option.text)")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Word forms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
