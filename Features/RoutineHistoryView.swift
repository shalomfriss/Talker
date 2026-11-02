import SwiftUI

struct RoutineHistoryView: View {
    @EnvironmentObject private var store: CommunicationStore

    var body: some View {
        List {
            if store.routineHistory.isEmpty {
                ContentUnavailableView("No routine records yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Record a completed routine or one that needed more time."))
            } else {
                Section("Saved routines") {
                    ForEach(store.routineHistory) { run in
                        NavigationLink {
                            RoutineRunDetailView(run: run)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(run.outcome.label).font(.headline)
                                Text(run.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                Text("\(run.completedCount) of \(run.steps.count) steps done")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("routine-history-record")
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.deleteRoutineRun(id: run.id) }
                        }
                    }
                }
                Section("Share") {
                    ShareLink(item: RoutineCSVTransfer(data: RoutineHistoryCSV.data(for: store.routineHistory)),
                              preview: SharePreview("Open Voice Routine History")) {
                        Label("Export history as CSV", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("routine-history-export")
                    Text("The CSV includes each saved step and its completion status for this profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Routine history")
    }
}

private struct RoutineRunDetailView: View {
    let run: RoutineRun

    var body: some View {
        List {
            Section {
                LabeledContent("Result", value: run.outcome.label)
                LabeledContent("Recorded", value: run.recordedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Progress", value: "\(run.completedCount) of \(run.steps.count) steps done")
            }
            Section("Steps at that time") {
                ForEach(Array(run.steps.enumerated()), id: \.offset) { index, step in
                    HStack {
                        Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(step.isComplete ? .green : .secondary)
                            .accessibilityHidden(true)
                        Text("\(index + 1). \(step.title)")
                        Spacer()
                        if let duration = step.durationSeconds {
                            Text("\(duration / 60) min").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(step.title), \(step.isComplete ? "done" : "not done")")
                }
            }
        }
        .navigationTitle("Routine record")
    }
}
