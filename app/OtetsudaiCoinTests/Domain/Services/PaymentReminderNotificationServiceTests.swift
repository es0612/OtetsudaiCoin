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

    // MARK: - reschedule: 無効時

    func testRescheduleDoesNothingWhenDisabled() async throws {
        service.isEnabled = false
        try await service.reschedule()
        XCTAssertEqual(mockNotificationCenter.addCallCount, 0)
    }

    // MARK: - reschedule: 未払いなし

    func testRescheduleSkipsAddWhenNoUnpaid() async throws {
        service.isEnabled = true
        mockNotificationCenter.mockAuthorizationStatus = .authorized

        try await service.reschedule()

        XCTAssertEqual(mockNotificationCenter.removeCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.addCallCount, 0)
    }

    // MARK: - reschedule: 単一未払い

    func testRescheduleAddsNotificationForSingleUnpaidPeriod() async throws {
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF0000")
        mockChildRepository.children = [child]

        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [task]

        let cal = Calendar.current
        let lastMonthDate = cal.date(byAdding: .month, value: -1, to: Date())!
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: lastMonthDate)
        ]
        mockAllowancePaymentRepository.payments = []

        service.isEnabled = true
        service.reminderHour = 10
        service.reminderMinute = 30
        mockNotificationCenter.mockAuthorizationStatus = .authorized

        try await service.reschedule()

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertEqual(request?.identifier, "payment-reminder")
        XCTAssertEqual(request?.content.title, "お小遣いの未払いがあります 💰")
        XCTAssertTrue(request?.content.body.contains("さくら") ?? false)
        XCTAssertTrue(request?.content.body.contains("¥100") ?? false)

        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        let nextMonthFirst = cal.date(byAdding: .month, value: 1, to: cal.date(from: cal.dateComponents([.year, .month], from: Date()))!)!
        let expected = cal.dateComponents([.year, .month, .day], from: nextMonthFirst)
        XCTAssertEqual(trigger?.dateComponents.year, expected.year)
        XCTAssertEqual(trigger?.dateComponents.month, expected.month)
        XCTAssertEqual(trigger?.dateComponents.day, 1)
        XCTAssertEqual(trigger?.dateComponents.hour, 10)
        XCTAssertEqual(trigger?.dateComponents.minute, 30)
        XCTAssertEqual(trigger?.repeats, false)
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
