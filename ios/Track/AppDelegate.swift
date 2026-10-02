import UIKit
import UserNotifications
import WidgetKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategories()
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
        let request = response.notification.request
        let info = request.content.userInfo
        guard
            let action = ReminderScheduler.Action(rawValue: response.actionIdentifier),
            let idString = info[ReminderScheduler.habitIDKey] as? String,
            let id = UUID(uuidString: idString)
        else { return }

        if action == .snooze {
            await ReminderScheduler.snooze(request)
            return
        }

        let status: DayStatus
        switch action {
        case .done: status = .full
        case .minimal: status = .minimal
        case .rest: status = .rest
        case .snooze: return
        }

        let day = info[ReminderScheduler.dayKey] as? String ?? DayKey.key(for: Date())
        let habits = HabitStorage.update(habitID: id) { $0.setStatus(status, onKey: day) }
        WidgetCenter.shared.reloadAllTimelines()
        await MainActor.run {
            NotificationCenter.default.post(name: .habitsChangedExternally, object: nil)
        }
        await ReminderScheduler.reschedule(habits)
    }
}
