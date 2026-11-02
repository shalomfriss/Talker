import SwiftUI
import UIKit

private enum BedsideScanTarget: Equatable {
    case card(UUID)
    case sayAgain
    case stop
    case painScale
    case edit
    case done
}

struct BedsideView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastMessage: String?
    @State private var showingEditor = false
    @State private var showingPain = false
    @State private var previousIdleTimerDisabled: Bool?
    @State private var scanIndex = 0
    @State private var scanPaused = false
    @State private var lastScanActivation = Date.distantPast

    private var language: String { store.settings.communicationLanguage }
    private var cards: [BedsideCard] { store.settings.cardsForBedside(language: language) }
    private var scanTargets: [BedsideScanTarget] {
        var targets = cards.map { BedsideScanTarget.card($0.id) }
        if lastMessage != nil { targets.append(.sayAgain) }
        targets += [.stop, .painScale]
        if !store.isBoardOnlyModeActive { targets.append(.edit) }
        targets.append(.done)
        return targets
    }
    private var highlightedScanTarget: BedsideScanTarget? {
        guard store.settings.scanEnabled, !showingEditor, !showingPain, !scanTargets.isEmpty else { return nil }
        return scanTargets[min(scanIndex, scanTargets.count - 1)]
    }
    private var currentScanCue: ScanCue? {
        guard let highlightedScanTarget else { return nil }
        return ScanCue(text: scanLabel(for: highlightedScanTarget), language: language)
    }
    private var scanTimerID: String {
        "\(store.settings.scanEnabled)-\(store.settings.scanMode.rawValue)-\(store.settings.scanInterval)-\(store.activeProfileID)"
    }
    private var scanHighlightColor: Color { store.settings.highContrast ? .black : .orange }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(lastMessage ?? (language == "es"
                        ? "Toque una tarjeta para hablar."
                        : "Tap a card to speak."))
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
                        .padding()
                        .background(store.settings.highContrast ? Color.white : Color.indigo.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("bedside-last-message")
                    HStack {
                        Button(language == "es" ? "Repetir" : "Say again", systemImage: "speaker.wave.2.fill") {
                            if let lastMessage { store.speakStandaloneMessage(lastMessage) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(lastMessage == nil)
                        .accessibilityIdentifier("bedside-say-again")
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(highlightedScanTarget == .sayAgain
                                ? scanHighlightColor : .clear, lineWidth: 4))
                        .id("bedside-scan-say-again")
                        Button(language == "es" ? "Detener" : "Stop", systemImage: "stop.fill") {
                            store.stopSpeaking()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("bedside-stop")
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(highlightedScanTarget == .stop
                                ? scanHighlightColor : .clear, lineWidth: 4))
                        .id("bedside-scan-stop")
                        Spacer()
                        Button(language == "es" ? "Escala de dolor" : "Pain scale",
                               systemImage: "cross.case") {
                            showingPain = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("bedside-pain-scale")
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(highlightedScanTarget == .painScale
                                ? scanHighlightColor : .clear, lineWidth: 4))
                        .id("bedside-scan-pain")
                    }
                    Text(language == "es"
                         ? "Las tarjetas hablan en voz alta; no contactan al personal automáticamente."
                         : "Cards speak aloud; they do not contact staff automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if cards.isEmpty {
                        ContentUnavailableView("No bedside cards", systemImage: "bed.double",
                                               description: Text("Add cards in Edit."))
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 120), spacing: 10),
                                                 count: sizeClass == .regular ? 3 : 2), spacing: 10) {
                            ForEach(cards) { card in
                                let activate = { activateCard(card) }
                                Button(action: activate) {
                                    VStack(spacing: 8) {
                                        Text(card.symbol.isEmpty ? "●" : card.symbol)
                                            .font(.largeTitle)
                                        Text(card.label)
                                            .font(.title3.weight(.semibold))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                    }
                                    .frame(maxWidth: .infinity,
                                           minHeight: sizeClass == .regular ? 120 : 110)
                                    .foregroundStyle(store.settings.highContrast ? .black : .primary)
                                    .background(store.settings.highContrast
                                                ? Color.white : Color.indigo.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 15))
                                    .overlay(RoundedRectangle(cornerRadius: 15)
                                        .strokeBorder(highlightedScanTarget == .card(card.id)
                                            ? scanHighlightColor
                                            : (store.settings.highContrast ? .black : .clear),
                                            lineWidth: highlightedScanTarget == .card(card.id) ? 4 : 2))
                                }
                                .buttonStyle(.plain)
                                .pointerDwell(duration: store.settings.pointerDwellDuration,
                                              highContrast: store.settings.highContrast, action: activate)
                                .accessibilityLabel(card.message)
                                .accessibilityIdentifier("bedside-card-\(card.id)")
                                .id("bedside-scan-card-\(card.id)")
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 850)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                if sizeClass != .regular, let lastMessage {
                    HStack(spacing: 12) {
                        Text(lastMessage)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("bedside-sticky-message")
                        Button("Say again", systemImage: "speaker.wave.2.fill") {
                            store.speakStandaloneMessage(lastMessage)
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("bedside-sticky-replay")
                        Button("Stop", systemImage: "stop.fill") { store.stopSpeaking() }
                            .labelStyle(.iconOnly)
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .safeAreaInset(edge: .top) {
                if store.settings.scanEnabled { scanControlBar }
            }
            .onChange(of: highlightedScanTarget) { _, target in
                if let target, let identifier = scanScrollID(for: target) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo(identifier, anchor: .center)
                    }
                }
            }
            }
            .navigationTitle(language == "es" ? "Comunicación de cabecera" : "Bedside communication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.isBoardOnlyModeActive {
                        Button(language == "es" ? "Editar" : "Edit") { showingEditor = true }
                            .accessibilityIdentifier("bedside-edit")
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(highlightedScanTarget == .edit
                                    ? scanHighlightColor : .clear, lineWidth: 4))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("bedside-done")
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(highlightedScanTarget == .done
                                ? scanHighlightColor : .clear, lineWidth: 4))
                }
            }
            .sheet(isPresented: $showingEditor) {
                BedsideCardEditorView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingPain) {
                NavigationStack {
                    PainCheckInView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showingPain = false }
                            }
                        }
                }
            }
            .onAppear {
                if previousIdleTimerDisabled == nil {
                    previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
            .onDisappear {
                if let previousIdleTimerDisabled {
                    UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
                    self.previousIdleTimerDisabled = nil
                }
            }
            .onChange(of: store.activeProfileID) { _, _ in lastMessage = nil; scanIndex = 0 }
            .onChange(of: language) { _, _ in lastMessage = nil; scanIndex = 0 }
            .onChange(of: currentScanCue, initial: true) { _, cue in
                if let cue { store.previewScanCue(cue) }
                else { store.stopScanCue() }
            }
            .task(id: scanTimerID) { await runScanTimer() }
            .onDisappear { store.stopScanCue() }
        }
    }

    private var scanControlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.settings.scanMode == .step ? "STEP SCAN · BEDSIDE" : "AUTO SCAN · BEDSIDE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(highlightedScanTarget.map(scanLabel(for:)) ?? "No bedside action")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("bedside-scan-target")
            HStack(spacing: 8) {
                Button("Select", systemImage: "checkmark.circle.fill") { selectHighlightedTarget() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(" ", modifiers: [])
                    .accessibilityIdentifier("bedside-scan-select")
                if store.settings.scanMode == .automatic {
                    Button(scanPaused ? "Resume" : "Pause",
                           systemImage: scanPaused ? "play.fill" : "pause.fill") {
                        scanPaused.toggle()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("bedside-scan-pause")
                }
                Button("Next", systemImage: "arrow.right") { advanceScan() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("n", modifiers: [])
                    .accessibilityIdentifier("bedside-scan-next")
            }
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(store.settings.highContrast ? Color.white : Color.yellow.opacity(0.2))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func scanLabel(for target: BedsideScanTarget) -> String {
        switch target {
        case .card(let id): return cards.first(where: { $0.id == id })?.label ?? "Bedside card"
        case .sayAgain: return language == "es" ? "Repetir" : "Say again"
        case .stop: return language == "es" ? "Detener" : "Stop"
        case .painScale: return language == "es" ? "Escala de dolor" : "Pain scale"
        case .edit: return language == "es" ? "Editar" : "Edit"
        case .done: return "Done"
        }
    }

    private func scanScrollID(for target: BedsideScanTarget) -> String? {
        switch target {
        case .card(let id): "bedside-scan-card-\(id)"
        case .sayAgain: "bedside-scan-say-again"
        case .stop: "bedside-scan-stop"
        case .painScale: "bedside-scan-pain"
        case .edit, .done: nil
        }
    }

    private func advanceScan() {
        guard !scanTargets.isEmpty else { scanIndex = 0; return }
        scanIndex = (scanIndex + 1) % scanTargets.count
    }

    private func selectHighlightedTarget() {
        let now = Date()
        guard now.timeIntervalSince(lastScanActivation) >= 0.35,
              let highlightedScanTarget else { return }
        lastScanActivation = now
        switch highlightedScanTarget {
        case .card(let id):
            if let card = cards.first(where: { $0.id == id }) { activateCard(card) }
        case .sayAgain:
            if let lastMessage { store.speakStandaloneMessage(lastMessage) }
        case .stop: store.stopSpeaking()
        case .painScale: showingPain = true
        case .edit: showingEditor = true
        case .done: dismiss()
        }
    }

    private func activateCard(_ card: BedsideCard) {
        lastMessage = card.message
        if store.settings.scanEnabled,
           let index = scanTargets.firstIndex(of: .sayAgain) { scanIndex = index }
        store.speakStandaloneMessage(card.message)
    }

    @MainActor
    private func runScanTimer() async {
        guard store.settings.scanEnabled, store.settings.scanMode == .automatic else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(store.settings.scanInterval))
            guard !Task.isCancelled else { return }
            if scenePhase == .active && !scanPaused && !showingPain && !showingEditor {
                advanceScan()
            }
        }
    }
}

private struct BedsideCardEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingCard: BedsideCard?
    @State private var addingCard = false

    private var language: String { store.settings.communicationLanguage }
    private var cards: [BedsideCard] { store.settings.cardsForBedside(language: language) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Drag to reorder. Tap a card to change its words.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Cards") {
                    ForEach(cards) { card in
                        Button {
                            editingCard = card
                        } label: {
                            HStack {
                                Text(card.symbol)
                                Text(card.label)
                                Spacer()
                                Text(card.message)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .onMove { source, destination in
                        var updated = cards
                        updated.move(fromOffsets: source, toOffset: destination)
                        store.settings.setBedsideCards(updated, language: language)
                    }
                    .onDelete { offsets in
                        var updated = cards
                        updated.remove(atOffsets: offsets)
                        store.settings.setBedsideCards(updated, language: language)
                    }
                }
            }
            .navigationTitle("Edit bedside cards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add card", systemImage: "plus") { addingCard = true }
                        .disabled(cards.count >= 24)
                        .accessibilityIdentifier("bedside-add-card")
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editingCard) { card in
                BedsideCardForm(card: card) { saved in
                    var updated = cards
                    guard let index = updated.firstIndex(where: { $0.id == card.id }) else { return }
                    updated[index] = saved
                    store.settings.setBedsideCards(updated, language: language)
                }
            }
            .sheet(isPresented: $addingCard) {
                BedsideCardForm(card: BedsideCard(symbol: "", label: "", message: "")) { saved in
                    store.settings.setBedsideCards(cards + [saved], language: language)
                }
            }
        }
    }
}

private struct BedsideCardForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BedsideCard
    let onSave: (BedsideCard) -> Void

    init(card: BedsideCard, onSave: @escaping (BedsideCard) -> Void) {
        _draft = State(initialValue: card)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Symbol", text: $draft.symbol)
                    .accessibilityIdentifier("bedside-card-symbol")
                TextField("Short label", text: $draft.label)
                    .accessibilityIdentifier("bedside-card-label")
                TextField("Words to speak", text: $draft.message, axis: .vertical)
                    .accessibilityIdentifier("bedside-card-message")
            }
            .navigationTitle("Bedside card")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        draft.symbol = String(draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4))
                        draft.label = String(draft.label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                        draft.message = String(draft.message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || draft.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("bedside-card-save")
                }
            }
        }
    }
}
