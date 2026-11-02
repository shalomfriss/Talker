import SwiftUI

struct FeelingsHistoryView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var showOneDay = false
    @State private var selectedDate = Date()
    @State private var showingClearConfirmation = false

    private var entries: [FeelingLogEntry] {
        store.feelingsLog
            .filter { !showOneDay || Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var sharedText: String {
        entries.map { entry in
            "\(entry.timestamp.formatted(date: .abbreviated, time: .shortened)) — \(entry.message)"
        }.joined(separator: "\n")
    }

    var body: some View {
        List {
            Section("Find a day") {
                Toggle("Show one day", isOn: $showOneDay)
                if showOneDay {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
            }
            Section("Saved check-ins") {
                if entries.isEmpty {
                    ContentUnavailableView("No check-ins for this day", systemImage: "heart.text.square",
                                           description: Text("Choose another date or save a check-in from How I feel."))
                }
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text(entry.symbol).font(.title2).accessibilityHidden(true)
                            Text(entry.feelingLabel).font(.headline)
                            Spacer()
                            if entry.intensity > 0 {
                                Text("\(entry.intensity)/\(entry.scaleMaximum == 10 ? 10 : 5)")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        Text(entry.message).font(.subheadline)
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Speak again", systemImage: "speaker.wave.2") {
                            store.speak(entry.message, language: entry.language)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(entry.feelingLabel)\(entry.intensity > 0 ? ", strength \(entry.intensity) out of \(entry.scaleMaximum == 10 ? 10 : 5)" : ""), \(entry.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.deleteFeelingEntry(id: entry.id) }
                    }
                }
            }
            if !entries.isEmpty {
                Section("Share") {
                    ShareLink(item: sharedText) {
                        Label("Share shown check-ins", systemImage: "square.and.arrow.up")
                    }
                    Text("Only the check-ins currently shown are shared when you choose this action.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if !store.feelingsLog.isEmpty {
                Section {
                    Button("Delete all check-ins", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("Feelings log")
        .confirmationDialog("Delete every saved check-in?", isPresented: $showingClearConfirmation) {
            Button("Delete all check-ins", role: .destructive) { store.clearFeelingsLog() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: store.activeProfileID) { _, _ in
            showOneDay = false
            selectedDate = Date()
        }
    }
}
