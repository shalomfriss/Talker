import SwiftUI

struct FocusWordsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Binding var isActive: Bool
    @State private var selection: Set<UUID> = []
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose words to emphasize on Speak. Every word stays available in its usual place, including words outside this focus set.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(selection.count) focus words selected")
                        .font(.subheadline.weight(.semibold))
                }
                ForEach(store.categories, id: \.self) { category in
                    let words = matchingWords(in: category)
                    if !words.isEmpty {
                        Section(category) {
                            ForEach(words) { item in
                                Button {
                                    if selection.contains(item.id) { selection.remove(item.id) }
                                    else { selection.insert(item.id) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(item.symbol).font(.title2).accessibilityHidden(true)
                                        Text(store.displayLabel(for: item))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selection.contains(item.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.purple)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .frame(minHeight: 44)
                                }
                                .accessibilityLabel("Focus word \(store.displayLabel(for: item))")
                                .accessibilityValue(selection.contains(item.id) ? "Selected" : "Not selected")
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Find a focus word")
            .navigationTitle("Focus words")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button(isActive ? "Update focus" : "Start focus", systemImage: "scope") {
                        store.settings.focusWordIDs = store.items.map(\.id).filter(selection.contains)
                        isActive = true
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selection.isEmpty)
                    .accessibilityIdentifier("start-focus")
                    if isActive {
                        Button("End focus") {
                            isActive = false
                            dismiss()
                        }
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial)
            }
            .onAppear {
                let available = Set(store.items.filter { $0.destinationBoard == nil }.map(\.id))
                selection = Set(store.settings.focusWordIDs).intersection(available)
            }
        }
    }

    private func matchingWords(in category: String) -> [CommunicationItem] {
        store.items.filter { item in
            guard item.category == category, item.destinationBoard == nil else { return false }
            guard !search.isEmpty else { return true }
            return item.label.localizedCaseInsensitiveContains(search)
                || store.displayLabel(for: item).localizedCaseInsensitiveContains(search)
                || item.message.localizedCaseInsensitiveContains(search)
        }
    }
}
