import SwiftUI

struct RoutineTemplatesView: View {
    @EnvironmentObject private var store: CommunicationStore
    let onOpenSpeak: () -> Void
    @State private var newName = ""
    @State private var showingSaveError = false
    @State private var templateToDelete: UUID?
    @State private var showingDeleteConfirmation = false

    init(onOpenSpeak: @escaping () -> Void) {
        self.onOpenSpeak = onOpenSpeak
    }

    var body: some View {
        List {
            Section("Save current routine") {
                TextField("Routine name", text: $newName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("routine-template-name")
                Button("Save this routine", systemImage: "square.and.arrow.down") {
                    if store.saveRoutineTemplate(name: newName) {
                        newName = ""
                    } else {
                        showingSaveError = true
                    }
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.routines.isEmpty)
                .accessibilityIdentifier("routine-template-save")
                Text("Saved routines keep photos, videos, recordings, instructions, and timers. Completion starts fresh when loaded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Saved routines") {
                if store.routineTemplates.isEmpty {
                    ContentUnavailableView("No saved routines", systemImage: "square.stack",
                                           description: Text("Name the current routine to reuse it later."))
                }
                ForEach(store.routineTemplates) { template in
                    NavigationLink {
                        RoutineTemplateDetailView(templateID: template.id, onOpenSpeak: onOpenSpeak)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name).font(.headline)
                            Text("\(template.steps.count) \(template.steps.count == 1 ? "step" : "steps")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let first = template.steps.first {
                                Text("First: \(first.title)")
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("routine-template-row")
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            templateToDelete = template.id
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved routines")
        .alert("Could not save routine", isPresented: $showingSaveError) {
            Button("OK") {}
        } message: {
            Text("Use a different name for this profile.")
        }
        .confirmationDialog("Delete saved routine?", isPresented: $showingDeleteConfirmation) {
            Button("Delete saved routine", role: .destructive) {
                if let templateToDelete { store.deleteRoutineTemplate(id: templateToDelete) }
                templateToDelete = nil
            }
            Button("Cancel", role: .cancel) { templateToDelete = nil }
        } message: {
            Text("The routine currently in use will stay in place.")
        }
        .onChange(of: store.activeProfileID) { _, _ in
            newName = ""
            templateToDelete = nil
            showingDeleteConfirmation = false
        }
    }
}

private struct RoutineTemplateDetailView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let templateID: UUID
    let onOpenSpeak: () -> Void
    @State private var name = ""
    @State private var showingRenameError = false
    @State private var showingLoadConfirmation = false
    @State private var showingUpdateConfirmation = false
    @State private var playingVideoStep: RoutineStep?
    @State private var activeChoiceBoard: ChoiceBoard?

    private var template: RoutineTemplate? {
        store.routineTemplates.first { $0.id == templateID }
    }

    var body: some View {
        List {
            if let template {
                Section("Preview") {
                    if let first = template.steps.first {
                        LabeledContent("FIRST", value: first.title)
                    }
                    if template.steps.count > 1 {
                        LabeledContent("THEN", value: template.steps[1].title)
                    }
                }
                Section("Use") {
                    NavigationLink {
                        RoutineTemplateBoardView(template: template, onOpenSpeak: onOpenSpeak)
                    } label: {
                        Label("Open First/Then board", systemImage: "rectangle.split.2x1")
                    }
                    .accessibilityIdentifier("routine-template-board")
                    NavigationLink {
                        RoutineRemindersView(templateID: templateID)
                    } label: {
                        Label("Routine reminders", systemImage: "bell.badge")
                    }
                    .accessibilityIdentifier("routine-template-reminders")
                    Button("Load this routine", systemImage: "arrow.down.square") {
                        showingLoadConfirmation = true
                    }
                    .accessibilityIdentifier("routine-template-load")
                    Text("Loading replaces the current routine. Save the current one here first if you want to keep it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Routine rewards") {
                    if store.rewardCharts.isEmpty {
                        NavigationLink {
                            RewardChartsView()
                        } label: {
                            Label("Create a reward chart", systemImage: "star.circle")
                        }
                    } else {
                        Menu {
                            Button("No linked chart") {
                                _ = store.setRoutineTemplateRewardChart(id: templateID, chartID: nil)
                            }
                            ForEach(store.rewardCharts) { chart in
                                Button(chart.title) {
                                    _ = store.setRoutineTemplateRewardChart(id: templateID, chartID: chart.id)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Reward chart")
                                Spacer()
                                Text(store.rewardCharts.first(where: { $0.id == template.rewardChartID })?.title
                                     ?? "None")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("routine-template-reward-chart")
                        if template.rewardChartID != nil {
                            Menu {
                                ForEach(RoutineRewardFrequency.allCases, id: \.self) { frequency in
                                    Button(frequency.label) {
                                        _ = store.setRoutineTemplateRewardFrequency(id: templateID, frequency: frequency)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("Earn a token for")
                                    Spacer()
                                    Text(template.rewardFrequency.label)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("routine-template-reward-frequency")
                        }
                    }
                    Text(template.rewardFrequency == .eachStep
                         ? "Each step you finish on the saved board adds one token to the linked chart. Undoing and finishing the same step again will not add another token until you start the board again."
                         : "Finishing every step on the saved board adds one token to the linked chart. Starting the board again allows another token. Communication remains available at any point.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Steps") {
                    ForEach(Array(template.steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 12) {
                            if let imageData = step.displayImageData {
                                AsyncThumbnailImage(data: imageData, maxPixelSize: 120) {
                                    Text(step.symbol).font(.title2)
                                }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .accessibilityHidden(true)
                            } else {
                                Text(step.symbol).font(.title2).frame(width: 44, height: 44)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(index + 1). \(step.title)")
                                if let duration = step.durationLabel {
                                    Text(duration).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Say \(step.title)", systemImage: "speaker.wave.2") {
                                if let audioData = step.audioData { store.playRecorded(audioData) }
                                else { store.speak(step.spokenMessage, language: store.settings.communicationLanguage) }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            if let boardID = step.choiceBoardID,
                               let board = store.choiceBoards.first(where: { $0.id == boardID }) {
                                Button("Open choices for \(step.title)", systemImage: "square.grid.2x2.fill") {
                                    store.stopSpeaking()
                                    activeChoiceBoard = board
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                            }
                            if step.videoData != nil {
                                Button("Play video for \(step.title)", systemImage: "play.rectangle.fill") {
                                    store.stopSpeaking()
                                    playingVideoStep = step
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                Section("Edit saved routine") {
                    TextField("Saved name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("routine-template-rename-field")
                    Button("Rename saved routine", systemImage: "pencil") {
                        if !store.renameRoutineTemplate(id: templateID, name: name) {
                            showingRenameError = true
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Replace saved steps with current routine", systemImage: "arrow.triangle.2.circlepath") {
                        showingUpdateConfirmation = true
                    }
                    .disabled(store.routines.isEmpty)
                }
            } else {
                ContentUnavailableView("Routine not found", systemImage: "square.stack")
            }
        }
        .navigationTitle(template?.name ?? "Saved routine")
        .sheet(item: $playingVideoStep) { SceneHotspotVideoView(step: $0) }
        .sheet(item: $activeChoiceBoard) { board in
            ChoiceBoardSessionView(board: board) {
                activeChoiceBoard = nil
                onOpenSpeak()
            }
        }
        .onAppear { name = template?.name ?? "" }
        .alert("Could not rename routine", isPresented: $showingRenameError) {
            Button("OK") {}
        } message: {
            Text("Use a different name for this profile.")
        }
        .confirmationDialog("Load saved routine?", isPresented: $showingLoadConfirmation) {
            Button("Replace current routine") {
                if store.loadRoutineTemplate(id: templateID) { dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current routine will be replaced. The saved routine starts with every step unchecked.")
        }
        .confirmationDialog("Update saved routine?", isPresented: $showingUpdateConfirmation) {
            Button("Replace saved steps") { _ = store.updateRoutineTemplate(id: templateID) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This copies the current routine into the saved routine and resets its saved completion marks.")
        }
    }
}
