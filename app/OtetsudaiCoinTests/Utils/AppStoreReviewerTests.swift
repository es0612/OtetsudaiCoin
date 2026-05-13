import XCTest
@testable import OtetsudaiCoin

final class AppStoreReviewerTests: XCTestCase {

    func testWriteReviewURLForValidNumericIDReturnsAppStoreURL() {
        let url = AppStoreReviewer.writeReviewURL(for: "6443148999")

        XCTAssertNotNil(url)
        XCTAssertEqual(
            url?.absoluteString,
            "itms-apps://itunes.apple.com/app/id6443148999?action=write-review"
        )
    }

    func testWriteReviewURLForEmptyStringReturnsNil() {
        XCTAssertNil(AppStoreReviewer.writeReviewURL(for: ""))
    }

    func testWriteReviewURLForWhitespaceOnlyReturnsNil() {
        XCTAssertNil(AppStoreReviewer.writeReviewURL(for: "   "))
    }

    // placeholder 文字列（"REPLACE_WITH_REAL_APPLE_APP_ID" 等の英数字混在）が
    // 誤って残った場合に App Store に飛ばさないためのガード。
    func testWriteReviewURLForNonNumericReturnsNil() {
        XCTAssertNil(AppStoreReviewer.writeReviewURL(for: "REPLACE_WITH_REAL_APPLE_APP_ID"))
        XCTAssertNil(AppStoreReviewer.writeReviewURL(for: "id-1234"))
    }

    // 本番 App Store Connect で発行された Apple ID。Build Settings に必ず反映されている
    // ことを保証し、空文字 placeholder への巻き戻しや typo を検出するためのリグレッションテスト。
    func testDebugConfigurationUsesProductionAppStoreAppID() {
        XCTAssertEqual(AppStoreReviewer.appStoreAppID, "6747692379")
    }

    func testAppStoreAppIDReadsFromInfoPlist() {
        // ビルド設定の APP_STORE_APP_ID が Info.plist 経由で読めること。
        // placeholder 未設定なら空文字、本番 ID 設定済みなら数字列のみが返る。
        let id = AppStoreReviewer.appStoreAppID
        XCTAssertEqual(id, id.trimmingCharacters(in: .whitespacesAndNewlines))
        if !id.isEmpty {
            XCTAssertTrue(id.allSatisfy(\.isNumber), "APP_STORE_APP_ID は数字のみであるべき")
        }
    }
}
