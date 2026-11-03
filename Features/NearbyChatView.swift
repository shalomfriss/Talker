import SwiftUI
import MultipeerConnectivity

struct NearbyChatView: View {
    @EnvironmentObject private var store: CommunicationStore
    @EnvironmentObject private var nearby: NearbyChatService
    @Environment(\.dismiss) private var dismiss
    @State private var reply = ""
    @State private var saveHistory = false
    @State private var showingError = false
    @State private var errorText = ""
    @State private var selectedRecipient: MCPeerID?
    @State private var isSending = false

    private var messages: [NearbyChatMessage] {
        let saved = store.nearbyMessages
        let ids = Set(saved.map(\.id))
        return (saved + nearby.sessionMessages.filter { !ids.contains($0.id) })
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionPanel
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if messages.isEmpty {
                                ContentUnavailableView("No messages yet", systemImage: "bubble.left.and.bubble.right",
                                                       description: Text("Connect to another Open Voice device to chat."))
                                    .padding(.top, 40)
                            }
                            ForEach(messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.last?.id) { _, _ in
                        if let id = messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                Divider()
                sendPanel
            }
            .navigationTitle("Nearby chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Save new messages in profile backup", isOn: $saveHistory)
                        Button("Clear chat", systemImage: "trash", role: .destructive) {
                            store.clearNearbyMessages()
                            nearby.clearSessionMessages()
                        }
                    } label: { Label("Chat options", systemImage: "ellipsis.circle") }
                }
            }
            .onAppear {
                saveHistory = store.nearbyChatSavingEnabled
                nearby.markRead()
            }
            .onChange(of: nearby.unreadCount) { _, count in
                if count > 0 { nearby.markRead() }
            }
            .onChange(of: saveHistory) { _, enabled in
                store.setNearbyChatSavingEnabled(enabled, including: nearby.sessionMessages)
            }
            .onChange(of: nearby.errorMessage) { _, error in
                if let error { present(error) }
            }
            .onChange(of: nearby.connectedPeers) { _, peers in
                if let selectedRecipient, !peers.contains(selectedRecipient) { self.selectedRecipient = nil }
            }
            .alert("Nearby chat", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorText) }
        }
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(nearby.isActive ? "Visible as \(nearby.myName)" : "Nearby chat is off")
                        .font(.headline)
                    Text(nearby.isActive ? "\(nearby.connectedPeers.count) connected" :
                         "Start to find another Open Voice device nearby.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(nearby.isActive ? "Stop" : "Start") {
                    if nearby.isActive { nearby.stop() } else { nearby.start() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("nearby-start-stop")
            }
            if let invitation = nearby.pendingInvitation {
                HStack {
                    Text("\(invitation.displayName) wants to connect")
                    Spacer()
                    Button("Decline") { nearby.answerInvitation(accept: false) }
                    Button("Connect") { nearby.answerInvitation(accept: true) }
                        .buttonStyle(.borderedProminent)
                }
                .accessibilityIdentifier("nearby-invitation")
            }
            if nearby.isActive {
                if !nearby.connectedPeers.isEmpty {
                    Text("Connected: \(nearby.connectedPeers.map(\.displayName).joined(separator: ", "))")
                        .font(.subheadline)
                }
                ForEach(nearby.discoveredPeers, id: \.self) { peer in
                    if !nearby.connectedPeers.contains(peer) {
                        Button("Connect to \(peer.displayName)", systemImage: "link") {
                            nearby.invite(peer)
                        }
                        .accessibilityIdentifier("nearby-peer-\(peer.displayName)")
                    }
                }
                if nearby.discoveredPeers.isEmpty && nearby.connectedPeers.isEmpty {
                    Text("Looking for devices on the same local network or nearby Wi-Fi…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
    }

    private var sendPanel: some View {
        VStack(spacing: 10) {
            if nearby.connectedPeers.count > 1 {
                Menu {
                    Button("Everyone") { selectedRecipient = nil }
                    ForEach(nearby.connectedPeers, id: \.self) { peer in
                        Button(peer.displayName) { selectedRecipient = peer }
                    }
                } label: {
                    Label("Send to \(selectedRecipient?.displayName ?? "Everyone")", systemImage: "person.2")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("nearby-recipient")
            }
            HStack {
                TextField("Type a reply", text: $reply, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("nearby-reply")
                Button("Send", systemImage: "arrow.up.circle.fill") {
                    send(reply, clearReplyOnSuccess: true)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending || nearby.connectedPeers.isEmpty ||
                          reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("nearby-send-reply")
            }
            HStack {
                Button("Send picture message", systemImage: "square.grid.2x2") {
                    send(store.composedMessage, pictureTokens: store.pictureMessageTokens)
                }
                .disabled(isSending || nearby.connectedPeers.isEmpty || store.composedMessage.isEmpty)
                .accessibilityIdentifier("nearby-send-picture")
                Button("Send typed message", systemImage: "text.bubble") {
                    send(store.typedMessage)
                }
                .disabled(isSending || nearby.connectedPeers.isEmpty ||
                          store.typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("nearby-send-typed")
            }
            .buttonStyle(.bordered)
            if isSending { ProgressView("Sending…") }
        }
        .padding()
    }

    private func messageBubble(_ message: NearbyChatMessage) -> some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 8) {
                Text(message.isMine ? "To \(message.recipientName ?? "Everyone")" : message.peerName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if !message.tokens.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(message.tokens) { token in
                                VStack(spacing: 4) {
                                    if let data = token.imageData {
                                        AsyncThumbnailImage(data: data, maxPixelSize: 120, contentMode: .fit) {
                                            Text(token.symbol ?? "💬").font(.largeTitle)
                                        }
                                            .frame(width: 58, height: 58)
                                    } else {
                                        Text(token.symbol ?? "💬").font(.largeTitle)
                                            .frame(width: 58, height: 58)
                                    }
                                    Text(token.text).font(.caption).lineLimit(2)
                                }
                                .frame(width: 70)
                            }
                        }
                    }
                }
                Text(message.text).font(.title3)
                Button("Speak", systemImage: "speaker.wave.2.fill") {
                    store.speak(message.text)
                }
                .font(.caption)
            }
            .padding(14)
            .background(message.isMine ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16))
            if !message.isMine { Spacer(minLength: 40) }
        }
        .accessibilityIdentifier("nearby-message-\(message.id.uuidString)")
    }

    private func send(_ text: String, pictureTokens: [PictureMessageToken] = [],
                      clearReplyOnSuccess: Bool = false) {
        guard !isSending else { return }
        isSending = true
        let recipient = selectedRecipient
        Task {
            defer { isSending = false }
            do {
                try await nearby.send(text, pictureTokens: pictureTokens, to: recipient)
                if clearReplyOnSuccess && reply == text { reply = "" }
            } catch { present(error.localizedDescription) }
        }
    }

    private func present(_ error: String) {
        errorText = error
        showingError = true
    }
}
