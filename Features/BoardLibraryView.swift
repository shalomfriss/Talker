import SwiftUI

struct BoardLibraryView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var matchingTemplates: [VocabularyLibraryTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return VocabularyLibrary.templates }
        return VocabularyLibrary.templates.filter {
            $0.title.localizedStandardContains(query) || $0.summary.localizedStandardContains(query)
        }
    }

    private func matchingPages(in group: VocabularyLibraryGroup) -> [VocabularyLibraryPage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let pages = VocabularyLibrary.pages.filter { $0.group == group }
        guard !query.isEmpty else { return pages }
        return pages.filter { page in
            page.title.localizedStandardContains(query) || page.summary.localizedStandardContains(query)
                || page.words.contains { word in
                    word.label.localizedStandardContains(query)
                        || word.spanishLabel.localizedStandardContains(query)
                }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Add ready-made vocabulary pages to the current profile. Each page includes English and Spanish button text. Existing boards keep their personal words and settings.")
                        .foregroundStyle(.secondary)
                }
                if !matchingTemplates.isEmpty {
                    Section("Setup templates") {
                        ForEach(matchingTemplates) { template in
                            NavigationLink {
                                LibraryTemplateDetailView(template: template)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(template.icon).font(.title2).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(template.title).font(.headline)
                                        Text(template.summary).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(template.pageIDs.count) pages")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("library-template-\(template.id)")
                        }
                    }
                }
                ForEach(VocabularyLibraryGroup.allCases) { group in
                    let pages = matchingPages(in: group)
                    if !pages.isEmpty {
                        Section(group.rawValue) {
                            ForEach(pages) { page in
                                NavigationLink {
                                    LibraryPageDetailView(page: page)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(page.icon)
                                            .font(.title2)
                                            .accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(page.title)
                                                .font(.headline)
                                            Text(page.summary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if store.missingLibraryWordCount(for: page) == 0 {
                                                Text("Added")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text("\(page.words.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .accessibilityLabel("\(page.words.count) buttons")
                                    }
                                }
                                .accessibilityIdentifier("library-page-\(page.id)")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Find a page or phrase")
            .navigationTitle("Page library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct LibraryTemplateDetailView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var profileName: String
    @State private var result: LibraryTemplateAddResult?
    @State private var applyResult: LibraryTemplateApplyResult?
    @State private var failureMessage: String?
    @State private var showApplyOptions = false

    let template: VocabularyLibraryTemplate

    init(template: VocabularyLibraryTemplate) {
        self.template = template
        _profileName = State(initialValue: "\(template.title) setup")
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Text(template.icon).font(.largeTitle).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.title).font(.title3.weight(.semibold))
                        Text(template.summary).foregroundStyle(.secondary)
                    }
                }
                Text("Creates a separate profile with starter boards and these ready-made pages. Your current profile stays available.")
                    .foregroundStyle(.secondary)
            }
            Section("Included pages") {
                ForEach(template.pageIDs, id: \.self) { pageID in
                    if let page = VocabularyLibrary.page(id: pageID) {
                        HStack(spacing: 12) {
                            Text(page.icon).accessibilityHidden(true)
                            Text(page.title)
                            Spacer()
                            Text("\(page.words.count) buttons")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("New profile") {
                TextField("Profile name", text: $profileName)
                    .accessibilityIdentifier("library-template-profile-name")
            }
            Section("Current profile") {
                Text("Apply these pages to \(store.activeProfileName). The starter boards stay. You can keep or replace personal boards; a named local backup is saved first.")
                    .foregroundStyle(.secondary)
                Button("Apply to current profile", systemImage: "square.on.square") {
                    showApplyOptions = true
                }
                .accessibilityIdentifier("library-apply-template")
            }
        }
        .navigationTitle(template.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Create profile with \(template.pageIDs.count) pages", systemImage: "person.crop.circle.badge.plus") {
                result = store.createProfileFromLibraryTemplate(id: template.id, named: profileName)
                if result == nil { failureMessage = "Choose a different profile name and try again." }
            }
            .buttonStyle(.borderedProminent)
            .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || result != nil)
            .accessibilityIdentifier("library-create-template-profile")
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
        }
        .alert("Profile created", isPresented: Binding(
            get: { result != nil }, set: { if !$0 { result = nil } }
        )) {
            Button("OK") { dismiss() }
        } message: {
            if let result {
                Text("Added \(result.pageCount) pages and \(result.buttonCount) buttons to \(result.profileName).")
            }
        }
        .confirmationDialog("Apply template to \(store.activeProfileName)?",
                            isPresented: $showApplyOptions, titleVisibility: .visible) {
            Button("Keep personal boards") { apply(.keepPersonalBoards) }
            Button("Replace personal boards", role: .destructive) { apply(.replacePersonalBoards) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Starter boards remain. A local backup is saved first. Replacing removes personal boards and buttons that link to them.")
        }
        .alert("Template applied", isPresented: Binding(
            get: { applyResult != nil }, set: { if !$0 { applyResult = nil } }
        )) {
            Button("OK") { dismiss() }
        } message: {
            if let applyResult {
                Text("Added \(applyResult.pageCount) pages. Removed \(applyResult.removedBoardCount) personal boards. Backup: \(applyResult.backupName).")
            }
        }
        .alert("Could not finish", isPresented: Binding(
            get: { failureMessage != nil }, set: { if !$0 { failureMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(failureMessage ?? "Try again.")
        }
    }

    private func apply(_ mode: LibraryTemplateApplyMode) {
        do {
            applyResult = try store.applyLibraryTemplate(id: template.id, mode: mode)
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}

private struct LibraryPageDetailView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var addResult: LibraryPageAddResult?

    let page: VocabularyLibraryPage

    private var missingCount: Int {
        store.missingLibraryWordCount(for: page)
    }

    private var boardExists: Bool {
        store.categories.contains { $0.localizedCaseInsensitiveCompare(page.title) == .orderedSame }
    }

    private var addTitle: String {
        if missingCount == 0 { return "Page is up to date" }
        if boardExists { return "Add \(missingCount) missing buttons" }
        return "Add page with \(missingCount) buttons"
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    Text(page.icon)
                        .font(.largeTitle)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(page.title).font(.title3.weight(.semibold))
                        Text(page.summary).foregroundStyle(.secondary)
                    }
                }
                Text("\(page.words.count) buttons · English and Spanish")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Buttons") {
                ForEach(page.words, id: \.label) { word in
                    HStack(spacing: 12) {
                        Text(word.symbol)
                            .font(.title2)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word.label)
                            Text(word.spanishLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(addTitle, systemImage: "plus.square.on.square") {
                addResult = store.addLibraryPage(id: page.id)
            }
            .buttonStyle(.borderedProminent)
            .disabled(missingCount == 0)
            .accessibilityIdentifier("library-add-page")
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
        }
        .alert("Page added", isPresented: Binding(
            get: { addResult != nil }, set: { if !$0 { addResult = nil } }
        )) {
            Button("OK") { addResult = nil }
        } message: {
            if let addResult {
                Text("Added \(addResult.addedCount) buttons to \(addResult.boardName).")
            }
        }
    }
}
