import Foundation

@MainActor
@Observable
class PaymentReminderNotificationSettingsViewModel {

    var isEnabled: Bool
    var reminderTime: Date
    var scheduleError: Error?

    private let service: PaymentReminderNotificationServiceProtocol

    init(service: PaymentReminderNotificationServiceProtocol) {
        self.service = service
        self.isEnabled = service.isEnabled
        self.reminderTime = Self.dateFrom(hour: service.reminderHour, minute: service.reminderMinute)
    }

    func toggleNotification(enabled: Bool) async {
        if enabled {
            let granted = await service.requestAuthorization()
            if granted {
                service.isEnabled = true
                isEnabled = true
                do {
                    try await service.reschedule()
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
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: newTime)
        guard let hour = comps.hour, let minute = comps.minute else { return }

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
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}
