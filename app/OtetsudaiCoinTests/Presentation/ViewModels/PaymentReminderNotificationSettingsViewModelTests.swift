import XCTest
@testable import OtetsudaiCoin

final class PaymentReminderNotificationSettingsViewModelTests: XCTestCase {

    private var mockService: MockPaymentReminderNotificationService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockService = MockPaymentReminderNotificationService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    @MainActor
    func testInitialStateReflectsServiceDisabled() {
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)
        XCTAssertFalse(vm.isEnabled)
    }

    @MainActor
    func testInitialStateReflectsServiceEnabled() {
        mockService.isEnabled = true
        mockService.reminderHour = 10
        mockService.reminderMinute = 30
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)
        XCTAssertTrue(vm.isEnabled)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: vm.reminderTime)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 30)
    }

    @MainActor
    func testToggleOnRequestsAuthorizationAndSchedules() async {
        mockService.authorizationResult = true
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        await vm.toggleNotification(enabled: true)

        XCTAssertEqual(mockService.requestAuthorizationCallCount, 1)
        XCTAssertTrue(mockService.isEnabled)
        XCTAssertEqual(mockService.rescheduleCallCount, 1)
        XCTAssertTrue(vm.isEnabled)
    }

    @MainActor
    func testToggleOnAuthorizationDeniedKeepsDisabled() async {
        mockService.authorizationResult = false
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        await vm.toggleNotification(enabled: true)

        XCTAssertFalse(mockService.isEnabled)
        XCTAssertEqual(mockService.rescheduleCallCount, 0)
        XCTAssertFalse(vm.isEnabled)
    }

    @MainActor
    func testToggleOnRescheduleErrorRevertsState() async {
        mockService.authorizationResult = true
        mockService.rescheduleError = NSError(domain: "test", code: 1)
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        await vm.toggleNotification(enabled: true)

        XCTAssertFalse(vm.isEnabled)
        XCTAssertFalse(mockService.isEnabled)
        XCTAssertNotNil(vm.scheduleError)
    }

    @MainActor
    func testToggleOffCancelsAndDisables() async {
        mockService.isEnabled = true
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        await vm.toggleNotification(enabled: false)

        XCTAssertFalse(mockService.isEnabled)
        XCTAssertEqual(mockService.cancelAllCallCount, 1)
        XCTAssertFalse(vm.isEnabled)
    }

    @MainActor
    func testUpdateReminderTimeUpdatesServiceAndReschedulesWhenEnabled() async {
        mockService.isEnabled = true
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        var comps = DateComponents()
        comps.hour = 7
        comps.minute = 45
        let newTime = Calendar.current.date(from: comps)!
        await vm.updateReminderTime(newTime)

        XCTAssertEqual(mockService.reminderHour, 7)
        XCTAssertEqual(mockService.reminderMinute, 45)
        XCTAssertEqual(mockService.rescheduleCallCount, 1)
    }

    @MainActor
    func testUpdateReminderTimeDoesNotRescheduleWhenDisabled() async {
        mockService.isEnabled = false
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        var comps = DateComponents()
        comps.hour = 7
        let newTime = Calendar.current.date(from: comps)!
        await vm.updateReminderTime(newTime)

        XCTAssertEqual(mockService.rescheduleCallCount, 0)
    }
}
