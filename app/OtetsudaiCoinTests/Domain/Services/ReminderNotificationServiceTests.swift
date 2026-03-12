import XCTest
import UserNotifications
@testable import OtetsudaiCoin

final class ReminderNotificationServiceTests: XCTestCase {

    private var service: ReminderNotificationService!
    private var mockNotificationCenter: MockNotificationCenter!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // テスト用の独立した UserDefaults を使用
        userDefaults = UserDefaults(suiteName: "ReminderNotificationServiceTests")!
        userDefaults.removePersistentDomain(forName: "ReminderNotificationServiceTests")
        mockNotificationCenter = MockNotificationCenter()
        service = ReminderNotificationService(
            notificationCenter: mockNotificationCenter,
            userDefaults: userDefaults
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "ReminderNotificationServiceTests")
        service = nil
        mockNotificationCenter = nil
        userDefaults = nil
        super.tearDown()
    }

    // MARK: - デフォルト値

    func testDefaultValues() {
        // Given: 初期化直後のサービス

        // Then: デフォルト値が設定されている
        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.reminderHour, 18)
        XCTAssertEqual(service.reminderMinute, 0)
    }

    // MARK: - UserDefaults 永続化

    func testIsEnabledPersistsToUserDefaults() {
        // Given: 通知が無効の状態

        // When: 通知を有効にする
        service.isEnabled = true

        // Then: UserDefaults に保存されている
        XCTAssertTrue(userDefaults.bool(forKey: "reminderNotificationEnabled"))
    }

    func testReminderHourPersistsToUserDefaults() {
        // Given: デフォルト時間の状態

        // When: 時間を変更する
        service.reminderHour = 20

        // Then: UserDefaults に保存されている
        XCTAssertEqual(userDefaults.integer(forKey: "reminderNotificationHour"), 20)
    }

    func testReminderMinutePersistsToUserDefaults() {
        // Given: デフォルト分の状態

        // When: 分を変更する
        service.reminderMinute = 30

        // Then: UserDefaults に保存されている
        XCTAssertEqual(userDefaults.integer(forKey: "reminderNotificationMinute"), 30)
    }

    func testLoadsPersistedValuesOnInit() {
        // Given: UserDefaults に保存済みの値がある
        userDefaults.set(true, forKey: "reminderNotificationEnabled")
        userDefaults.set(20, forKey: "reminderNotificationHour")
        userDefaults.set(45, forKey: "reminderNotificationMinute")

        // When: 新しいインスタンスを作成する
        let newService = ReminderNotificationService(
            notificationCenter: mockNotificationCenter,
            userDefaults: userDefaults
        )

        // Then: 保存済みの値がロードされる
        XCTAssertTrue(newService.isEnabled)
        XCTAssertEqual(newService.reminderHour, 20)
        XCTAssertEqual(newService.reminderMinute, 45)
    }

    // MARK: - 権限リクエスト

    func testRequestAuthorizationGranted() async {
        // Given: ユーザーが権限を許可する
        mockNotificationCenter.grantResult = true

        // When: 権限をリクエストする
        let result = await service.requestAuthorization()

        // Then: true が返り、リクエストが1回呼ばれる
        XCTAssertTrue(result)
        XCTAssertEqual(mockNotificationCenter.requestAuthorizationCallCount, 1)
    }

    func testRequestAuthorizationDenied() async {
        // Given: ユーザーが権限を拒否する
        mockNotificationCenter.grantResult = false

        // When: 権限をリクエストする
        let result = await service.requestAuthorization()

        // Then: false が返る
        XCTAssertFalse(result)
        XCTAssertEqual(mockNotificationCenter.requestAuthorizationCallCount, 1)
    }

    // MARK: - 通知スケジュール

    func testScheduleDailyCreatesNotificationRequest() async throws {
        // Given: 通知時間が設定されている
        service.reminderHour = 19
        service.reminderMinute = 30

        // When: 毎日の通知をスケジュールする
        try await service.scheduleDaily()

        // Then: 通知リクエストが追加される
        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)
    }

    func testScheduleDailyUsesCorrectIdentifier() async throws {
        // Given: サービスが初期化されている

        // When: 毎日の通知をスケジュールする
        try await service.scheduleDaily()

        // Then: 通知識別子が "daily-reminder" である
        XCTAssertEqual(mockNotificationCenter.addedRequests.count, 1)
        XCTAssertEqual(
            mockNotificationCenter.addedRequests.first?.identifier,
            "daily-reminder"
        )
    }

    func testScheduleDailySetsCorrectContent() async throws {
        // Given: サービスが初期化されている

        // When: 毎日の通知をスケジュールする
        try await service.scheduleDaily()

        // Then: 通知内容が正しく設定されている
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertEqual(request?.content.title, "おてつだいコイン")
        XCTAssertEqual(request?.content.body, "今日のお手伝いを記録しよう！🌟")
        XCTAssertNotNil(request?.content.sound)
    }

    func testScheduleDailySetsCorrectTriggerTime() async throws {
        // Given: 通知時間を 19:30 に設定
        service.reminderHour = 19
        service.reminderMinute = 30

        // When: 毎日の通知をスケジュールする
        try await service.scheduleDaily()

        // Then: トリガーが指定時刻の繰り返しカレンダートリガーである
        let request = mockNotificationCenter.addedRequests.first
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.dateComponents.hour, 19)
        XCTAssertEqual(trigger?.dateComponents.minute, 30)
        XCTAssertTrue(trigger?.repeats ?? false)
    }

    func testScheduleDailyWithDefaultTime() async throws {
        // Given: デフォルト時間（18:00）のまま

        // When: 毎日の通知をスケジュールする
        try await service.scheduleDaily()

        // Then: トリガーが 18:00 に設定されている
        let trigger = mockNotificationCenter.addedRequests.first?.trigger
            as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 18)
        XCTAssertEqual(trigger?.dateComponents.minute, 0)
    }

    func testScheduleDailyThrowsOnError() async {
        // Given: 通知センターがエラーを返す
        let expectedError = NSError(domain: "test", code: 1)
        mockNotificationCenter.addError = expectedError

        // When/Then: scheduleDaily がエラーをスローする
        do {
            try await service.scheduleDaily()
            XCTFail("エラーがスローされるべき")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }

    // MARK: - 通知キャンセル

    func testCancelAllRemovesPendingNotifications() {
        // Given: サービスが初期化されている

        // When: すべての通知をキャンセルする
        service.cancelAll()

        // Then: 通知センターの削除メソッドが呼ばれる
        XCTAssertEqual(mockNotificationCenter.removeCallCount, 1)
        XCTAssertTrue(
            mockNotificationCenter.removedIdentifiers.contains("daily-reminder")
        )
    }

    // MARK: - リスケジュール

    func testRescheduleCancelsAndSchedules() async throws {
        // Given: サービスが初期化されている

        // When: リスケジュールする
        try await service.reschedule()

        // Then: キャンセル後にスケジュールが呼ばれる
        XCTAssertEqual(mockNotificationCenter.removeCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)
    }

    func testRescheduleUsesUpdatedTime() async throws {
        // Given: 時間を変更する
        service.reminderHour = 7
        service.reminderMinute = 15

        // When: リスケジュールする
        try await service.reschedule()

        // Then: 新しい時間でスケジュールされる
        let trigger = mockNotificationCenter.addedRequests.first?.trigger
            as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 7)
        XCTAssertEqual(trigger?.dateComponents.minute, 15)
    }

    // MARK: - 境界値

    func testReminderHourBoundary_Midnight() async throws {
        // Given: 0時に設定

        // When: 0:00 に設定してスケジュール
        service.reminderHour = 0
        service.reminderMinute = 0
        try await service.scheduleDaily()

        // Then: 0:00 のトリガーが作成される
        let trigger = mockNotificationCenter.addedRequests.first?.trigger
            as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 0)
        XCTAssertEqual(trigger?.dateComponents.minute, 0)
    }

    func testReminderHourBoundary_EndOfDay() async throws {
        // Given: 23:59 に設定

        // When: 23:59 に設定してスケジュール
        service.reminderHour = 23
        service.reminderMinute = 59
        try await service.scheduleDaily()

        // Then: 23:59 のトリガーが作成される
        let trigger = mockNotificationCenter.addedRequests.first?.trigger
            as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 23)
        XCTAssertEqual(trigger?.dateComponents.minute, 59)
    }
}
