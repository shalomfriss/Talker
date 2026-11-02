import SwiftUI

struct TypedWordFormsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss

    let context: TypedWordForms.Context
    let onUse: (EnglishWordForms.Option) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose a form for “\(context.word)”. Preview speaks it before you use it.")
                        .foregroundStyle(.secondary)
                }
                Section("Typed word") {
                    ForEach(context.options) { option in
                        HStack(spacing: 12) {
                            Button {
                                onUse(option)
                                dismiss()
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
                            .accessibilityIdentifier("typed-word-form-\(option.kind.rawValue)")
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
            .navigationTitle("Typed word forms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
