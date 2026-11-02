import SwiftUI

struct SentenceSuggestionsView: View {
    @Environment(\.dismiss) private var dismiss

    let suggestions: [String]
    let onUse: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Complete your message with a saved phrase, quick reply, or recent message. Recent messages appear only when message history is on. Repeated spoken word patterns can also suggest a sentence when learning is on.")
                        .foregroundStyle(.secondary)
                }
                Section("Sentences") {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, sentence in
                        Button {
                            onUse(sentence)
                            dismiss()
                        } label: {
                            Text(sentence)
                                .font(.title3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .accessibilityIdentifier("sentence-choice-\(index)")
                    }
                }
            }
            .navigationTitle("Sentence suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
