import XCTest
import UIKit
@testable import OpenVoice

final class NearbyChatTests: XCTestCase {
    func testPacketKeepsPictureAndTextAcrossDevices() throws {
        let token = NearbyChatToken(text: "water", symbol: "💧", imageData: Data([1, 2, 3]))
        let outgoing = NearbyChatMessage(peerName: "My iPad", isMine: true,
                                         text: "I want water", tokens: [token])
        let packet = try NearbyChatPacket.decode(NearbyChatPacket(message: outgoing).encoded())
        XCTAssertEqual(packet.id, outgoing.id)
        XCTAssertEqual(packet.text, "I want water")
        XCTAssertEqual(packet.tokens, [token])
    }

    func testPacketsRejectOversizedOrEmptyMessages() throws {
        let empty = NearbyChatMessage(peerName: "Me", isMine: true, text: "  ")
        XCTAssertThrowsError(try NearbyChatPacket(message: empty).encoded())
        let tooLong = NearbyChatMessage(peerName: "Me", isMine: true,
                                        text: String(repeating: "x", count: 4_001))
        XCTAssertThrowsError(try NearbyChatPacket(message: tooLong).encoded())
        XCTAssertThrowsError(try NearbyChatPacket.decode(Data(repeating: 0, count: 2_000_001)))
    }

    @MainActor
    func testPersonalPhotoIsReducedForPictureChat() throws {
        let data = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600)).pngData { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }
        let token = NearbyChatToken(PictureMessageToken(text: "my cup", symbol: nil, imageData: data))
        let shared = try XCTUnwrap(token.imageData)
        XCTAssertLessThan(shared.count, 100_000)
        let image = try XCTUnwrap(UIImage(data: shared))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 128)
        let message = NearbyChatMessage(peerName: "Me", isMine: true, text: "my cup", tokens: [token])
        let received = try NearbyChatPacket.decode(NearbyChatPacket(message: message).encoded())
        XCTAssertEqual(received.tokens.first?.imageData, shared)
    }

    @MainActor
    func testChatHistoryNeedsOptInAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("first.json"))
        let unsaved = NearbyChatMessage(peerName: "Partner", isMine: false, text: "Hello")
        store.appendNearbyMessage(unsaved)
        XCTAssertTrue(store.nearbyMessages.isEmpty)
        store.setNearbyChatSavingEnabled(true, including: [unsaved])
        let saved = NearbyChatMessage(peerName: "Me", isMine: true, text: "Hi")
        store.appendNearbyMessage(saved)
        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("second.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.nearbyMessages, [unsaved, saved])
        XCTAssertTrue(restored.nearbyChatSavingEnabled)
        restored.clearNearbyMessages()
        XCTAssertTrue(restored.nearbyMessages.isEmpty)
    }

    func testOldProfileWithoutNearbyKeysStartsWithPrivateHistory() throws {
        let data = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                              phrases: StarterVocabulary.phrases, settings: AppSettings())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as? [String: Any])
        json.removeValue(forKey: "nearbyMessages")
        json.removeValue(forKey: "nearbyChatSavingEnabled")
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(StoredData.self, from: old)
        XCTAssertTrue(decoded.nearbyMessages.isEmpty)
        XCTAssertFalse(decoded.nearbyChatSavingEnabled)
    }

    @MainActor
    func testTwoNearbySessionsExchangeMessage() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstStore = CommunicationStore(storageURL: directory.appendingPathComponent("a.json"))
        let secondStore = CommunicationStore(storageURL: directory.appendingPathComponent("b.json"))
        let first = NearbyChatService(store: firstStore, displayName: "Nearby test Alice")
        let second = NearbyChatService(store: secondStore, displayName: "Nearby test Bob")
        first.start()
        second.start()
        defer { first.stop(); second.stop() }
        let found = await waitUntil { !first.discoveredPeers.isEmpty }
        XCTAssertTrue(found, "The simulator did not discover the second nearby session")
        guard let peer = first.discoveredPeers.first else { return }
        first.invite(peer)
        let invited = await waitUntil { second.pendingInvitation != nil }
        XCTAssertTrue(invited)
        second.answerInvitation(accept: true)
        let connected = await waitUntil { !first.connectedPeers.isEmpty && !second.connectedPeers.isEmpty }
        XCTAssertTrue(connected)
        guard connected else { return }
        let outgoing = try first.send("I need water", pictureTokens: [
            PictureMessageToken(text: "water", symbol: "💧", imageData: nil)
        ], to: peer)
        XCTAssertEqual(outgoing.recipientName, peer.displayName)
        let received = await waitUntil { second.sessionMessages.contains(where: { $0.text == "I need water" }) }
        XCTAssertTrue(received)
        XCTAssertEqual(second.sessionMessages.first?.isMine, false)
        XCTAssertEqual(second.sessionMessages.first?.tokens.first?.text, "water")
        XCTAssertEqual(second.unreadCount, 1)
        second.markRead()
        XCTAssertEqual(second.unreadCount, 0)
    }

    @MainActor
    func testGroupChatCanSendToOnePartnerOrEveryone() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let alice = NearbyChatService(store: CommunicationStore(
            storageURL: directory.appendingPathComponent("alice.json")), displayName: "Nearby group Alice")
        let bob = NearbyChatService(store: CommunicationStore(
            storageURL: directory.appendingPathComponent("bob.json")), displayName: "Nearby group Bob")
        let cara = NearbyChatService(store: CommunicationStore(
            storageURL: directory.appendingPathComponent("cara.json")), displayName: "Nearby group Cara")
        alice.start()
        bob.start()
        cara.start()
        defer { alice.stop(); bob.stop(); cara.stop() }
        let discovered = await waitUntil { alice.discoveredPeers.count >= 2 }
        XCTAssertTrue(discovered)
        guard let bobPeer = alice.discoveredPeers.first(where: { $0.displayName == "Nearby group Bob" }),
              let caraPeer = alice.discoveredPeers.first(where: { $0.displayName == "Nearby group Cara" }) else {
            return XCTFail("Expected to find both partners")
        }
        alice.invite(bobPeer)
        alice.invite(caraPeer)
        let invited = await waitUntil { bob.pendingInvitation != nil && cara.pendingInvitation != nil }
        XCTAssertTrue(invited)
        bob.answerInvitation(accept: true)
        cara.answerInvitation(accept: true)
        let connected = await waitUntil { alice.connectedPeers.count == 2 }
        XCTAssertTrue(connected)
        guard connected else { return }
        try alice.send("For Bob", to: bobPeer)
        let bobReceived = await waitUntil { bob.sessionMessages.count == 1 }
        XCTAssertTrue(bobReceived)
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(cara.sessionMessages.isEmpty)
        try alice.send("For everyone")
        let bothReceived = await waitUntil { bob.sessionMessages.count == 2 && cara.sessionMessages.count == 1 }
        XCTAssertTrue(bothReceived)
        XCTAssertEqual(cara.sessionMessages.first?.text, "For everyone")
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }
}
