import SwiftUI

struct CardPhraseChoicesView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int?
    @State private var scanIndex = 0
    @State private var scanPaused = false

    let item: CommunicationItem
    let onUseWord: () -> Void
    let onUsePhrase: (CardPhrase) -> Void

    private var phrases: [CardPhrase] { item.phraseOptions ?? [] }
    private var choiceCount: Int { phrases.count + 1 }
    private var scanTaskID: String {
        "\(store.settings.scanEnabled)-\(store.settings.scanInterval)-\(scanPaused)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.settings.scanEnabled { scanControls }
                List {
                    Section("Word") {
                        choiceButton(index: 0, title: store.displayLabel(for: item),
                                     subtitle: "Add just this word to the message")
                    }
                    Section("Phrases") {
                        ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                            let resolved = phrase.resolved(for: store.settings.communicationLanguage)
                            choiceButton(index: index + 1, title: resolved.text,
                                         subtitle: "Speak now and add to the message")
                        }
                    }
                }
                if store.settings.confirmSelection, let selectedIndex {
                    Button("Use selected", systemImage: "checkmark.circle.fill") {
                        finish(selectedIndex)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                    .accessibilityIdentifier("use-selected-card-choice")
                }
            }
            .navigationTitle("\(store.displayLabel(for: item)) phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task(id: scanTaskID) {
                guard store.settings.scanEnabled, !scanPaused else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(store.settings.scanInterval))
                    guard !Task.isCancelled else { return }
                    scanIndex = (scanIndex + 1) % choiceCount
                }
            }
        }
    }

    private var scanControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCANNING · CARD CHOICES")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(scanIndex == 0 ? store.displayLabel(for: item)
                 : phrases[scanIndex - 1].resolved(for: store.settings.communicationLanguage).text)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("card-scan-target")
            HStack {
                Button("Select highlighted", systemImage: "checkmark.circle.fill") { choose(scanIndex) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(" ", modifiers: [])
                    .accessibilityIdentifier("card-scan-select")
                Button("Next", systemImage: "arrow.right") {
                    scanIndex = (scanIndex + 1) % choiceCount
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("n", modifiers: [])
                Button(scanPaused ? "Resume" : "Pause", systemImage: scanPaused ? "play.fill" : "pause.fill") {
                    scanPaused.toggle()
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
        .padding()
        .background(store.settings.highContrast ? Color.white : Color.yellow.opacity(0.15))
    }

    private func choiceButton(index: Int, title: String, subtitle: String) -> some View {
        Button {
            choose(index)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
            store.settings.scanEnabled && scanIndex == index ? (store.settings.highContrast ? .black : .orange) : .clear,
            lineWidth: 4))
        .accessibilityValue(selectedIndex == index ? "Selected" : (store.settings.scanEnabled && scanIndex == index ? "Highlighted" : ""))
        .accessibilityHint(store.settings.confirmSelection ? "Choose, then use the selected choice" : subtitle)
        .accessibilityIdentifier(index == 0 ? "card-word-choice" : "card-phrase-choice-\(index)")
    }

    private func choose(_ index: Int) {
        if store.settings.confirmSelection && selectedIndex != index {
            selectedIndex = index
            return
        }
        finish(index)
    }

    private func finish(_ index: Int) {
        if index == 0 { onUseWord() }
        else if phrases.indices.contains(index - 1) { onUsePhrase(phrases[index - 1]) }
        dismiss()
    }
}
