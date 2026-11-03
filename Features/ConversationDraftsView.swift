import SwiftUI

struct ConversationDraftsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingNameAlert = false
    @State private var editingConversationID: UUID?
    @State private var deleting: ConversationDraft?
    @State private var draftName = ""
    @State private var confirmingPrivateExit = false
    @State private var privateExitConversationID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(store.isPrivateConversationActive
                         ? "This draft is not saved to conversations or backups and does not update history, recent items, or prediction learning. Choosing Save or Share can create a copy."
                         : "Keep more than one message in progress. Switching conversations saves both the picture message and typed text for each one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    if store.isPrivateConversationActive {
                        Label("Private conversation is active", systemImage: "eye.slash")
                            .accessibilityIdentifier("private-conversation-active")
                        Button("End and discard private conversation", systemImage: "xmark.circle",
                               role: .destructive) {
                            privateExitConversationID = nil
                            confirmingPrivateExit = true
                        }
                        .accessibilityIdentifier("end-private-conversation")
                    } else {
                        Button("Start private conversation", systemImage: "eye.slash") {
                            store.beginPrivateConversation()
                            dismiss()
                        }
                        .accessibilityIdentifier("start-private-conversation")
                    }
                }
                Section("Conversations") {
                    ForEach(store.conversations) { draft in
                        HStack(spacing: 12) {
                            Button {
                                if store.isPrivateConversationActive {
                                    privateExitConversationID = draft.id
                                    confirmingPrivateExit = true
                                } else {
                                    _ = store.switchConversation(to: draft.id)
                                    dismiss()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(draft.name).font(.headline)
                                        if draft.id == store.activeConversationID && !store.isPrivateConversationActive {
                                            Text("Current").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Text(draft.preview)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use conversation \(draft.name)")
                            .accessibilityIdentifier("use-conversation-\(draft.id)")
                            Menu {
                                Button("Rename", systemImage: "pencil") {
                                    draftName = draft.name
                                    editingConversationID = draft.id
                                    showingNameAlert = true
                                }
                                if store.conversations.count > 1 {
                                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = draft }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Manage conversation \(draft.name)")
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New conversation", systemImage: "plus") {
                        draftName = ""
                        editingConversationID = nil
                        showingNameAlert = true
                    }
                    .accessibilityIdentifier("add-conversation")
                    .disabled(store.isPrivateConversationActive)
                }
            }
            .alert(editingConversationID == nil ? "New conversation" : "Rename conversation",
                   isPresented: $showingNameAlert) {
                TextField("Conversation name", text: $draftName)
                Button(editingConversationID == nil ? "Create" : "Save") {
                    if let id = editingConversationID {
                        _ = store.renameConversation(id: id, to: draftName)
                    } else if store.addConversation(draftName) {
                        dismiss()
                    }
                }
                .disabled(!validName(excluding: editingConversationID))
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Name this conversation so you can return to it later.")
            }
            .confirmationDialog("Delete \(deleting?.name ?? "conversation")?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }
            )) {
                Button("Delete conversation", role: .destructive) {
                    if let deleting { _ = store.deleteConversation(id: deleting.id) }
                    deleting = nil
                }
                Button("Cancel", role: .cancel) { deleting = nil }
            } message: {
                Text("Its picture and typed drafts will be deleted.")
            }
            .confirmationDialog("Discard private conversation?", isPresented: $confirmingPrivateExit) {
                Button("Discard private messages", role: .destructive) {
                    if let id = privateExitConversationID {
                        _ = store.switchConversation(to: id)
                    } else {
                        store.endPrivateConversation()
                    }
                    privateExitConversationID = nil
                    dismiss()
                }
                Button("Keep private conversation", role: .cancel) {
                    privateExitConversationID = nil
                }
            } message: {
                Text("The private picture and typed messages will be cleared. Saved conversations remain available.")
            }
        }
    }

    private func validName(excluding id: UUID? = nil) -> Bool {
        let clean = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && !store.conversations.contains {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame
        }
    }
}
