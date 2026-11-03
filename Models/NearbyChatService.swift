@preconcurrency import MultipeerConnectivity
import Foundation
import UIKit

private final class NearbyInvitationHandler: @unchecked Sendable {
    let call: (Bool, MCSession?) -> Void
    init(_ call: @escaping (Bool, MCSession?) -> Void) { self.call = call }
}

@MainActor
final class NearbyChatService: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var discoveredPeers: [MCPeerID] = []
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var pendingInvitation: MCPeerID?
    @Published private(set) var sessionMessages: [NearbyChatMessage] = []
    @Published private(set) var unreadCount = 0
    @Published var errorMessage: String?

    private static let serviceType = "ov-aac-chat"
    private weak var store: CommunicationStore?
    private let preferredName: String?
    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var invitationHandler: ((Bool, MCSession?) -> Void)?
    private nonisolated let packetDecodeQueue = DispatchQueue(label: "org.openvoice.aac.nearby.decode",
                                                               qos: .userInitiated)

    init(store: CommunicationStore, displayName: String? = nil) {
        self.store = store
        self.preferredName = displayName
        super.init()
    }

    var myName: String { myPeerID?.displayName ?? UIDevice.current.name }

    func start() {
        guard !isActive else { return }
        errorMessage = nil
        let name = String((preferredName ?? UIDevice.current.name).prefix(50))
        let peer = MCPeerID(displayName: name.isEmpty ? "Open Voice" : name)
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        let advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil,
                                                    serviceType: Self.serviceType)
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        self.myPeerID = peer
        self.session = session
        self.advertiser = advertiser
        self.browser = browser
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        isActive = true
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        invitationHandler?(false, nil)
        invitationHandler = nil
        pendingInvitation = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        myPeerID = nil
        isActive = false
        discoveredPeers = []
        connectedPeers = []
        sessionMessages = []
        unreadCount = 0
        errorMessage = nil
    }

    func invite(_ peer: MCPeerID) {
        guard let browser, let session, discoveredPeers.contains(peer) else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    func answerInvitation(accept: Bool) {
        invitationHandler?(accept, accept ? session : nil)
        invitationHandler = nil
        pendingInvitation = nil
    }

    @discardableResult
    func send(_ text: String, pictureTokens: [PictureMessageToken] = [],
              to recipient: MCPeerID? = nil) async throws -> NearbyChatMessage {
        guard session?.connectedPeers.isEmpty == false else { throw NearbyChatError.noConnection }
        var tokens: [NearbyChatToken] = []
        tokens.reserveCapacity(min(100, pictureTokens.count))
        for token in pictureTokens.prefix(100) {
            tokens.append(await NearbyChatToken.prepared(from: token))
        }
        guard let session, !session.connectedPeers.isEmpty else { throw NearbyChatError.noConnection }
        let recipients: [MCPeerID]
        if let recipient {
            guard session.connectedPeers.contains(recipient) else { throw NearbyChatError.noConnection }
            recipients = [recipient]
        } else {
            recipients = session.connectedPeers
        }
        let message = NearbyChatMessage(peerName: myName,
                                        recipientName: recipient?.displayName ??
                                            (recipients.count == 1 ? recipients[0].displayName : "Everyone"),
                                        isMine: true,
                                        text: text.trimmingCharacters(in: .whitespacesAndNewlines), tokens: tokens)
        let data = try await NearbyChatPacket(message: message).encodedAsync()
        guard isActive, self.session === session,
              recipients.allSatisfy({ session.connectedPeers.contains($0) }) else {
            throw NearbyChatError.noConnection
        }
        try session.send(data, toPeers: recipients, with: .reliable)
        append(message)
        return message
    }

    func clearSessionMessages() { sessionMessages = [] }

    func markRead() { unreadCount = 0 }

    @discardableResult
    private func append(_ message: NearbyChatMessage) -> Bool {
        guard !sessionMessages.contains(where: { $0.id == message.id }) else { return false }
        sessionMessages.append(message)
        if sessionMessages.count > 200 { sessionMessages.removeFirst(sessionMessages.count - 200) }
        store?.appendNearbyMessage(message)
        return true
    }

    private func receiveInvitation(from peer: MCPeerID,
                                   handler: @escaping (Bool, MCSession?) -> Void) {
        guard isActive, pendingInvitation == nil else { handler(false, nil); return }
        pendingInvitation = peer
        invitationHandler = handler
    }

    private func updateConnectedPeers() {
        connectedPeers = session?.connectedPeers.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        } ?? []
    }
}

extension NearbyChatService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let box = NearbyInvitationHandler(invitationHandler)
        DispatchQueue.main.async { [weak self] in
            self?.receiveInvitation(from: peerID, handler: box.call)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [weak self] in self?.errorMessage = error.localizedDescription }
    }
}

extension NearbyChatService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isActive, !self.discoveredPeers.contains(peerID) else { return }
            self.discoveredPeers.append(peerID)
            self.discoveredPeers.sort {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredPeers.removeAll { $0 == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in self?.errorMessage = error.localizedDescription }
    }
}

extension NearbyChatService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in self?.updateConnectedPeers() }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        packetDecodeQueue.async { [weak self] in
            guard let packet = try? NearbyChatPacket.decode(data) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isActive, self.session === session,
                      session.connectedPeers.contains(peerID) else { return }
                if self.append(NearbyChatMessage(id: packet.id, date: packet.date,
                                                 peerName: peerID.displayName, isMine: false,
                                                 text: packet.text, tokens: packet.tokens)) {
                    self.unreadCount += 1
                }
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                             withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
