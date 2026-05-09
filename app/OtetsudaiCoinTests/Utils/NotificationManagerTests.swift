import XCTest
@testable import OtetsudaiCoin

final class NotificationManagerTests: XCTestCase {

    func testNavigateToHomeNotificationNameExists() {
        let name = Notification.Name.navigateToHome

        XCTAssertEqual(name.rawValue, "navigateToHome")
    }
}
