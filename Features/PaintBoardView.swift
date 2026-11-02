import SwiftUI

struct PaintBoardView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var boardName: String
    @State private var selectedColorHex: String? = "#FFF2A6"
    @State private var selectedColorName = "Yellow"
    @State private var customColor = Color(red: 0.84, green: 0.78, blue: 0.96)
    @State private var paintedCount = 0
    @State private var undo: PaintUndo?

    private let swatches: [PaintSwatch] = [
        .init(name: "Coral", hex: "#FFB7A8"),
        .init(name: "Yellow", hex: "#FFF2A6"),
        .init(name: "Mint", hex: "#BFE9D1"),
        .init(name: "Sky", hex: "#B7DFFD"),
        .init(name: "Lavender", hex: "#D9CBF5"),
        .init(name: "Pink", hex: "#F6C8DB"),
        .init(name: "Slate", hex: "#D7DEE8"),
        .init(name: "White", hex: "#FFFFFF")
    ]

    init(initialBoard: String) {
        _boardName = State(initialValue: initialBoard)
    }

    private var boardItems: [CommunicationItem] {
        store.items.filter { $0.category == boardName }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: max(110, store.tileSize(for: boardName).minimumWidth),
                            maximum: 220), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.settings.highContrast {
                    Text("High contrast is on. Painted colors will appear on the communication board when high contrast is off.")
                        .font(.subheadline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                HStack {
                    Text("Selected: \(selectedColorName)")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("paint-selected-color")
                    Spacer()
                    Text("\(paintedCount) changed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("paint-count")
                    Button("Undo last", systemImage: "arrow.uturn.backward") { undoLast() }
                        .labelStyle(.iconOnly)
                        .disabled(undo == nil)
                        .accessibilityIdentifier("paint-undo")
                }
                .padding(.horizontal)
                .padding(.top, 12)

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(swatches) { swatch in
                            swatchButton(swatch)
                        }
                        Button {
                            selectedColorHex = nil
                            selectedColorName = "Default"
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 40))
                                    .frame(width: 40, height: 40)
                                Text("Default").font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use default color")
                        .accessibilityValue(selectedColorHex == nil ? "Selected" : "")
                        .accessibilityIdentifier("paint-swatch-default")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)

                HStack {
                    ColorPicker("Custom color", selection: $customColor, supportsOpacity: false)
                        .accessibilityIdentifier("paint-custom-color")
                    Button("Use custom") {
                        if let hex = ButtonColorAppearance.hex(from: customColor) {
                            selectedColorHex = hex
                            selectedColorName = "Custom"
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("paint-use-custom")
                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                Divider()
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.categories, id: \.self) { name in
                            Button(name) { boardName = name }
                                .buttonStyle(.bordered)
                                .tint(boardName == name ? .indigo : .primary)
                                .fontWeight(boardName == name ? .bold : .regular)
                                .accessibilityAddTraits(boardName == name ? .isSelected : [])
                                .accessibilityIdentifier("paint-board-\(name)")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)

                if boardItems.isEmpty {
                    ContentUnavailableView("No buttons on \(boardName)", systemImage: "paintpalette",
                                           description: Text("Add buttons before painting this board."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(boardItems) { item in
                                paintTile(item)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Paint buttons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear {
                if !store.categories.contains(boardName) { boardName = store.categories.first ?? "Core" }
            }
        }
    }

    private func paintTile(_ item: CommunicationItem) -> some View {
        CommunicationTile(item: item, size: store.tileSize(for: boardName), highContrast: false,
                          grammarColorScheme: store.settings.grammarColorScheme,
                          isScanHighlighted: false,
                          displayLabel: store.displayLabel(for: item)) {
            paint(item)
        }
        .overlay(alignment: .topLeading) {
            if item.boardVisibility != .shown {
                Text(item.boardVisibility.title)
                    .font(.caption2.weight(.semibold))
                    .padding(4)
                    .background(.regularMaterial, in: Capsule())
                    .padding(5)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint("Apply \(selectedColorName) to \(store.displayLabel(for: item))")
        .accessibilityValue(item.backgroundColorHex ?? "Default color")
        .accessibilityIdentifier("paint-button-\(item.category)-\(item.label)")
    }

    private func swatchButton(_ swatch: PaintSwatch) -> some View {
        let color = ButtonColorValue(text: swatch.hex).map(ButtonColorAppearance.color) ?? Color.gray
        let selected = selectedColorHex == swatch.hex
        return Button {
            selectedColorHex = swatch.hex
            selectedColorName = swatch.name
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
                    .overlay(Circle().strokeBorder(selected ? Color.primary : Color.clear,
                                                   lineWidth: 3).padding(-3))
                Text(swatch.name).font(.caption)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Paint \(swatch.name)")
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityIdentifier("paint-swatch-\(swatch.name)")
        .contextMenu {
            Button("Lighter \(swatch.name)") {
                selectedColorHex = swatch.lighterHex
                selectedColorName = "Lighter \(swatch.name)"
            }
            Button("Darker \(swatch.name)") {
                selectedColorHex = swatch.darkerHex
                selectedColorName = "Darker \(swatch.name)"
            }
        }
    }

    private func paint(_ item: CommunicationItem) {
        guard store.setButtonBackgroundColor(selectedColorHex, for: item.id) else { return }
        undo = PaintUndo(itemID: item.id, previousHex: item.backgroundColorHex)
        paintedCount += 1
    }

    private func undoLast() {
        guard let undo else { return }
        if store.setButtonBackgroundColor(undo.previousHex, for: undo.itemID) {
            paintedCount = max(0, paintedCount - 1)
        }
        self.undo = nil
    }
}

private struct PaintSwatch: Identifiable {
    let name: String
    let hex: String
    var id: String { name }

    var lighterHex: String { shade(toward: 255, portion: 0.45) }
    var darkerHex: String { shade(toward: 0, portion: 0.25) }

    private func shade(toward target: Int, portion: Double) -> String {
        guard let color = ButtonColorValue(text: hex) else { return hex }
        func mixed(_ channel: Int) -> Int {
            Int((Double(channel) + Double(target - channel) * portion).rounded())
        }
        return ButtonColorValue(red: mixed(color.red), green: mixed(color.green),
                                blue: mixed(color.blue)).hex
    }
}

private struct PaintUndo {
    let itemID: UUID
    let previousHex: String?
}
