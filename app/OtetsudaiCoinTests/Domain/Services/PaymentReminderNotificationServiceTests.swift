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

    // MARK: - reschedule: 複数集約

    func testRescheduleAggregatesMultipleChildrenAndMonths() async throws {
        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date())!
        let twoMonthsAgo = cal.date(byAdding: .month, value: -2, to: Date())!

        let child1 = Child(id: UUID(), name: "さくら", themeColor: "#FF0000")
        let child2 = Child(id: UUID(), name: "たろう", themeColor: "#00FF00")
        mockChildRepository.children = [child1, child2]

        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 500)
        mockHelpTaskRepository.tasks = [task]

        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child1.id, helpTaskId: task.id, recordedAt: lastMonth),
            HelpRecord(id: UUID(), childId: child1.id, helpTaskId: task.id, recordedAt: twoMonthsAgo),
            HelpRecord(id: UUID(), childId: child2.id, helpTaskId: task.id, recordedAt: lastMonth)
        ]
        mockAllowancePaymentRepository.payments = []

        service.isEnabled = true
        mockNotificationCenter.mockAuthorizationStatus = .authorized

        try await service.reschedule()

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)
        let body = mockNotificationCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("さくら"), "さくらの未払いが含まれるべき: \(body)")
        XCTAssertTrue(body.contains("たろう"), "たろうの未払いが含まれるべき: \(body)")
        XCTAssertTrue(body.contains("合計"), "合計表示があるべき: \(body)")
        XCTAssertTrue(body.contains("¥1500"), "合計金額が表示されるべき: \(body)")
    }

    // MARK: - reschedule: 年またぎ

    func testRescheduleHandlesYearRolloverDecemberToJanuary() async throws {
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF0000")
        mockChildRepository.children = [child]
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [task]
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: lastMonth)
        ]
        service.isEnabled = true
        mockNotificationCenter.mockAuthorizationStatus = .authorized

        try await service.reschedule()

        let trigger = mockNotificationCenter.addedRequests.first?.trigger as? UNCalendarNotificationTrigger
        let cal = Calendar.current
        let now = Date()
        let nextMonth = cal.date(byAdding: .month, value: 1, to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
        let expectedComps = cal.dateComponents([.year, .month], from: nextMonth)
        XCTAssertEqual(trigger?.dateComponents.year, expectedComps.year, "翌月の年が一致")
        XCTAssertEqual(trigger?.dateComponents.month, expectedComps.month, "翌月の月が一致")
    }

    // MARK: - reschedule: 認可なし

    func testRescheduleSkipsWhenAuthorizationDenied() async throws {
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF0000")
        mockChildRepository.children = [child]
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id,
                       recordedAt: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        ]
        service.isEnabled = true
        mockNotificationCenter.mockAuthorizationStatus = .denied

        try await service.reschedule()

        XCTAssertEqual(mockNotificationCenter.removeCallCount, 1, "cancelAll は呼ばれる")
        XCTAssertEqual(mockNotificationCenter.addCallCount, 0, "認可なしなら add されない")
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
