import SwiftUI

struct AlphabetKeyboardView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var uppercase = true
    @State private var showingNumbers = false
    @State private var showingLargeMessage = false
    @State private var cursorOffset = 0
    @State private var wordFormContext: TypedWordForms.Context?
    @State private var showingSentenceSuggestions = false
    @State private var selectedKeyCluster: KeyboardKeyCluster?
    @State private var showingCustomLetterOrder = false
    @State private var showingWordKeyboardEditor = false
    @State private var showingCommunicationRepair = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 38), spacing: 6), count: sizeClass == .regular ? 9 : 6)
    }

    private var groupColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: sizeClass == .regular ? 3 : 2)
    }

    private var tenKeyColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: sizeClass == .regular ? 3 : 2)
    }

    private var letters: [String] {
        store.settings.orderedLetters(language: store.settings.communicationLanguage)
    }

    private var keys: [String] {
        showingNumbers ? Array("0123456789").map(String.init)
            + ["-", "/", ":", ";", "(", ")", "$", "&", "@"]
            + (store.settings.tenKeyKeyboardEnabled ? [",", ".", "?", "!"] : [])
            : letters
    }

    private var sentenceSuggestions: [String] {
        guard cursorOffset == store.typedMessage.count else { return [] }
        return store.sentenceSuggestions()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    QuickResponseBar()
                    HStack {
                        Text("Your message")
                            .font(.headline)
                        Spacer()
                        if !sentenceSuggestions.isEmpty {
                            Button("Sentence suggestions", systemImage: "text.quote") {
                                showingSentenceSuggestions = true
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityHint("Complete from saved phrases, recent messages, or learned word patterns")
                            .accessibilityIdentifier("alphabet-sentence-suggestions")
                        }
                        if let context = TypedWordForms.context(in: store.typedMessage,
                                                                cursorOffset: cursorOffset,
                                                                language: store.settings.communicationLanguage) {
                            Button("Word forms for \(context.word)", systemImage: "textformat") {
                                wordFormContext = context
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Word forms for \(context.word)")
                            .accessibilityIdentifier("alphabet-word-forms")
                        }
                        Button("Move left", systemImage: "arrow.left") {
                            cursorOffset = max(0, cursorOffset - 1)
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("alphabet-cursor-left")
                        .disabled(cursorOffset == 0)
                        Button("Move right", systemImage: "arrow.right") {
                            cursorOffset = min(store.typedMessage.count, cursorOffset + 1)
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("alphabet-cursor-right")
                        .disabled(cursorOffset >= store.typedMessage.count)
                    }
                    ScrollView {
                        if store.typedMessage.isEmpty {
                            Text("Tap the letters to write a message.")
                                .foregroundStyle(.secondary)
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                                .padding(14)
                        } else {
                            messageWithCursor
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                                .padding(14)
                                .accessibilityLabel(store.typedMessage)
                                .accessibilityHint("Use the left and right buttons to move the cursor")
                                .accessibilityIdentifier("alphabet-message")
                        }
                    }
                    .frame(maxHeight: 150)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.gray.opacity(0.3)))
                    if let highlight = store.speechHighlight, highlight.source == .typed {
                        SpeechFollowAlongView(state: highlight)
                    }

                    let suggestions = cursorOffset == store.typedMessage.count
                        ? store.wordSuggestions()
                        : []
                    let trailingEmoji = cursorOffset == store.typedMessage.count
                        ? EmojiWordPrediction.trailingEmoji(in: store.typedMessage) : nil
                    let emojiWords = trailingEmoji == nil ? [] : EmojiWordPrediction.suggestions(
                        for: store.typedMessage, language: store.settings.communicationLanguage)
                    if let trailingEmoji {
                        ScrollView(.horizontal) {
                            HStack {
                                Button("Keep \(trailingEmoji)") {
                                    store.typedMessage = EmojiWordPrediction.keepingTrailingEmoji(
                                        in: store.typedMessage)
                                    cursorOffset = store.typedMessage.count
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("alphabet-emoji-keep")
                                ForEach(emojiWords, id: \.self) { word in
                                    Button(word) {
                                        store.typedMessage = EmojiWordPrediction.replacingTrailingEmoji(
                                            in: store.typedMessage, with: word)
                                        cursorOffset = store.typedMessage.count
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Replace \(trailingEmoji) with \(word)")
                                    .accessibilityIdentifier("alphabet-emoji-word-\(word.lowercased().replacingOccurrences(of: " ", with: "-"))")
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .accessibilityLabel("Emoji word suggestions")
                    } else if !suggestions.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(suggestions, id: \.self) { word in
                                    Button(word) {
                                        store.typedMessage = WordPrediction.completing(store.typedMessage, with: word)
                                        cursorOffset = store.typedMessage.count
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier(store.typedMessage.last?.isWhitespace == true
                                        ? "alphabet-next-word-suggestion-\(word.lowercased())"
                                        : "alphabet-word-suggestion-\(word.lowercased())")
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .accessibilityLabel(store.typedMessage.last?.isWhitespace == true
                                            ? "Next word suggestions" : "Word suggestions")
                    }

                    Toggle("Word keys", isOn: $store.settings.wordKeyboardEnabled)
                        .accessibilityHint("Use editable word and phrase keys to compose your message")
                        .accessibilityIdentifier("alphabet-word-keys-toggle")
                    if store.settings.wordKeyboardEnabled {
                        if !store.isBoardOnlyModeActive {
                            Button("Edit word keys", systemImage: "square.and.pencil") {
                                showingWordKeyboardEditor = true
                            }
                            .accessibilityIdentifier("alphabet-edit-word-keys")
                        }
                        wordKeyboard
                    } else {
                    if !store.isBoardOnlyModeActive {
                        Picker("Letter order", selection: $store.settings.letterOrder) {
                            ForEach(LetterOrder.allCases, id: \.self) { order in
                                Text(order.title).tag(order)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("alphabet-letter-order")
                        if store.settings.letterOrder == .custom {
                            Button("Edit custom order", systemImage: "arrow.up.arrow.down") {
                                showingCustomLetterOrder = true
                            }
                            .accessibilityIdentifier("alphabet-edit-custom-order")
                        }
                    }

                    Toggle("Grouped keys", isOn: Binding(
                        get: { store.settings.groupedKeyboardKeys },
                        set: { store.settings.selectGroupedKeyboardKeys($0) }
                    ))
                        .accessibilityIdentifier("alphabet-grouped-keys")
                    Toggle("Ten Key", isOn: Binding(
                        get: { store.settings.tenKeyKeyboardEnabled },
                        set: { store.settings.selectTenKeyKeyboard($0) }
                    ))
                        .accessibilityIdentifier("alphabet-ten-key-toggle")

                    if (store.settings.groupedKeyboardKeys || store.settings.tenKeyKeyboardEnabled),
                       let selectedKeyCluster {
                        expandedKeyCluster(selectedKeyCluster)
                    } else if store.settings.tenKeyKeyboardEnabled {
                        tenKeyKeyboard
                    } else if store.settings.groupedKeyboardKeys {
                        LazyVGrid(columns: groupColumns, spacing: 10) {
                            ForEach(KeyboardKeyCluster.groups(for: keys)) { cluster in
                                clusterButton(cluster, tenKey: false)
                            }
                        }
                    } else if !showingNumbers && store.settings.letterOrder == .qwerty {
                        qwertyKeyboard
                    } else {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(keys, id: \.self) { key in
                                keyButton(key)
                            }
                        }
                    }
                    if !store.settings.tenKeyKeyboardEnabled {
                        HStack(spacing: 6) {
                            controlButton(uppercase ? "Shift on" : "Shift off", symbol: "shift") {
                                uppercase.toggle()
                            }
                            controlButton(showingNumbers ? "ABC" : "123", symbol: "number") {
                                showingNumbers.toggle()
                            }
                            controlButton("Delete", symbol: "delete.left") {
                                deleteBeforeCursor()
                            }
                            .accessibilityIdentifier("alphabet-delete")
                        }
                        HStack(spacing: 6) {
                            punctuationButton(",")
                            controlButton("Space", symbol: "space") { insert(" ") }
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("alphabet-space")
                            punctuationButton(".")
                            punctuationButton("?")
                            punctuationButton("!")
                        }
                    }
                    }
                }
                .padding()
                .frame(maxWidth: 850)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Alphabet keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Communication repair", systemImage: "arrow.uturn.backward") {
                        showingCommunicationRepair = true
                    }
                    .accessibilityHint("Speak a phrase without changing your message")
                    .accessibilityIdentifier("alphabet-open-communication-repair")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if store.settings.wordKeyboardEnabled, !store.typedMessage.isEmpty {
                        Text(store.typedMessage)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .accessibilityLabel("Current message: \(store.typedMessage)")
                    }
                    MessagePlaybackControl(source: .typed)
                    if !store.settings.wordKeyboardEnabled,
                       store.settings.tenKeyKeyboardEnabled, selectedKeyCluster == nil {
                        tenKeyControls
                    }
                    HStack {
                        Button("Speak text", systemImage: "speaker.wave.2.fill") {
                            store.speak(store.typedMessage, saveToHistory: true, followAlong: .typed)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("alphabet-speak")
                        Spacer(minLength: 0)
                        Button("Show", systemImage: "rectangle.expand.vertical") {
                            showingLargeMessage = true
                        }
                        Button("Clear", systemImage: "xmark") {
                            store.stopSpeaking()
                            store.typedMessage = ""
                            cursorOffset = 0
                            uppercase = true
                        }
                        .accessibilityIdentifier("alphabet-clear")
                        .disabled(store.typedMessage.isEmpty)
                    }
                    .padding(12)
                }
                .background(.regularMaterial)
            }
            .sheet(isPresented: $showingLargeMessage) {
                MessageDisplayView(message: store.typedMessage)
            }
            .sheet(isPresented: $showingCommunicationRepair) { CommunicationRepairView() }
            .sheet(isPresented: $showingCustomLetterOrder) {
                NavigationStack { CustomLetterOrderView() }
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingWordKeyboardEditor) {
                WordKeyboardEditorView()
                    .environmentObject(store)
            }
            .sheet(item: $wordFormContext) { context in
                TypedWordFormsView(context: context) { option in
                    guard let result = TypedWordForms.replacing(store.typedMessage, context: context,
                                                                with: option) else { return }
                    store.typedMessage = result.text
                    cursorOffset = result.cursorOffset
                }
            }
            .sheet(isPresented: $showingSentenceSuggestions) {
                SentenceSuggestionsView(suggestions: sentenceSuggestions) { sentence in
                    guard let completed = SentencePrediction.completing(store.typedMessage,
                                                                        with: sentence) else { return }
                    store.typedMessage = completed
                    cursorOffset = completed.count
                }
            }
            .onAppear { cursorOffset = min(max(store.typedCursorOffset ?? store.typedMessage.count, 0),
                                           store.typedMessage.count) }
            .onDisappear { store.typedCursorOffset = cursorOffset }
            .onChange(of: keys) { _, _ in selectedKeyCluster = nil }
            .onChange(of: store.settings.groupedKeyboardKeys) { _, _ in selectedKeyCluster = nil }
            .onChange(of: store.settings.tenKeyKeyboardEnabled) { _, _ in selectedKeyCluster = nil }
            .onChange(of: store.activeProfileID) { _, _ in selectedKeyCluster = nil }
        }
    }

    private var messageWithCursor: Text {
        let characters = Array(store.typedMessage)
        let offset = min(cursorOffset, characters.count)
        return Text("\(String(characters.prefix(offset)))│\(String(characters.dropFirst(offset)))")
    }

    private var wordKeyboard: some View {
        let count = store.settings.wordKeyboardColumns == 0
            ? (sizeClass == .regular ? 4 : 3) : store.settings.wordKeyboardColumns
        let grid = Array(repeating: GridItem(.flexible(minimum: 70), spacing: 8), count: count)
        let words = store.settings.wordsForKeyboard(language: store.settings.communicationLanguage)
        return VStack(spacing: 10) {
            LazyVGrid(columns: grid, spacing: 8) {
                ForEach(words) { key in
                    let activate = { insertWordKey(key) }
                    Button(action: activate) {
                        Text(key.label)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: sizeClass == .regular ? 80 : 64)
                            .background(store.settings.highContrast ? .black.opacity(0.14) : .indigo.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .pointerDwell(duration: store.settings.pointerDwellDuration,
                                  highContrast: store.settings.highContrast, action: activate)
                    .accessibilityLabel("Insert \(key.text)")
                    .accessibilityIdentifier("word-key-\(key.id)")
                }
            }
            HStack(spacing: 8) {
                controlButton("Delete", symbol: "delete.left") { deleteBeforeCursor() }
                    .accessibilityIdentifier("word-key-delete")
                controlButton("Space", symbol: "space") { insert(" ") }
                    .accessibilityIdentifier("word-key-space")
            }
        }
    }

    private func insertWordKey(_ key: WordKeyboardKey) {
        let previous = store.typedMessage
        let result = key.inserting(into: previous, at: cursorOffset)
        store.typedMessage = result.text
        cursorOffset = result.cursorOffset
        if cursorOffset == result.text.count {
            store.previewTypedSpeech(previous: previous, current: result.text)
        }
    }

    private var qwertyKeyboard: some View {
        VStack(spacing: 6) {
            ForEach(Array(LetterOrder.qwerty.qwertyRows(language: store.settings.communicationLanguage).enumerated()),
                    id: \.offset) { row in
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    ForEach(row.element, id: \.self) { key in
                        keyButton(key)
                            .frame(maxWidth: 70)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var tenKeyKeyboard: some View {
        LazyVGrid(columns: tenKeyColumns, spacing: 10) {
            ForEach(KeyboardKeyCluster.groups(for: keys)) { cluster in
                clusterButton(cluster, tenKey: true)
            }
        }
    }

    private var tenKeyControls: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                                 count: sizeClass == .regular ? 4 : 2), spacing: 6) {
            tenKeyAction("Space", symbol: "space", identifier: "alphabet-ten-key-space") {
                insert(" ")
            }
            tenKeyAction("Delete", symbol: "delete.left", identifier: "alphabet-ten-key-delete") {
                deleteBeforeCursor()
            }
            tenKeyAction(showingNumbers ? "Period" : (uppercase ? "Shift on" : "Shift off"),
                         symbol: showingNumbers ? "circle.fill" : "shift",
                         identifier: "alphabet-ten-key-shift") {
                if showingNumbers { insert(".") } else { uppercase.toggle() }
            }
            tenKeyAction(showingNumbers ? "ABC" : "123", symbol: "number",
                         identifier: "alphabet-ten-key-numbers") {
                showingNumbers.toggle()
            }
        }
        .padding(.horizontal, 12)
    }

    private func expandedKeyCluster(_ cluster: KeyboardKeyCluster) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button("All key groups", systemImage: "arrow.left") {
                    selectedKeyCluster = nil
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("alphabet-all-key-groups")
                Spacer()
                Text(cluster.keys.joined(separator: "  "))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: groupColumns, spacing: 10) {
                ForEach(cluster.keys, id: \.self) { key in
                    keyButton(key, expanded: true)
                }
            }
        }
    }

    private func clusterButton(_ cluster: KeyboardKeyCluster, tenKey: Bool) -> some View {
        let openGroup = { selectedKeyCluster = cluster }
        return Button(action: openGroup) {
            Text(cluster.keys.map { showingNumbers || uppercase ? $0 : $0.lowercased() }
                .joined(separator: "  "))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: sizeClass == .regular ? 100 : 86)
                .background(store.settings.highContrast ? .black.opacity(0.14) : .indigo.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .pointerDwell(duration: store.settings.pointerDwellDuration,
                      highContrast: store.settings.highContrast, action: openGroup)
        .accessibilityLabel("Key group \(cluster.keys.joined(separator: ", "))")
        .accessibilityIdentifier(tenKey
            ? "alphabet-ten-key-group-\(cluster.id)" : "alphabet-key-group-\(cluster.id)")
    }

    private func tenKeyAction(_ title: String, symbol: String, identifier: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(store.settings.highContrast ? .black : .indigo)
                .frame(maxWidth: .infinity, minHeight: sizeClass == .regular ? 72 : 60)
                .background(store.settings.highContrast ? .black.opacity(0.14) : .indigo.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12))
        }
            .buttonStyle(.plain)
            .pointerDwell(duration: store.settings.pointerDwellDuration,
                          highContrast: store.settings.highContrast, action: action)
            .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func keyButton(_ key: String, expanded: Bool = false) -> some View {
        let label = showingNumbers || uppercase ? key : key.lowercased()
        let activate = {
            insert(label)
            if !showingNumbers { uppercase = false }
            if expanded { selectedKeyCluster = nil }
        }
        let button = Button(action: activate) {
            Text(label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(store.settings.highContrast ? .black : .indigo)
                .frame(maxWidth: .infinity,
                       minHeight: expanded ? (sizeClass == .regular ? 100 : 86)
                           : (sizeClass == .regular ? 62 : 48))
                .background(store.settings.highContrast ? .black.opacity(0.14) : .indigo.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .pointerDwell(duration: store.settings.pointerDwellDuration,
                      highContrast: store.settings.highContrast, action: activate)
        .accessibilityIdentifier("alphabet-key-\(key)")

        if !showingNumbers && store.settings.communicationLanguage == "es",
           let accent = ["A": "Á", "E": "É", "I": "Í", "O": "Ó", "U": "Ú"].first(where: { $0.key == key })?.value {
            button.contextMenu {
                Button(uppercase ? accent : accent.lowercased()) {
                    insert(uppercase ? accent : accent.lowercased())
                    uppercase = false
                    if expanded { selectedKeyCluster = nil }
                }
                if key == "U" {
                    Button(uppercase ? "Ü" : "ü") {
                        insert(uppercase ? "Ü" : "ü")
                        uppercase = false
                        if expanded { selectedKeyCluster = nil }
                    }
                }
            }
            .accessibilityHint("Hold for an accented letter")
        } else {
            button
        }
    }

    private func controlButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: symbol, action: action)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, minHeight: 48)
            .buttonStyle(.bordered)
            .pointerDwell(duration: store.settings.pointerDwellDuration,
                          highContrast: store.settings.highContrast, action: action)
    }

    private func punctuationButton(_ mark: String) -> some View {
        let activate = {
            insert(mark)
            if ".?!".contains(mark) { uppercase = true }
        }
        return Button(mark, action: activate)
        .font(.title3)
        .frame(minWidth: 45, minHeight: 48)
        .buttonStyle(.bordered)
        .pointerDwell(duration: store.settings.pointerDwellDuration,
                      highContrast: store.settings.highContrast, action: activate)
    }

    private func insert(_ text: String) {
        let previous = store.typedMessage
        let offset = min(cursorOffset, previous.count)
        var updated = previous
        updated.insert(contentsOf: text, at: updated.index(updated.startIndex, offsetBy: offset))
        store.typedMessage = updated
        cursorOffset = offset + text.count
        if offset == previous.count {
            store.previewTypedSpeech(previous: previous, current: updated)
        }
    }

    private func deleteBeforeCursor() {
        guard cursorOffset > 0, cursorOffset <= store.typedMessage.count else { return }
        var updated = store.typedMessage
        let end = updated.index(updated.startIndex, offsetBy: cursorOffset)
        let start = updated.index(before: end)
        updated.removeSubrange(start..<end)
        store.typedMessage = updated
        cursorOffset -= 1
    }
}
