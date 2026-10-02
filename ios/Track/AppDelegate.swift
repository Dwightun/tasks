import UIKit
import UserNotifications
import WidgetKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategory()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard
            response.actionIdentifier == ReminderScheduler.doneActionID,
            let idString = info[ReminderScheduler.habitIDKey] as? String,
            let id = UUID(uuidString: idString)
        else { return }

        let day = info[ReminderScheduler.dayKey] as? String ?? DayKey.key(for: Date())
        let habits = HabitStorage.update(habitID: id) { $0.setStatus(.full, onKey: day) }
        WidgetCenter.shared.reloadAllTimelines()
        await MainActor.run {
            NotificationCenter.default.post(name: .habitsChangedExternally, object: nil)
        }
        await ReminderScheduler.reschedule(habits)
    }
}
