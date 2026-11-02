import SwiftUI

struct ExpandedTypingView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var cursorOffsetValue: Int?
    @State private var largeText = false
    @State private var showingLargeMessage = false
    @State private var showingAlphabetKeyboard = false
    @State private var showingConversations = false
    @State private var showingNotes = false
    @State private var showingCommunicationRepair = false
    @State private var fillingShortcutPhrase: SavedPhrase?

    private var hasMessage: Bool {
        !store.typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var cursorAtEnd: Bool {
        (cursorOffsetValue ?? store.typedMessage.count) == store.typedMessage.count
    }

    private var sentenceSuggestions: [String] {
        guard cursorAtEnd else { return [] }
        return SentencePrediction.suggestions(
            for: store.typedMessage, phrases: store.phrases,
            quickResponses: store.settings.quickResponses,
            history: store.settings.saveHistory ? store.history : [],
            learned: store.settings.learnPrediction ? store.learnedPrediction : nil,
            language: store.settings.communicationLanguage)
    }

    private var wordSuggestions: [String] {
        guard cursorAtEnd else { return [] }
        return WordPrediction.suggestions(
            for: store.typedMessage, items: store.localizedItems(excludingPredictionKeys: true), phrases: store.phrases,
            history: store.settings.saveHistory ? store.history : [],
            learned: store.settings.learnPrediction ? store.learnedPrediction : nil,
            language: store.settings.communicationLanguage)
    }

    private var matchingShortcuts: [SavedPhrase] {
        cursorAtEnd ? PhraseShortcut.matches(store.typedMessage, phrases: store.phrases) : []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if !store.isBoardOnlyModeActive {
                    Button(store.activeConversationName, systemImage: "bubble.left.and.bubble.right") {
                        showingConversations = true
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("expanded-open-conversations")
                }
                if let highlight = store.speechHighlight,
                   highlight.source == .typed, let word = highlight.currentUnit {
                    Text("Now speaking: \(word)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("expanded-spoken-word")
                }
                MessageTextEditor(text: $store.typedMessage, cursorOffset: $cursorOffsetValue,
                                  textStyle: largeText ? .title1 : .title3) { previous, current in
                    store.previewTypedSpeech(previous: previous, current: current)
                }
                .id(store.activeConversationID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 180)
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.gray.opacity(0.3)))
                .accessibilityIdentifier("expanded-typed-editor")
                suggestionBar
                HStack(spacing: 10) {
                    Button("Speak text", systemImage: "speaker.wave.2.fill") {
                        store.speak(store.typedMessage, saveToHistory: true, followAlong: .typed)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasMessage)
                    .accessibilityIdentifier("expanded-speak-text")
                    Spacer(minLength: 0)
                    Button("Show large message", systemImage: "rectangle.expand.vertical") {
                        showingLargeMessage = true
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .disabled(!hasMessage)
                    .accessibilityIdentifier("expanded-show-message")
                    Button("Clear", systemImage: "xmark") {
                        store.stopSpeaking()
                        setMessage("")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .disabled(store.typedMessage.isEmpty)
                    .accessibilityIdentifier("expanded-clear-message")
                }
                .controlSize(.large)
                MessagePlaybackControl(source: .typed)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(store.settings.highContrast ? Color.white : Color(red: 0.98, green: 0.98, blue: 1))
            .navigationTitle("Full-screen typing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Larger editor text", isOn: $largeText)
                        Button("ABC keyboard", systemImage: "character.cursor.ibeam") {
                            showingAlphabetKeyboard = true
                        }
                        Button("Notes", systemImage: "note.text") { showingNotes = true }
                        Button("Communication repair", systemImage: "arrow.uturn.backward") {
                            showingCommunicationRepair = true
                        }
                        if !store.isBoardOnlyModeActive {
                            Divider()
                            Button("Save phrase", systemImage: "star") {
                                store.addPhrase(store.typedMessage)
                            }
                            .disabled(!hasMessage)
                            Toggle("Speak characters", isOn: $store.settings.speakTypedCharacters)
                            Toggle("Speak words", isOn: $store.settings.speakTypedWords)
                            Toggle("Speak sentences", isOn: $store.settings.speakTypedSentences)
                        }
                    } label: {
                        Label("Typing tools", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("expanded-typing-tools")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingLargeMessage) {
                MessageDisplayView(message: store.typedMessage)
            }
            .sheet(isPresented: $showingConversations) { ConversationDraftsView() }
            .sheet(isPresented: $showingNotes) { CommunicationNotesView(onUseInDraft: {}) }
            .sheet(isPresented: $showingCommunicationRepair) { CommunicationRepairView() }
            .fullScreenCover(isPresented: $showingAlphabetKeyboard) { AlphabetKeyboardView() }
            .sheet(item: $fillingShortcutPhrase) { phrase in
                PhraseTemplateFillView(phrase: phrase) { completed in
                    setMessage(PhraseShortcut.expanding(store.typedMessage, with: completed))
                }
            }
            .onChange(of: store.activeConversationID) { _, _ in cursorOffsetValue = nil }
        }
    }

    @ViewBuilder
    private var suggestionBar: some View {
        let shortcuts = matchingShortcuts
        let sentences = sentenceSuggestions
        let words = wordSuggestions
        if !shortcuts.isEmpty || !sentences.isEmpty || !words.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(shortcuts) { phrase in
                        Button {
                            if PhraseTemplate.fields(in: phrase.text).isEmpty {
                                setMessage(PhraseShortcut.expanding(store.typedMessage, with: phrase.text))
                            } else {
                                fillingShortcutPhrase = phrase
                            }
                        } label: {
                            Label("\(phrase.shortcut ?? "") → \(phrase.text)", systemImage: "text.badge.plus")
                                .lineLimit(1)
                        }
                        .accessibilityIdentifier("expanded-shortcut-\(phrase.shortcut ?? "")")
                    }
                    ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                        Button {
                            if let completed = SentencePrediction.completing(store.typedMessage,
                                                                             with: sentence) {
                                setMessage(completed)
                            }
                        } label: {
                            Label(sentence, systemImage: "text.quote")
                                .lineLimit(1)
                        }
                        .accessibilityIdentifier("expanded-sentence-\(index)")
                    }
                    ForEach(words, id: \.self) { word in
                        Button(word) {
                            setMessage(WordPrediction.completing(store.typedMessage, with: word))
                        }
                        .accessibilityIdentifier("expanded-word-\(word.lowercased())")
                    }
                }
                .buttonStyle(.bordered)
            }
            .scrollIndicators(.hidden)
            .accessibilityLabel("Typing suggestions")
        }
    }

    private func setMessage(_ value: String) {
        store.typedMessage = value
        cursorOffsetValue = value.count
    }
}
