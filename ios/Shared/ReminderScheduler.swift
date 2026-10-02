import Foundation
import UserNotifications

/// Schedules one-shot reminders for upcoming due, not-yet-done days.
/// Repeating triggers can't skip days that are already completed, so the window is
/// rebuilt on every change (app, widget, notification action) instead.
enum ReminderScheduler {
    static let categoryID = "HABIT_REMINDER"
    static let doneActionID = "HABIT_DONE"
    static let habitIDKey = "habitID"
    static let dayKey = "day"

    private static let horizonDays = 14
    /// iOS keeps at most 64 pending local notifications per app.
    private static let maxPending = 60

    static func registerCategory() {
        let done = UNNotificationAction(identifier: doneActionID, title: "Выполнено", options: [])
        let category = UNNotificationCategory(identifier: categoryID, actions: [done], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    static func reschedule(_ habits: [Habit], now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let today = calendar.startOfDay(for: now)
        var pending: [(fireDate: Date, request: UNNotificationRequest)] = []

        for habit in habits {
            guard let minutes = habit.reminderMinutes else { continue }
            for offset in 0..<horizonDays {
                guard
                    let day = calendar.date(byAdding: .day, value: offset, to: today),
                    let fireDate = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
                    fireDate > now,
                    habit.isPlanned(on: day, calendar: calendar),
                    habit.status(onKey: DayKey.key(for: day, calendar: calendar)) == nil
                else { continue }

                let key = DayKey.key(for: day, calendar: calendar)
                let content = UNMutableNotificationContent()
                content.title = habit.name
                let week = habit.weekProgress(containing: day, calendar: calendar)
                content.body = week.planned > 0
                    ? "На этой неделе \(week.completed) из \(week.planned). Отметь, когда выполнишь"
                    : "Отметь, когда выполнишь"
                content.sound = .default
                content.categoryIdentifier = categoryID
                content.threadIdentifier = habit.id.uuidString
                content.userInfo = [habitIDKey: habit.id.uuidString, dayKey: key]

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "habit-\(habit.id.uuidString)-\(key)",
                    content: content,
                    trigger: trigger
                )
                pending.append((fireDate, request))
            }
        }

        for item in pending.sorted(by: { $0.fireDate < $1.fireDate }).prefix(maxPending) {
            try? await center.add(item.request)
        }
    }
}
