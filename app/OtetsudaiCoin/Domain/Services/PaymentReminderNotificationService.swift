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
