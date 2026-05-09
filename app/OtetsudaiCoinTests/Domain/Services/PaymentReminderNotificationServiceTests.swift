import XCTest
import UserNotifications
@testable import OtetsudaiCoin

final class PaymentReminderNotificationServiceTests: XCTestCase {

    private var service: PaymentReminderNotificationService!
    private var mockNotificationCenter: MockNotificationCenter!
    private var userDefaults: UserDefaults!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockAllowancePaymentRepository: MockAllowancePaymentRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var unpaidDetector: UnpaidAllowanceDetectorService!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "PaymentReminderNotificationServiceTests")!
        userDefaults.removePersistentDomain(forName: "PaymentReminderNotificationServiceTests")
        mockNotificationCenter = MockNotificationCenter()
        mockChildRepository = MockChildRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockAllowancePaymentRepository = MockAllowancePaymentRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        unpaidDetector = UnpaidAllowanceDetectorService()
        service = PaymentReminderNotificationService(
            notificationCenter: mockNotificationCenter,
            userDefaults: userDefaults,
            unpaidDetector: unpaidDetector,
            childRepository: mockChildRepository,
            helpRecordRepository: mockHelpRecordRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            helpTaskRepository: mockHelpTaskRepository
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "PaymentReminderNotificationServiceTests")
        service = nil
        mockNotificationCenter = nil
        userDefaults = nil
        mockChildRepository = nil
        mockHelpRecordRepository = nil
        mockAllowancePaymentRepository = nil
        mockHelpTaskRepository = nil
        unpaidDetector = nil
        super.tearDown()
    }

    // MARK: - デフォルト値

    func testDefaultValues() {
        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.reminderHour, 9)
        XCTAssertEqual(service.reminderMinute, 0)
    }

    // MARK: - UserDefaults 永続化

    func testIsEnabledPersistsToUserDefaults() {
        service.isEnabled = true
        XCTAssertTrue(userDefaults.bool(forKey: "paymentReminderNotificationEnabled"))
    }

    func testReminderHourPersistsToUserDefaults() {
        service.reminderHour = 10
        XCTAssertEqual(userDefaults.integer(forKey: "paymentReminderNotificationHour"), 10)
    }

    func testReminderMinutePersistsToUserDefaults() {
        service.reminderMinute = 30
        XCTAssertEqual(userDefaults.integer(forKey: "paymentReminderNotificationMinute"), 30)
    }

    // MARK: - 権限リクエスト

    func testRequestAuthorizationGranted() async {
        mockNotificationCenter.grantResult = true
        let result = await service.requestAuthorization()
        XCTAssertTrue(result)
        XCTAssertEqual(mockNotificationCenter.requestAuthorizationCallCount, 1)
    }

    func testRequestAuthorizationDenied() async {
        mockNotificationCenter.grantResult = false
        let result = await service.requestAuthorization()
        XCTAssertFalse(result)
    }

    // MARK: - キャンセル

    func testCancelAllRemovesPendingPaymentReminderOnly() {
        service.cancelAll()
        XCTAssertEqual(mockNotificationCenter.removeCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers, ["payment-reminder"])
    }

    func testLoadsPersistedValuesOnInit() {
        userDefaults.set(true, forKey: "paymentReminderNotificationEnabled")
        userDefaults.set(8, forKey: "paymentReminderNotificationHour")
        userDefaults.set(15, forKey: "paymentReminderNotificationMinute")

        let newService = PaymentReminderNotificationService(
            notificationCenter: mockNotificationCenter,
            userDefaults: userDefaults,
            unpaidDetector: unpaidDetector,
            childRepository: mockChildRepository,
            helpRecordRepository: mockHelpRecordRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            helpTaskRepository: mockHelpTaskRepository
        )

        XCTAssertTrue(newService.isEnabled)
        XCTAssertEqual(newService.reminderHour, 8)
        XCTAssertEqual(newService.reminderMinute, 15)
    }
}
