import Foundation

@MainActor
@Observable
class NotificationSettingsViewModel {

    var isEnabled: Bool
    var reminderTime: Date

    private let service: ReminderNotificationServiceProtocol

    init(service: ReminderNotificationServiceProtocol) {
        self.service = service
        self.isEnabled = service.isEnabled
        self.reminderTime = Self.dateFrom(hour: service.reminderHour, minute: service.reminderMinute)
    }

    var scheduleError: Error?

    func toggleNotification(enabled: Bool) async {
        if enabled {
            let granted = await service.requestAuthorization()
            if granted {
                service.isEnabled = true
                isEnabled = true
                do {
                    try await service.scheduleDaily()
                    scheduleError = nil
                } catch {
                    scheduleError = error
                    service.isEnabled = false
                    isEnabled = false
                    service.cancelAll()
                }
            } else {
                service.isEnabled = false
                isEnabled = false
            }
        } else {
            service.isEnabled = false
            isEnabled = false
            service.cancelAll()
        }
    }

    func updateReminderTime(_ newTime: Date) async {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: newTime)
        guard let hour = components.hour, let minute = components.minute else { return }

        service.reminderHour = hour
        service.reminderMinute = minute
        reminderTime = newTime

        if service.isEnabled {
            do {
                try await service.reschedule()
                scheduleError = nil
            } catch {
                scheduleError = error
            }
        }
    }

    private static func dateFrom(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
