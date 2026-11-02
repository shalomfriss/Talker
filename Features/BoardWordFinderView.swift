import SwiftUI

struct BoardWordFinderView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    let onChoose: (UUID) -> Void

    private var results: [BoardWordFinderResult] {
        BoardWordFinder.matches(query, in: store.items,
                                dimmedButtonsActive: store.settings.dimmedButtonsActive,
                                labelFor: store.displayLabel(for:))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Find a picture word", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("finder-query")
                } footer: {
                    Text("Choose a result to practice its path. The board and word will be outlined; no word is spoken until you select its button.")
                }

                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Word paths") {
                        if results.isEmpty {
                            ContentUnavailableView.search(text: query)
                        } else {
                            ForEach(results) { result in
                                Button {
                                    onChoose(result.id)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(result.item.symbol)
                                            .font(.title2)
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(result.displayLabel)
                                                .font(.headline)
                                            Text(result.path.joined(separator: " → "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                            .accessibilityHidden(true)
                                    }
                                    .frame(minHeight: 48)
                                }
                                .accessibilityLabel("Practice path to \(result.displayLabel) on \(result.item.category) board")
                                .accessibilityIdentifier("finder-result-\(result.item.category)-\(result.item.label)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Word finder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
