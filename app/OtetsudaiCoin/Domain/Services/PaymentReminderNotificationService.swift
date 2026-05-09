import Foundation
import UserNotifications

// MARK: - PaymentReminderNotificationServiceProtocol

protocol PaymentReminderNotificationServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }
    var reminderHour: Int { get set }
    var reminderMinute: Int { get set }

    func requestAuthorization() async -> Bool
    func reschedule() async throws
    func cancelAll()
}

// MARK: - PaymentReminderNotificationService

class PaymentReminderNotificationService: PaymentReminderNotificationServiceProtocol {

    private enum UserDefaultsKey {
        static let enabled = "paymentReminderNotificationEnabled"
        static let hour = "paymentReminderNotificationHour"
        static let minute = "paymentReminderNotificationMinute"
    }

    static let notificationIdentifier = "payment-reminder"
    private static let defaultHour = 9
    private static let defaultMinute = 0

    private let notificationCenter: NotificationCenterProtocol
    private let userDefaults: UserDefaults
    private let unpaidDetector: UnpaidAllowanceDetectorService
    private let childRepository: ChildRepository
    private let helpRecordRepository: HelpRecordRepository
    private let allowancePaymentRepository: AllowancePaymentRepository
    private let helpTaskRepository: HelpTaskRepository

    var isEnabled: Bool {
        didSet { userDefaults.set(isEnabled, forKey: UserDefaultsKey.enabled) }
    }

    var reminderHour: Int {
        didSet { userDefaults.set(reminderHour, forKey: UserDefaultsKey.hour) }
    }

    var reminderMinute: Int {
        didSet { userDefaults.set(reminderMinute, forKey: UserDefaultsKey.minute) }
    }

    init(
        notificationCenter: NotificationCenterProtocol,
        userDefaults: UserDefaults,
        unpaidDetector: UnpaidAllowanceDetectorService,
        childRepository: ChildRepository,
        helpRecordRepository: HelpRecordRepository,
        allowancePaymentRepository: AllowancePaymentRepository,
        helpTaskRepository: HelpTaskRepository
    ) {
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        self.unpaidDetector = unpaidDetector
        self.childRepository = childRepository
        self.helpRecordRepository = helpRecordRepository
        self.allowancePaymentRepository = allowancePaymentRepository
        self.helpTaskRepository = helpTaskRepository

        let hasStoredHour = userDefaults.object(forKey: UserDefaultsKey.hour) != nil
        let hasStoredMinute = userDefaults.object(forKey: UserDefaultsKey.minute) != nil
        self.isEnabled = userDefaults.bool(forKey: UserDefaultsKey.enabled)
        self.reminderHour = hasStoredHour
            ? userDefaults.integer(forKey: UserDefaultsKey.hour)
            : Self.defaultHour
        self.reminderMinute = hasStoredMinute
            ? userDefaults.integer(forKey: UserDefaultsKey.minute)
            : Self.defaultMinute
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func reschedule() async throws {
        cancelAll()
        guard isEnabled else { return }
        guard await notificationCenter.currentAuthorizationStatus() == .authorized else { return }

        let unpaidPeriods = try await collectUnpaidPeriods()
        guard !unpaidPeriods.isEmpty else { return }

        // メッセージ組み立てとスケジュールは次タスク
    }

    private func collectUnpaidPeriods() async throws -> [(child: Child, period: UnpaidPeriod)] {
        let children = try await childRepository.findAll()
        let allTasks = try await helpTaskRepository.findAll()
        let allPayments = try await allowancePaymentRepository.findAll()

        var result: [(Child, UnpaidPeriod)] = []
        for child in children {
            let records = try await helpRecordRepository.findByChildId(child.id)
            let periods = unpaidDetector.detectUnpaidPeriods(
                childId: child.id,
                helpRecords: records,
                payments: allPayments,
                tasks: allTasks
            )
            result.append(contentsOf: periods.map { (child, $0) })
        }
        return result
    }

    func cancelAll() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
    }
}
