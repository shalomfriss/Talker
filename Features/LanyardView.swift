import SwiftUI

struct LanyardView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 96
    @State private var board: String
    @State private var selectedIndex = 0

    init(initialBoard: String) {
        _board = State(initialValue: initialBoard)
    }

    private var boards: [String] { store.visibleBoards + ["Favorites"] }

    private var cards: [CommunicationItem] {
        LanyardCatalog.items(in: board, from: store.items,
                             dimmedButtonsActive: store.settings.dimmedButtonsActive)
    }

    private var selectedCard: CommunicationItem? {
        cards.indices.contains(selectedIndex) ? cards[selectedIndex] : nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Menu {
                        ForEach(boards, id: \.self) { name in
                            Button(name) { board = name; selectedIndex = 0 }
                        }
                    } label: {
                        Label(board, systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Lanyard board: \(board)")
                    .accessibilityIdentifier("lanyard-board-menu")
                    Spacer()
                    Text(cards.isEmpty ? "No speaking cards" : "Card \(selectedIndex + 1) of \(cards.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("lanyard-card-count")
                }
                .padding(.horizontal)

                if cards.isEmpty {
                    ContentUnavailableView("No speaking cards on \(board)",
                                           systemImage: "rectangle.stack",
                                           description: Text("Choose another board with the board menu."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, item in
                            card(item)
                                .padding(.horizontal, 20)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .accessibilityIdentifier("lanyard-cards")

                    HStack(spacing: 16) {
                        Button("Previous card", systemImage: "chevron.left") {
                            selectedIndex = max(0, selectedIndex - 1)
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedIndex == 0)
                        .accessibilityIdentifier("lanyard-previous")

                        Button("Speak card", systemImage: "speaker.wave.2.fill") { speakSelected() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityLabel(selectedCard.map { "Speak \(store.displayLabel(for: $0))" } ?? "Speak card")
                            .accessibilityIdentifier("lanyard-speak")

                        Button("Next card", systemImage: "chevron.right") {
                            selectedIndex = min(cards.count - 1, selectedIndex + 1)
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedIndex + 1 >= cards.count)
                        .accessibilityIdentifier("lanyard-next")
                    }
                    .padding(.bottom)
                }
            }
            .background(store.settings.highContrast ? Color.white : Color(red: 0.97, green: 0.97, blue: 1))
            .navigationTitle("Lanyard cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("lanyard-done")
                }
            }
            .onChange(of: store.visibleBoards) { _, visible in
                if !visible.contains(board) && board != "Favorites" {
                    board = visible.first ?? "Favorites"
                    selectedIndex = 0
                }
            }
            .onChange(of: cards.map(\.id)) { _, ids in
                selectedIndex = min(selectedIndex, max(0, ids.count - 1))
            }
            .onChange(of: store.activeProfileID) { _, _ in dismiss() }
            .onAppear {
                if !boards.contains(board) { board = boards.first ?? "Favorites" }
            }
        }
    }

    private func card(_ item: CommunicationItem) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)
            if let imageData = item.imageData {
                AsyncThumbnailImage(data: imageData, maxPixelSize: 640, contentMode: .fit) {
                    Text(item.symbol).font(.system(size: symbolSize))
                }
                    .frame(maxWidth: 320, maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
            } else {
                Text(item.symbol)
                    .font(.system(size: symbolSize))
                    .minimumScaleFactor(0.7)
                    .accessibilityHidden(true)
            }
            Text(store.displayLabel(for: item))
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("lanyard-card-label")
            let spokenText = store.displayMessage(for: item)
            if spokenText != store.displayLabel(for: item) {
                Text(spokenText)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(store.settings.highContrast ? Color.white : Color(red: 0.91, green: 0.94, blue: 1),
                    in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28)
            .strokeBorder(store.settings.highContrast ? Color.black : Color.indigo.opacity(0.2), lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.displayLabel(for: item)). \(store.displayMessage(for: item))")
    }

    private func speakSelected() {
        guard let selectedCard else { return }
        store.speakStandaloneMessage(store.displayMessage(for: selectedCard),
                                     audioData: selectedCard.audioData,
                                     voiceIdentifier: store.boardFolderVoiceIdentifier(for: selectedCard))
    }
}
