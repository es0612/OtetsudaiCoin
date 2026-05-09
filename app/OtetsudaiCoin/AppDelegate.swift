import UIKit
import UserNotifications
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        MobileAds.shared.start(completionHandler: nil)
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationTap(identifier: response.notification.request.identifier)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Internal

    func handleNotificationTap(identifier: String) {
        switch identifier {
        case PaymentReminderNotificationService.notificationIdentifier:
            NotificationCenter.default.post(name: .navigateToHome, object: nil)
        default:
            NotificationCenter.default.post(name: .navigateToRecord, object: nil)
        }
    }
}
