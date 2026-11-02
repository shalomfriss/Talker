import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: CommunicationStore

    var body: some View {
        List {
            if store.history.isEmpty {
                ContentUnavailableView("No recent messages", systemImage: "clock", description: Text("Complete messages you speak will appear here."))
            } else {
                ForEach(store.history) { entry in
                    HStack(spacing: 12) {
                        Button {
                            store.speak(entry.text)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.text).foregroundStyle(.primary)
                                Text(entry.date, style: .relative).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Speak again")
                        ShareLink(item: entry.text) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("Share message")
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.deleteHistoryEntry(entry) }
                    }
                }
            }
        }
        .navigationTitle("Recent messages")
        .toolbar {
            if !store.history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear all", role: .destructive) { store.clearHistory() }
                }
            }
        }
    }
}
