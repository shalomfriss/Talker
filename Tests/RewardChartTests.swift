import UIKit
import XCTest
@testable import OpenVoice

final class RewardChartTests: XCTestCase {
    @MainActor
    func testTokensCanBeChangedCollectedAndRetainedAfterChartDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let chart = try XCTUnwrap(store.addRewardChart(title: "A new activity", reward: "Choose a game",
                                                       symbol: "🐟", targetTokens: 3))
        XCTAssertFalse(store.setRewardChartTokens(id: chart.id, count: 4))
        XCTAssertTrue(store.setRewardChartTokens(id: chart.id, count: 2))
        XCTAssertTrue(store.setRewardChartTokens(id: chart.id, count: 1))
        XCTAssertNil(store.collectReward(id: chart.id))
        XCTAssertTrue(store.setRewardChartTokens(id: chart.id, count: 3))
        let collected = try XCTUnwrap(store.collectReward(id: chart.id))
        XCTAssertEqual(collected.chartTitle, "A new activity")
        XCTAssertEqual(collected.reward, "Choose a game")
        XCTAssertEqual(store.rewardCharts[0].earnedTokens, 0)
        XCTAssertEqual(store.rewardCollectibles.map(\.id), [collected.id])
        XCTAssertTrue(store.deleteRewardChart(id: chart.id))
        XCTAssertTrue(store.rewardCharts.isEmpty)
        XCTAssertEqual(store.rewardCollectibles.first?.reward, "Choose a game")
        XCTAssertTrue(store.deleteRewardCollectible(id: collected.id))
        XCTAssertTrue(store.rewardCollectibles.isEmpty)
    }

    @MainActor
    func testChartPhotoAndCollectionStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: url)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.blue.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let photo = try XCTUnwrap(image.pngData())
        let chart = try XCTUnwrap(source.addRewardChart(title: "Try a game", reward: "Pick music",
                                                        targetTokens: 2, photoData: photo))
        XCTAssertTrue(source.setRewardChartTokens(id: chart.id, count: 2))
        XCTAssertNotNil(source.collectReward(id: chart.id))
        XCTAssertEqual(source.rewardCollectibles.first?.photoData, photo)
        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertTrue(source.rewardCharts.isEmpty)
        XCTAssertTrue(source.rewardCollectibles.isEmpty)
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.rewardCharts.first?.photoData, photo)
        XCTAssertEqual(CommunicationStore(storageURL: url).rewardCollectibles.first?.reward, "Pick music")
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.rewardCharts.first?.photoData, photo)
        XCTAssertEqual(restored.rewardCollectibles.first?.photoData, photo)
    }

    @MainActor
    func testEditingTargetClampsProgressAndResetDoesNotCollect() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let chart = try XCTUnwrap(store.addRewardChart(title: "  Practice  ", reward: "  A rest  ",
                                                       targetTokens: 5))
        XCTAssertEqual(chart.title, "Practice")
        XCTAssertTrue(store.setRewardChartTokens(id: chart.id, count: 4))
        let edited = RewardChart(id: chart.id, title: "Practice", reward: "A rest", targetTokens: 2)
        XCTAssertTrue(store.updateRewardChart(edited))
        XCTAssertEqual(store.rewardCharts.first?.earnedTokens, 2)
        XCTAssertTrue(store.startRewardChartAgain(id: chart.id))
        XCTAssertEqual(store.rewardCharts.first?.earnedTokens, 0)
        XCTAssertTrue(store.rewardCollectibles.isEmpty)
        XCTAssertNil(store.addRewardChart(title: " ", reward: "Something"))
    }

    func testOlderProfileDataDefaultsToNoRewardCharts() throws {
        let stored = StoredData(items: StarterVocabulary.items, routines: [], phrases: [], settings: AppSettings())
        let encoded = try JSONEncoder().encode(stored)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "rewardCharts")
        object.removeValue(forKey: "rewardCollectibles")
        let older = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(StoredData.self, from: older)
        XCTAssertTrue(decoded.rewardCharts.isEmpty)
        XCTAssertTrue(decoded.rewardCollectibles.isEmpty)
    }
}
