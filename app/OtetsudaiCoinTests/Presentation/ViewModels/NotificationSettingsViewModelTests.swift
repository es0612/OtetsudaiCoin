import XCTest
@testable import OtetsudaiCoin

final class NotificationSettingsViewModelTests: XCTestCase {

    private var mockService: MockReminderNotificationService!
    private var viewModel: NotificationSettingsViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        mockService = MockReminderNotificationService()
        viewModel = NotificationSettingsViewModel(service: mockService)
    }

    override func tearDown() {
        viewModel = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: - 初期状態

    @MainActor
    func testInitialStateReflectsServiceDisabled() {
        // Given: サービスで通知が無効

        // Then: ViewModel も無効状態を反映する
        XCTAssertFalse(viewModel.isEnabled)
    }

    @MainActor
    func testInitialStateReflectsServiceEnabled() {
        // Given: サービスで通知が有効
        mockService.isEnabled = true
        mockService.reminderHour = 20
        mockService.reminderMinute = 30

        // When: ViewModel を作成する
        let vm = NotificationSettingsViewModel(service: mockService)

        // Then: サービスの状態が反映される
        XCTAssertTrue(vm.isEnabled)
    }

    @MainActor
    func testInitialReminderTimeReflectsService() {
        // Given: サービスに時間が設定されている
        mockService.reminderHour = 20
        mockService.reminderMinute = 30

        // When: ViewModel を作成する
        let vm = NotificationSettingsViewModel(service: mockService)

        // Then: reminderTime が 20:30 を表す Date になる
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: vm.reminderTime)
        XCTAssertEqual(components.hour, 20)
        XCTAssertEqual(components.minute, 30)
    }

    // MARK: - 通知トグル ON

    @MainActor
    func testToggleOnRequestsAuthorization() async {
        // Given: 通知が無効の状態
        mockService.authorizationResult = true

        // When: 通知を有効にする
        await viewModel.toggleNotification(enabled: true)

        // Then: 権限リクエストが呼ばれる
        XCTAssertEqual(mockService.requestAuthorizationCallCount, 1)
    }

    @MainActor
    func testToggleOnWithAuthorizationGrantedEnablesAndSchedules() async {
        // Given: 権限が許可される
        mockService.authorizationResult = true

        // When: 通知を有効にする
        await viewModel.toggleNotification(enabled: true)

        // Then: サービスが有効化され、スケジュールされる
        XCTAssertTrue(mockService.isEnabled)
        XCTAssertEqual(mockService.scheduleDailyCallCount, 1)
    }

    @MainActor
    func testToggleOnWithAuthorizationDeniedDoesNotEnable() async {
        // Given: 権限が拒否される
        mockService.authorizationResult = false

        // When: 通知を有効にしようとする
        await viewModel.toggleNotification(enabled: true)

        // Then: サービスは無効のまま、スケジュールされない
        XCTAssertFalse(mockService.isEnabled)
        XCTAssertEqual(mockService.scheduleDailyCallCount, 0)
    }

    @MainActor
    func testToggleOnWithAuthorizationDeniedUpdatesViewModelState() async {
        // Given: 権限が拒否される
        mockService.authorizationResult = false

        // When: 通知を有効にしようとする
        await viewModel.toggleNotification(enabled: true)

        // Then: ViewModel の isEnabled も false に戻る
        XCTAssertFalse(viewModel.isEnabled)
    }

    @MainActor
    func testToggleOnWithScheduleErrorRevertsState() async {
        // Given: 権限は許可されるがスケジュールが失敗する
        mockService.authorizationResult = true
        mockService.scheduleDailyError = NSError(domain: "test", code: 1)

        // When: 通知を有効にしようとする
        await viewModel.toggleNotification(enabled: true)

        // Then: エラーにより無効状態に戻る
        XCTAssertFalse(viewModel.isEnabled)
        XCTAssertFalse(mockService.isEnabled)
        XCTAssertNotNil(viewModel.scheduleError)
    }

    // MARK: - 通知トグル OFF

    @MainActor
    func testToggleOffDisablesAndCancels() async {
        // Given: 通知が有効の状態
        mockService.isEnabled = true
        mockService.authorizationResult = true
        let vm = NotificationSettingsViewModel(service: mockService)

        // When: 通知を無効にする
        await vm.toggleNotification(enabled: false)

        // Then: サービスが無効化され、通知がキャンセルされる
        XCTAssertFalse(mockService.isEnabled)
        XCTAssertEqual(mockService.cancelAllCallCount, 1)
    }

    @MainActor
    func testToggleOffDoesNotRequestAuthorization() async {
        // Given: 通知が有効の状態
        mockService.isEnabled = true
        let vm = NotificationSettingsViewModel(service: mockService)

        // When: 通知を無効にする
        await vm.toggleNotification(enabled: false)

        // Then: 権限リクエストは呼ばれない
        XCTAssertEqual(mockService.requestAuthorizationCallCount, 0)
    }

    // MARK: - 通知時間の変更

    @MainActor
    func testUpdateReminderTimeUpdatesService() async {
        // Given: デフォルト時間の状態
        var components = DateComponents()
        components.hour = 20
        components.minute = 30
        let newTime = Calendar.current.date(from: components)!

        // When: 時間を変更する
        await viewModel.updateReminderTime(newTime)

        // Then: サービスの時間が更新される
        XCTAssertEqual(mockService.reminderHour, 20)
        XCTAssertEqual(mockService.reminderMinute, 30)
    }

    @MainActor
    func testUpdateReminderTimeReschedulesWhenEnabled() async {
        // Given: 通知が有効の状態
        mockService.isEnabled = true
        let vm = NotificationSettingsViewModel(service: mockService)

        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        let newTime = Calendar.current.date(from: components)!

        // When: 時間を変更する
        await vm.updateReminderTime(newTime)

        // Then: リスケジュールが呼ばれる
        XCTAssertEqual(mockService.rescheduleCallCount, 1)
    }

    @MainActor
    func testUpdateReminderTimeDoesNotRescheduleWhenDisabled() async {
        // Given: 通知が無効の状態

        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        let newTime = Calendar.current.date(from: components)!

        // When: 時間を変更する
        await viewModel.updateReminderTime(newTime)

        // Then: リスケジュールは呼ばれない
        XCTAssertEqual(mockService.rescheduleCallCount, 0)
    }

    // MARK: - 時間変換の境界値

    @MainActor
    func testUpdateReminderTimeMidnight() async {
        // Given: 0:00 の Date を作成
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        let midnight = Calendar.current.date(from: components)!

        // When: 0:00 に変更する
        await viewModel.updateReminderTime(midnight)

        // Then: 0:00 がサービスに設定される
        XCTAssertEqual(mockService.reminderHour, 0)
        XCTAssertEqual(mockService.reminderMinute, 0)
    }

    @MainActor
    func testUpdateReminderTimeEndOfDay() async {
        // Given: 23:59 の Date を作成
        var components = DateComponents()
        components.hour = 23
        components.minute = 59
        let endOfDay = Calendar.current.date(from: components)!

        // When: 23:59 に変更する
        await viewModel.updateReminderTime(endOfDay)

        // Then: 23:59 がサービスに設定される
        XCTAssertEqual(mockService.reminderHour, 23)
        XCTAssertEqual(mockService.reminderMinute, 59)
    }

    // MARK: - reminderTime プロパティ

    @MainActor
    func testReminderTimeDefaultIs18_00() {
        // Given: デフォルト状態のViewModel

        // Then: reminderTime が 18:00 を表す
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: viewModel.reminderTime)
        XCTAssertEqual(components.hour, 18)
        XCTAssertEqual(components.minute, 0)
    }
}
