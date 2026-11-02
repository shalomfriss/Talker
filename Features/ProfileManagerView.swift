import SwiftUI

struct ProfileManagerView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false
    @State private var newName = ""
    @State private var renaming: CommunicationProfile?
    @State private var renamedName = ""
    @State private var pendingDelete: CommunicationProfile?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                Section {
                    Text("Each person has separate words, boards, scenes, choice boards, recordings, stories, routines, weekly plans, feelings logs, and settings. Switching clears the unfinished message.")
                        .foregroundStyle(.secondary)
                }
                Section("Profiles") {
                    ForEach(store.profiles) { profile in
                        HStack {
                            Button {
                                _ = store.switchProfile(to: profile.id)
                            } label: {
                                HStack {
                                    Text(profile.name)
                                    Spacer()
                                    if profile.id == store.activeProfileID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use profile \(profile.name)")
                            Menu {
                                Button("Rename", systemImage: "pencil") {
                                    renaming = profile
                                    renamedName = profile.name
                                }
                                if store.profiles.count > 1 {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        pendingDelete = profile
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .accessibilityLabel("Options for \(profile.name)")
                        }
                        .id(profile.id)
                    }
                }
                }
                .onAppear { proxy.scrollTo(store.activeProfileID, anchor: .center) }
                .onChange(of: store.activeProfileID) { _, id in
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add profile", systemImage: "plus") { showingAdd = true }
                }
            }
            .alert("New profile", isPresented: $showingAdd) {
                TextField("Profile name", text: $newName)
                Button("Create") {
                    if !store.addProfile(newName) { errorMessage = "Use a unique name and check available storage." }
                    newName = ""
                }
                Button("Cancel", role: .cancel) { newName = "" }
            }
            .alert("Rename profile", isPresented: Binding(
                get: { renaming != nil }, set: { if !$0 { renaming = nil } }
            )) {
                TextField("Profile name", text: $renamedName)
                Button("Save") {
                    if let renaming, !store.renameProfile(id: renaming.id, to: renamedName) {
                        errorMessage = "Use a unique name and check available storage."
                    }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
            .confirmationDialog("Delete \(pendingDelete?.name ?? "profile") and its data?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Delete profile", role: .destructive) {
                    if let pendingDelete, !store.deleteProfile(id: pendingDelete.id) {
                        errorMessage = "The profile could not be deleted."
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Export a backup of this profile first if you want to keep its data.")
            }
            .alert("Profile error", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
