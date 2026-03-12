import XCTest
import UserNotifications
@testable import OtetsudaiCoin

final class AppDelegateTests: XCTestCase {

    private var appDelegate: AppDelegate!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
    }

    override func tearDown() {
        appDelegate = nil
        super.tearDown()
    }

    // MARK: - 通知タップ時の画面遷移イベント

    /// AppDelegate.handleNotificationTap() が .navigateToRecord を発火することを検証
    func testHandleNotificationTapPostsNavigateToRecord() {
        // Given: navigateToRecord 通知の監視を設定
        let expectation = XCTestExpectation(
            description: "navigateToRecord 通知が発火される"
        )

        let observer = NotificationCenter.default.addObserver(
            forName: .navigateToRecord,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // When: 通知タップハンドラが呼ばれる
        appDelegate.handleNotificationTap()

        // Then: navigateToRecord 通知が発火される
        wait(for: [expectation], timeout: 2.0)

        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Notification.Name の定義確認

    func testNavigateToRecordNotificationNameExists() {
        // Given/When: Notification.Name.navigateToRecord にアクセス
        let name = Notification.Name.navigateToRecord

        // Then: 名前が定義されている
        XCTAssertFalse(name.rawValue.isEmpty)
    }
}
