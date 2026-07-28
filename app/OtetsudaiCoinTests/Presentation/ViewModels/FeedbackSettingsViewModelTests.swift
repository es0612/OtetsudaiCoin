import XCTest
@testable import OtetsudaiCoin

final class FeedbackSettingsViewModelTests: XCTestCase {

    @MainActor
    func test_initialState_reflectsService() {
        let fake = FakeFeedbackSettingsService(isSoundEnabled: false, isHapticEnabled: true)

        let viewModel = FeedbackSettingsViewModel(service: fake)

        XCTAssertFalse(viewModel.isSoundEnabled)
        XCTAssertTrue(viewModel.isHapticEnabled)
    }

    @MainActor
    func test_togglingSound_writesThroughToService() {
        let fake = FakeFeedbackSettingsService()
        let viewModel = FeedbackSettingsViewModel(service: fake)

        viewModel.isSoundEnabled = false

        XCTAssertFalse(fake.isSoundEnabled, "トグル操作が設定サービスへ反映されていない")
        XCTAssertTrue(fake.isHapticEnabled, "触っていない側は変わらないべき")
    }

    @MainActor
    func test_togglingHaptic_writesThroughToService() {
        let fake = FakeFeedbackSettingsService()
        let viewModel = FeedbackSettingsViewModel(service: fake)

        viewModel.isHapticEnabled = false

        XCTAssertFalse(fake.isHapticEnabled)
        XCTAssertTrue(fake.isSoundEnabled)
    }
}
