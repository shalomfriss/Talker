import AVFoundation
import XCTest
@testable import OpenVoice

final class CallAudioManagerTests: XCTestCase {
    @MainActor
    func testTurningCallAudioOffDoesNotNeedCallPermission() async {
        let manager = CallAudioManager()
        await manager.setEnabled(false)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertEqual(AVAudioSession.sharedInstance().preferredMicrophoneInjectionMode, .none)
        XCTAssertNil(manager.errorMessage)
    }
}
