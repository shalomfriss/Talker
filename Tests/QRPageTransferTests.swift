import XCTest
@testable import OpenVoice

final class QRPageTransferTests: XCTestCase {
    @MainActor
    func testQRPagePreservesVocabularyAndTranslationsAcrossProfiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(source.addBoard("My requests"))
        XCTAssertTrue(source.setBoardIcon("🗣️", for: "My requests"))
        source.addItem(label: "Please wait", symbol: "⏳", message: "Please wait for me",
                       category: "My requests", imageData: nil, action: .speakImmediately,
                       spanishLabel: "Espera, por favor", spanishMessage: "Espera por mí, por favor",
                       visibility: .dimmed, backgroundColorHex: "#AABBCC")
        source.addItem(label: "I need a break", symbol: "⏸️", message: "I need a break",
                       category: "My requests", imageData: nil)
        let code = try source.qrCodeForBoard("My requests")
        XCTAssertTrue(code.hasPrefix(QRPageTransfer.prefix))
        XCTAssertLessThanOrEqual(code.utf8.count, QRPageTransfer.maxCodeBytes)
        let page = try QRPageTransfer.decode(code)
        XCTAssertEqual(page.title, "My requests")
        XCTAssertEqual(page.icon, "🗣️")
        XCTAssertEqual(page.tiles.count, 2)
        XCTAssertEqual(page.tiles[0].spanish?.label, "Espera, por favor")
        XCTAssertEqual(page.tiles[0].action, .speakImmediately)
        XCTAssertEqual(page.tiles[0].visibility, .dimmed)
        XCTAssertEqual(page.tiles[0].backgroundColorHex, "#AABBCC")

        let targetURL = directory.appendingPathComponent("target.json")
        let target = CommunicationStore(storageURL: targetURL)
        XCTAssertEqual(target.addQRPage(page), "My requests")
        XCTAssertEqual(target.addQRPage(page), "My requests (imported 2)")
        XCTAssertEqual(target.boardIcon(for: "My requests"), "🗣️")
        let copied = try XCTUnwrap(target.items.first { $0.category == "My requests" && $0.label == "Please wait" })
        XCTAssertTrue(copied.isCustom)
        XCTAssertEqual(copied.message, "Please wait for me")
        XCTAssertEqual(copied.action, .speakImmediately)
        XCTAssertEqual(copied.boardVisibility, .dimmed)
        XCTAssertEqual(target.translation(for: copied)?.message, "Espera por mí, por favor")
        XCTAssertTrue(CommunicationStore(storageURL: targetURL).categories.contains("My requests"))
        XCTAssertFalse(source.categories.contains("My requests (imported 2)"))
    }

    @MainActor
    func testQRImageIsRecognizedAndDecodes() throws {
        let item = CommunicationItem(label: "Help", symbol: "🙋", message: "I need help", category: "Help")
        let code = try QRPageTransfer.encode(title: "Help", icon: "🆘", items: [item], translations: [:])
        let image = try QRPageImage.make(code)
        let data = try XCTUnwrap(image.pngData())
        let recognized = try QRPageImage.read(from: data)
        XCTAssertEqual(recognized, code)
        XCTAssertEqual(try QRPageTransfer.decode(recognized).tiles.first?.label, "Help")
    }

    @MainActor
    func testQRRejectsMediaLinksAndInvalidCodes() throws {
        let plain = CommunicationItem(label: "Hello", symbol: "👋", message: "Hello", category: "My board")
        var photo = plain
        photo.imageData = Data([1, 2, 3])
        XCTAssertThrowsError(try QRPageTransfer.encode(title: "My board", icon: nil,
                                                       items: [photo], translations: [:]))
        var linked = plain
        linked.destinationBoard = "Other board"
        XCTAssertThrowsError(try QRPageTransfer.encode(title: "My board", icon: nil,
                                                       items: [linked], translations: [:]))
        var video = plain
        video.action = .playVideo
        video.videoData = Data([1, 2, 3])
        video.videoPosterData = Data([4])
        XCTAssertThrowsError(try QRPageTransfer.encode(title: "My board", icon: nil,
                                                       items: [video], translations: [:]))
        XCTAssertThrowsError(try QRPageTransfer.decode("https://example.com"))
        XCTAssertThrowsError(try QRPageTransfer.decode("OVQR1:broken"))
        let code = try QRPageTransfer.encode(title: "My board", icon: nil,
                                              items: [plain], translations: [:])
        XCTAssertThrowsError(try QRPageTransfer.decode(code + String(repeating: "x", count: 3_000)))
    }

    @MainActor
    func testStarterNeedsBoardFitsOneScannableCode() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let code = try store.qrCodeForBoard("Needs")
        let page = try QRPageTransfer.decode(code)
        XCTAssertEqual(page.tiles.count, store.items.filter { $0.category == "Needs" }.count)
        XCTAssertEqual(try QRPageImage.read(from: XCTUnwrap(QRPageImage.make(code).pngData())), code)
    }
}
