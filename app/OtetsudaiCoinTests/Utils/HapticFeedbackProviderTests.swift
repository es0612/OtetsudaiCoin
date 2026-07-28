import XCTest
@testable import OtetsudaiCoin

final class HapticFeedbackProviderTests: XCTestCase {

    @MainActor
    func test_mockProvider_countsEachChannelIndependently() {
        let mock = MockHapticFeedbackProvider()

        mock.helpRecorded()
        mock.helpRecorded()
        mock.taskSelection()

        XCTAssertEqual(mock.helpRecordedCallCount, 2)
        XCTAssertEqual(mock.taskSelectionCallCount, 1)
        XCTAssertEqual(mock.childSelectionCallCount, 0)
        XCTAssertEqual(mock.errorOccurredCallCount, 0)
    }

    func test_fakeSettings_defaultsToBothEnabled() {
        let fake = FakeFeedbackSettingsService()

        XCTAssertTrue(fake.isSoundEnabled)
        XCTAssertTrue(fake.isHapticEnabled)
    }
}
