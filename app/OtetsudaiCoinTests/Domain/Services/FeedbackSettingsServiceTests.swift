import XCTest
@testable import OtetsudaiCoin

final class FeedbackSettingsServiceTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // グローバルな UserDefaults.standard を汚さないよう suite を分離する
        suiteName = "FeedbackSettingsServiceTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_defaults_areBothEnabled() {
        let service = FeedbackSettingsService(userDefaults: userDefaults)

        XCTAssertTrue(service.isSoundEnabled, "未保存時のサウンド既定値は true であるべき")
        XCTAssertTrue(service.isHapticEnabled, "未保存時のハプティクス既定値は true であるべき")
    }

    func test_setValues_arePersistedToUserDefaults() {
        let service = FeedbackSettingsService(userDefaults: userDefaults)

        service.isSoundEnabled = false
        service.isHapticEnabled = false

        XCTAssertFalse(userDefaults.bool(forKey: "sound_enabled"))
        XCTAssertFalse(userDefaults.bool(forKey: "haptic_enabled"))
    }

    func test_newInstance_readsStoredValues() {
        let first = FeedbackSettingsService(userDefaults: userDefaults)
        first.isHapticEnabled = false

        let second = FeedbackSettingsService(userDefaults: userDefaults)

        XCTAssertFalse(second.isHapticEnabled)
        XCTAssertTrue(second.isSoundEnabled, "触っていない側は既定値のままであるべき")
    }

    /// 回帰ガード: 値を init で読んで stored property に持つ方式へ退行すると落ちる。
    /// アプリ上では「設定画面で OFF にしても記録画面は再起動まで ON のまま」という形で
    /// 現れるが、単一インスタンスしか触らない他のテストは全て green のまま素通りする。
    func test_liveInstance_seesWriteFromAnotherInstance() {
        let recordSide = FeedbackSettingsService(userDefaults: userDefaults)
        let settingsSide = FeedbackSettingsService(userDefaults: userDefaults)
        XCTAssertTrue(recordSide.isHapticEnabled)

        settingsSide.isHapticEnabled = false

        XCTAssertFalse(
            recordSide.isHapticEnabled,
            "別インスタンスの書き込みが即座に読めていない (値をキャッシュしている)"
        )
    }
}
