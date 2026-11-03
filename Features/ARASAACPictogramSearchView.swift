import SwiftUI

struct ARASAACPictogramSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Data, Int) -> Void
    @State private var query: String
    @State private var language: String
    @State private var results: [ARASAACPictogram] = []
    @State private var isSearching = false
    @State private var selectingID: Int?
    @State private var savingID: Int?
    @State private var photoSaveMessage: String?
    @State private var errorText: String?

    init(initialQuery: String, language: String, onSelect: @escaping (Data, Int) -> Void) {
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
        _language = State(initialValue: ["en", "es"].contains(language) ? language : "en")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("Search pictograms", text: $query)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                        .accessibilityIdentifier("arasaac-query")
                    Button("Search") { Task { await search() } }
                        .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("arasaac-search")
                }
                .padding(.horizontal)
                Picker("Search language", selection: $language) {
                    Text("English").tag("en")
                    Text("Español").tag("es")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .accessibilityIdentifier("arasaac-language")

                if isSearching { ProgressView("Searching pictograms") }
                if let errorText {
                    ContentUnavailableView("Search unavailable", systemImage: "wifi.exclamationmark",
                                           description: Text(errorText))
                } else if results.isEmpty && !isSearching {
                    ContentUnavailableView("Find a pictogram", systemImage: "square.grid.2x2",
                                           description: Text("Search for a word or short phrase. Internet is needed to search and select a symbol."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112, maximum: 170), spacing: 12)],
                                  spacing: 12) {
                            ForEach(results) { pictogram in
                                VStack(spacing: 6) {
                                    Button {
                                        Task { await select(pictogram) }
                                    } label: {
                                        VStack(spacing: 6) {
                                            AsyncImage(url: pictogram.previewURL) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().scaledToFit()
                                                case .failure:
                                                    Image(systemName: "photo.badge.exclamationmark")
                                                        .foregroundStyle(.secondary)
                                                case .empty:
                                                    ProgressView()
                                                @unknown default:
                                                    ProgressView()
                                                }
                                            }
                                            .frame(height: 105)
                                            Text(pictogram.title)
                                                .font(.caption)
                                                .lineLimit(2)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(selectingID != nil || savingID != nil)
                                    .accessibilityLabel("Use \(pictogram.title) pictogram")
                                    .accessibilityIdentifier("arasaac-result-\(pictogram.id)")
                                    Button("Save to Photos", systemImage: "square.and.arrow.down") {
                                        Task { await saveToPhotos(pictogram) }
                                    }
                                    .font(.caption2)
                                    .buttonStyle(.bordered)
                                    .disabled(selectingID != nil || savingID != nil)
                                    .accessibilityIdentifier("arasaac-save-photo-\(pictogram.id)")
                                }
                                .padding(8)
                                .background(Color(uiColor: .secondarySystemBackground),
                                            in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding()
                    }
                }
                if selectingID != nil { ProgressView("Adding pictogram") }
                if savingID != nil { ProgressView("Saving pictogram to Photos") }
                if let photoSaveMessage {
                    Text(photoSaveMessage)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityIdentifier("arasaac-photo-save-message")
                }
                VStack(spacing: 3) {
                    Text(ARASAACPictogramService.attribution)
                        .font(.caption2)
                    Link("Noncommercial license and terms", destination: ARASAACPictogramService.termsURL)
                        .font(.caption2)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("ARASAAC pictograms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await search()
            }
        }
    }

    private func search() async {
        guard !isSearching else { return }
        isSearching = true
        errorText = nil
        do {
            results = try await ARASAACPictogramService.search(query: query, language: language)
            if results.isEmpty { errorText = "No pictograms found. Try a different word." }
        } catch {
            results = []
            errorText = error.localizedDescription
        }
        isSearching = false
    }

    private func select(_ pictogram: ARASAACPictogram) async {
        guard selectingID == nil, savingID == nil else { return }
        selectingID = pictogram.id
        do {
            let data = try await ARASAACPictogramService.download(id: pictogram.id)
            onSelect(data, pictogram.id)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
        selectingID = nil
    }

    private func saveToPhotos(_ pictogram: ARASAACPictogram) async {
        guard selectingID == nil, savingID == nil else { return }
        photoSaveMessage = nil
        savingID = pictogram.id
        defer { savingID = nil }
        do {
            try await ARASAACPictogramService.saveToPhotos(id: pictogram.id)
            photoSaveMessage = "Saved to Photos. Credit Sergio Palao / ARASAAC when you reuse this pictogram."
        } catch {
            photoSaveMessage = error.localizedDescription
        }
    }
}
