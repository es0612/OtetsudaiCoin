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

    @MainActor
    func testHandlePaymentReminderTapPostsNavigateToHome() {
        let expectation = expectation(forNotification: .navigateToHome, object: nil)

        appDelegate.handleNotificationTap(identifier: "payment-reminder")

        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor
    func testHandleDailyReminderTapPostsNavigateToRecord() {
        let expectation = expectation(forNotification: .navigateToRecord, object: nil)

        appDelegate.handleNotificationTap(identifier: "daily-reminder")

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Notification.Name の定義確認

    func testNavigateToRecordNotificationNameExists() {
        let name = Notification.Name.navigateToRecord
        XCTAssertFalse(name.rawValue.isEmpty)
    }
}
