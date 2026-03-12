import Foundation
import UserNotifications
@testable import OtetsudaiCoin

// MARK: - ReminderNotificationServiceProtocol のモック

class MockReminderNotificationService: ReminderNotificationServiceProtocol {
    var isEnabled: Bool = false
    var reminderHour: Int = 18
    var reminderMinute: Int = 0

    // テスト用トラッキング
    var requestAuthorizationCallCount = 0
    var scheduleDailyCallCount = 0
    var cancelAllCallCount = 0
    var rescheduleCallCount = 0

    var authorizationResult: Bool = true
    var scheduleDailyError: Error?
    var rescheduleError: Error?

    func requestAuthorization() async -> Bool {
        requestAuthorizationCallCount += 1
        return authorizationResult
    }

    func scheduleDaily() async throws {
        scheduleDailyCallCount += 1
        if let error = scheduleDailyError {
            throw error
        }
    }

    func cancelAll() {
        cancelAllCallCount += 1
    }

    func reschedule() async throws {
        rescheduleCallCount += 1
        if let error = rescheduleError {
            throw error
        }
    }
}

// MARK: - UNUserNotificationCenter の抽象化モック

class MockNotificationCenter: NotificationCenterProtocol {
    var grantResult: Bool = true

    var addCallCount = 0
    var removeCallCount = 0
    var requestAuthorizationCallCount = 0
    var removedIdentifiers: [String] = []
    var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        return grantResult
    }

    var addError: Error?

    func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        addCallCount += 1
        addedRequests.append(request)
        if let error = addError {
            throw error
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removeCallCount += 1
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
