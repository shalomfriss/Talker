import SwiftUI

struct QuickResponseBar: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var repeatTapFilter = RepeatTapFilter()
    @State private var pendingResponse: QuickResponse?

    private var responses: [QuickResponse] {
        store.settings.quickResponses.filter { response in
            guard let item = sourceItem(for: response) else { return true }
            return item.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive)
        }
    }
    private var buttonColor: Color { store.settings.highContrast ? .black : .indigo }

    var body: some View {
        Group {
            if !responses.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(responses) { response in
                            responseButton(response)
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, 6)
                .background(store.settings.highContrast ? Color.white : Color(red: 0.95, green: 0.95, blue: 1))
            }
        }
        .confirmationDialog(pendingResponse?.action == .speakOnly
                            ? "Speak \(pendingResponse.map(displayText(for:)) ?? "response") now?"
                            : "Add \(pendingResponse.map(displayText(for:)) ?? "response") to your message?",
                            isPresented: Binding(get: { pendingResponse != nil },
                                                 set: { if !$0 { pendingResponse = nil } })) {
            Button(pendingResponse?.action == .speakOnly ? "Speak now" : "Add and speak") {
                if let pendingResponse { commit(pendingResponse) }
                pendingResponse = nil
            }
            Button("Cancel", role: .cancel) { pendingResponse = nil }
        }
    }

    private func responseButton(_ response: QuickResponse) -> some View {
        let label = displayText(for: response)
        let displayLabel = label.prefix(1).uppercased() + String(label.dropFirst())
        let width: CGFloat = response.text.count > 12 ? 144 : 72
        return Button {
            if store.settings.confirmSelection { pendingResponse = response }
            else { commit(response) }
        } label: {
            Text(displayLabel)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(width: width)
                .frame(minHeight: 44)
                .foregroundStyle(.white)
                .background(buttonColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayLabel)
        .accessibilityHint(response.action == .speakOnly
                           ? "Speak now without changing the message"
                           : "Speak now and add to the picture message")
        .accessibilityIdentifier("quick-response-\(response.text)")
    }

    private func commit(_ response: QuickResponse) {
        guard repeatTapFilter.allows(response.id, interval: store.settings.repeatFilterInterval) else { return }
        if response.action == .speakOnly {
            speakWithoutAdding(response)
            return
        }
        if response.audioData != nil {
            store.selectPhrase(CardPhrase(text: response.text, spanishText: response.spanishText),
                               audioData: response.audioData)
            return
        }
        if let sourceWord = response.sourceWord {
            if let item = sourceItem(for: response) {
                guard item.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive) else { return }
                let message = store.displayMessage(for: item)
                store.select(item)
                if !store.settings.speakOnTap && item.audioData == nil { store.speak(message) }
                return
            }
            if let starter = StarterVocabulary.items.first(where: { $0.label == sourceWord }) {
                store.selectPhrase(CardPhrase(text: starter.message,
                                              spanishText: StarterTranslations.spanish[sourceWord] ?? ""))
                return
            }
        }
        store.selectPhrase(CardPhrase(text: response.text, spanishText: response.spanishText))
    }

    private func speakWithoutAdding(_ response: QuickResponse) {
        if let item = sourceItem(for: response) {
            guard item.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive) else { return }
            store.speakStandaloneMessage(store.displayMessage(for: item),
                                         audioData: response.audioData ?? item.audioData)
            return
        }
        if let sourceWord = response.sourceWord,
           let starter = StarterVocabulary.items.first(where: { $0.label == sourceWord }) {
            let text = store.settings.communicationLanguage == "es"
                ? StarterTranslations.spanish[sourceWord] ?? starter.message : starter.message
            store.speakStandaloneMessage(text, audioData: response.audioData)
            return
        }
        store.speakStandaloneMessage(response.displayedText(language: store.settings.communicationLanguage),
                                     audioData: response.audioData)
    }

    private func sourceItem(for response: QuickResponse) -> CommunicationItem? {
        guard let sourceWord = response.sourceWord else { return nil }
        return store.items.first { $0.label == sourceWord && $0.destinationBoard == nil }
    }

    private func displayText(for response: QuickResponse) -> String {
        if let item = sourceItem(for: response) { return store.displayLabel(for: item) }
        return response.displayedText(language: store.settings.communicationLanguage)
    }
}

struct CommunicationRepairView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingWord: VocabularyLibraryWord?

    private var words: [VocabularyLibraryWord] {
        VocabularyLibrary.page(id: "communication-repair")?.words ?? []
    }

    private var isSpanish: Bool { store.settings.communicationLanguage == "es" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Speak a phrase now. Your picture and typed messages stay as they are.")
                        .foregroundStyle(.secondary)
                }
                Section("Phrases") {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        Button {
                            if store.settings.confirmSelection { pendingWord = word }
                            else { speak(word) }
                        } label: {
                            HStack(spacing: 14) {
                                Text(word.symbol).font(.title2).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(displayText(for: word))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(isSpanish ? word.label : word.spanishLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "speaker.wave.2")
                                    .foregroundStyle(.tint)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Speak \(displayText(for: word))")
                        .accessibilityHint("Speak without changing your message")
                        .accessibilityIdentifier("communication-repair-phrase-\(index)")
                    }
                }
            }
            .navigationTitle("Communication repair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Speak this phrase now?", isPresented: Binding(
                get: { pendingWord != nil }, set: { if !$0 { pendingWord = nil } }
            )) {
                Button("Speak now") {
                    if let pendingWord { speak(pendingWord) }
                    pendingWord = nil
                }
                Button("Cancel", role: .cancel) { pendingWord = nil }
            }
        }
    }

    private func displayText(for word: VocabularyLibraryWord) -> String {
        isSpanish ? word.spanishLabel : word.label
    }

    private func speak(_ word: VocabularyLibraryWord) {
        store.speakStandaloneMessage(displayText(for: word))
    }
}
