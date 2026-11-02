import SwiftUI

struct BoardOrderView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBoard: String
    @State private var editMode: EditMode = .inactive
    @State private var arrangementMode: ArrangementMode = .list
    @State private var isSelectingForSort = false
    @State private var selectedSortIDs: Set<UUID> = []
    @State private var selectedSwapID: UUID?
    @State private var swapPage = 0
    @State private var previewAvailableWidth: CGFloat = 300
    private let boardAvailableWidth: CGFloat

    private enum ArrangementMode: String, CaseIterable {
        case list = "List"
        case swap = "Swap"
    }

    init(board: String, availableWidth: CGFloat) {
        _selectedBoard = State(initialValue: board == "Favorites" ? "Core" : board)
        boardAvailableWidth = availableWidth
    }

    private var boardItems: [CommunicationItem] {
        store.items.filter { $0.category == selectedBoard }
    }

    private var previewColumns: Int {
        store.gridLayout(for: selectedBoard)?.columns ?? BoardScanner.columnCount(
            availableWidth: max(boardAvailableWidth, 320),
            minimumTileWidth: store.tileSize(for: selectedBoard).minimumWidth)
    }

    private var previewCapacity: Int {
        store.gridLayout(for: selectedBoard)?.pageCapacity ?? previewColumns * 4
    }

    private var previewPageCount: Int {
        let occupiedPages = max(1, (max(1, store.gridSlots(in: selectedBoard).count) - 1) / previewCapacity + 1)
        return boardItems.isEmpty ? 1 : occupiedPages + 1
    }

    private var previewRange: Range<Int> {
        let start = min(swapPage, previewPageCount - 1) * previewCapacity
        return start..<(start + previewCapacity)
    }

    private var previewSlots: [CommunicationItem?] {
        store.gridSlots(in: selectedBoard, minimumCount: previewRange.upperBound)
    }

    private var previewCellWidth: CGFloat {
        let gridWidth = max(CGFloat(previewColumns) * 76, previewAvailableWidth)
        return (gridWidth - CGFloat(previewColumns - 1) * 8) / CGFloat(previewColumns)
    }

    private var previewGrid: some View {
        let slots = previewSlots
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                 count: previewColumns), spacing: 8) {
            ForEach(previewRange, id: \.self) { index in
                if let item = slots[index] {
                    swapCell(item, position: index)
                } else {
                    emptySwapCell(position: index)
                }
            }
        }
        .frame(width: max(CGFloat(previewColumns) * 76, previewAvailableWidth))
        .padding(.vertical, 4)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Board", selection: $selectedBoard) {
                        ForEach(store.categories, id: \.self) { board in
                            Text(board).tag(board)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("arrange-board-picker")
                    Picker("Arrange style", selection: $arrangementMode) {
                        ForEach(ArrangementMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("arrange-style")
                    Text(isSelectingForSort
                         ? "Select buttons, then choose Alphabetize selected. Other buttons stay in place."
                         : "Use arrows, Drag, or Sort in List. In Swap, tap two positions or drag a button into an empty position. Hidden and dimmed buttons keep their spaces.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                if arrangementMode == .swap {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 12) {
                        Text("Arrange grid positions").font(.headline)
                        Text("Tap two buttons to swap, or tap a button then an empty position to move it. You can also drag onto a button or empty position. Change pages between taps.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Previous page", systemImage: "chevron.left") {
                                swapPage -= 1
                            }
                            .labelStyle(.iconOnly)
                            .disabled(swapPage == 0)
                            .accessibilityIdentifier("swap-page-previous")
                            Spacer()
                            Text("Page \(swapPage + 1) of \(previewPageCount)")
                                .accessibilityIdentifier("swap-page-label")
                            Spacer()
                            Button("Next page", systemImage: "chevron.right") {
                                swapPage += 1
                            }
                            .labelStyle(.iconOnly)
                            .disabled(swapPage + 1 >= previewPageCount)
                            .accessibilityIdentifier("swap-page-next")
                        }
                        .buttonStyle(.borderless)
                        Group {
                            if CGFloat(previewColumns) * 76 > previewAvailableWidth {
                                ScrollView(.horizontal) { previewGrid }
                            } else {
                                previewGrid
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                            previewAvailableWidth = width
                        }
                        if let selectedSwapID,
                           let selectedItem = boardItems.first(where: { $0.id == selectedSwapID }) {
                            HStack {
                                Text("Selected: \(store.displayLabel(for: selectedItem))")
                                    .accessibilityIdentifier("swap-selected")
                                Spacer()
                                Button("Cancel selection") { self.selectedSwapID = nil }
                            }
                        }
                        }
                        .padding()
                    }
                } else {
                    List {
                    Section("Buttons") {
                    ForEach(Array(boardItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text(item.symbol)
                                .font(.title2)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.displayLabel(for: item))
                                    .font(.body.weight(.medium))
                                if item.boardVisibility != .shown {
                                    Text(item.boardVisibility.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if isSelectingForSort {
                                Button(selectedSortIDs.contains(item.id) ? "Deselect \(item.label)" : "Select \(item.label)",
                                       systemImage: selectedSortIDs.contains(item.id) ? "checkmark.circle.fill" : "circle") {
                                    toggleSortSelection(item.id)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("sort-select-\(item.label)")
                            } else if editMode == .inactive {
                                Button("Move \(item.label) up", systemImage: "arrow.up") {
                                    _ = store.moveItem(item.id, in: selectedBoard, by: -1)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .disabled(index == 0)
                                .accessibilityIdentifier("move-up-\(item.label)")
                                Button("Move \(item.label) down", systemImage: "arrow.down") {
                                    _ = store.moveItem(item.id, in: selectedBoard, by: 1)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .disabled(index == boardItems.count - 1)
                                .accessibilityIdentifier("move-down-\(item.label)")
                            }
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        _ = store.moveItems(in: selectedBoard, fromOffsets: fromOffsets,
                                            toOffset: toOffset)
                    }
                    }
                    }
                }
                if arrangementMode == .list && isSelectingForSort {
                    VStack(spacing: 10) {
                        HStack {
                            Text("\(selectedSortIDs.count) selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Select all") {
                                selectedSortIDs = Set(boardItems.map(\.id))
                            }
                            Button("Clear selection") { selectedSortIDs.removeAll() }
                                .disabled(selectedSortIDs.isEmpty)
                        }
                        Button("Alphabetize selected") { alphabetizeSelection() }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(selectedSortIDs.count < 2)
                    }
                    .padding()
                    .background(.bar)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Arrange buttons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if arrangementMode == .list {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelectingForSort ? "Cancel" : "Sort") {
                            if isSelectingForSort {
                                endSortSelection()
                            } else {
                                editMode = .inactive
                                isSelectingForSort = true
                            }
                        }
                    }
                    if !isSelectingForSort {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(editMode == .active ? "Finish" : "Drag") {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }
                    }
                }
            }
            .onChange(of: store.categories) { _, boards in
                if !boards.contains(selectedBoard) { selectedBoard = "Core" }
            }
            .onChange(of: selectedBoard) { _, _ in
                selectedSwapID = nil
                swapPage = 0
                endSortSelection()
            }
            .onChange(of: arrangementMode) { _, _ in
                editMode = .inactive
                selectedSwapID = nil
                endSortSelection()
            }
        }
    }

    private func swapCell(_ item: CommunicationItem, position: Int) -> some View {
        VStack(spacing: 4) {
            Text(item.symbol).font(.title2).accessibilityHidden(true)
            Text(store.displayLabel(for: item))
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if item.boardVisibility != .shown {
                Text(item.boardVisibility.title).font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 84)
        .padding(4)
        .background(Color.accentColor.opacity(selectedSwapID == item.id ? 0.20 : 0.08),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(selectedSwapID == item.id ? 1 : 0.22),
                        lineWidth: selectedSwapID == item.id ? 3 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { selectSwapItem(item.id) }
        .draggable(item.id.uuidString)
        .dropDestination(for: String.self) { values, session in
            guard let rawID = values.first, let draggedID = UUID(uuidString: rawID) else { return }
            rearrangeDraggedItem(draggedID, onto: item.id, at: session.location.x)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Position \(position + 1), \(item.label)")
        .accessibilityHint("Tap to select a position. Drag onto the middle of another button to swap, or near its edge to insert.")
        .accessibilityAction(.default) { selectSwapItem(item.id) }
        .accessibilityIdentifier("swap-cell-\(item.label)")
    }

    private func emptySwapCell(position: Int) -> some View {
        Text("Empty")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .padding(4)
            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture { placeSelectedItem(at: position) }
            .dropDestination(for: String.self) { values, _ in
                guard let rawID = values.first, let itemID = UUID(uuidString: rawID) else { return }
                _ = store.moveItem(itemID, in: selectedBoard, toEmptyGridPosition: position)
                selectedSwapID = nil
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Empty position \(position + 1)")
            .accessibilityHint("Select a button, then tap here to move it into this position.")
            .accessibilityAction(.default) { placeSelectedItem(at: position) }
            .accessibilityIdentifier("swap-empty-\(position + 1)")
    }

    private func placeSelectedItem(at position: Int) {
        guard let selectedSwapID else { return }
        _ = store.moveItem(selectedSwapID, in: selectedBoard, toEmptyGridPosition: position)
        self.selectedSwapID = nil
    }

    private func selectSwapItem(_ id: UUID) {
        if let selectedSwapID {
            if selectedSwapID != id {
                _ = store.swapItems(selectedSwapID, with: id, in: selectedBoard)
            }
            self.selectedSwapID = nil
        } else {
            selectedSwapID = id
        }
    }

    private func toggleSortSelection(_ id: UUID) {
        if selectedSortIDs.contains(id) {
            selectedSortIDs.remove(id)
        } else {
            selectedSortIDs.insert(id)
        }
    }

    private func endSortSelection() {
        isSelectingForSort = false
        selectedSortIDs.removeAll()
    }

    private func alphabetizeSelection() {
        _ = store.alphabetizeItems(in: selectedBoard, selectedIDs: selectedSortIDs)
        endSortSelection()
    }

    private func rearrangeDraggedItem(_ draggedID: UUID, onto targetID: UUID, at x: CGFloat) {
        guard let source = boardItems.firstIndex(where: { $0.id == draggedID }),
              let target = boardItems.firstIndex(where: { $0.id == targetID }) else { return }
        let edgeWidth = previewCellWidth * 0.22
        if x < edgeWidth {
            _ = store.moveItems(in: selectedBoard, fromOffsets: IndexSet(integer: source), toOffset: target)
        } else if x > previewCellWidth - edgeWidth {
            _ = store.moveItems(in: selectedBoard, fromOffsets: IndexSet(integer: source), toOffset: target + 1)
        } else {
            _ = store.swapItems(draggedID, with: targetID, in: selectedBoard)
        }
        selectedSwapID = nil
    }
}
