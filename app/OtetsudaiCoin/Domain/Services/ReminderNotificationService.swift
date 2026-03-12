import Foundation
import UserNotifications

// MARK: - NotificationCenterProtocol

protocol NotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func addNotificationRequest(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await add(request)
    }
}

// MARK: - ReminderNotificationServiceProtocol

protocol ReminderNotificationServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }
    var reminderHour: Int { get set }
    var reminderMinute: Int { get set }

    func requestAuthorization() async -> Bool
    func scheduleDaily() async throws
    func cancelAll()
    func reschedule() async throws
}

// MARK: - ReminderNotificationService

class ReminderNotificationService: ReminderNotificationServiceProtocol {

    private enum UserDefaultsKey {
        static let enabled = "reminderNotificationEnabled"
        static let hour = "reminderNotificationHour"
        static let minute = "reminderNotificationMinute"
    }

    private static let notificationIdentifier = "daily-reminder"
    private static let defaultHour = 18
    private static let defaultMinute = 0

    private let notificationCenter: NotificationCenterProtocol
    private let userDefaults: UserDefaults

    var isEnabled: Bool {
        didSet { userDefaults.set(isEnabled, forKey: UserDefaultsKey.enabled) }
    }

    var reminderHour: Int {
        didSet { userDefaults.set(reminderHour, forKey: UserDefaultsKey.hour) }
    }

    var reminderMinute: Int {
        didSet { userDefaults.set(reminderMinute, forKey: UserDefaultsKey.minute) }
    }

    init(notificationCenter: NotificationCenterProtocol, userDefaults: UserDefaults) {
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults

        let hasStoredHour = userDefaults.object(forKey: UserDefaultsKey.hour) != nil
        self.isEnabled = userDefaults.bool(forKey: UserDefaultsKey.enabled)
        self.reminderHour = hasStoredHour
            ? userDefaults.integer(forKey: UserDefaultsKey.hour)
            : Self.defaultHour
        self.reminderMinute = userDefaults.object(forKey: UserDefaultsKey.minute) != nil
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

    func scheduleDaily() async throws {
        let content = UNMutableNotificationContent()
        content.title = "おてつだいコイン"
        content.body = "今日のお手伝いを記録しよう！🌟"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.addNotificationRequest(request)
    }

    func cancelAll() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
    }

    func reschedule() async throws {
        cancelAll()
        try await scheduleDaily()
    }
}
