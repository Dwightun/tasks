import Foundation
import UserNotifications

/// Schedules one-shot reminders for upcoming planned, not-yet-recorded days.
/// Repeating triggers can't skip days that are already handled, so the window is
/// rebuilt on every change (app, widget, notification action) instead.
enum ReminderScheduler {
    enum Action: String {
        case done = "HABIT_DONE"
        case minimal = "HABIT_MINIMAL"
        case snooze = "HABIT_SNOOZE"
        case rest = "HABIT_REST"
    }

    static let categoryID = "HABIT_REMINDER"
    static let categoryWithMinimalID = "HABIT_REMINDER_MINIMAL"
    static let habitIDKey = "habitID"
    static let dayKey = "day"

    private static let snoozeSuffix = "-snooze"
    private static let horizonDays = 14
    /// iOS keeps at most 64 pending local notifications per app.
    private static let maxPending = 60

    static func registerCategories() {
        func action(_ action: Action, _ title: String) -> UNNotificationAction {
            UNNotificationAction(identifier: action.rawValue, title: title, options: [])
        }
        let done = action(.done, "Выполнено")
        let minimal = action(.minimal, "Минимум")
        let snooze = action(.snooze, "Через час")
        let rest = action(.rest, "Сегодня отдых")
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: categoryID, actions: [done, snooze, rest], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: categoryWithMinimalID, actions: [done, minimal, snooze, rest], intentIdentifiers: [], options: []),
        ])
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

    /// Re-delivers the same reminder in an hour; survives later reschedules until the day gets a record.
    static func snooze(_ request: UNNotificationRequest, minutes: Int = 60) async {
        let identifier = request.identifier.hasSuffix(snoozeSuffix) ? request.identifier : request.identifier + snoozeSuffix
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: request.content, trigger: trigger)
        )
    }

    static func reschedule(_ habits: [Habit], now: Date = Date(), calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()

        // Keep snoozed reminders whose day is still open; drop everything else and rebuild.
        let pending = await center.pendingNotificationRequests()
        let obsolete = pending.filter { request in
            guard request.identifier.hasSuffix(snoozeSuffix) else { return true }
            let info = request.content.userInfo
            guard
                let idString = info[habitIDKey] as? String,
                let key = info[dayKey] as? String,
                let habit = habits.first(where: { $0.id.uuidString == idString }),
                habit.reminderMinutes != nil
            else { return true }
            return habit.status(onKey: key) != nil || habit.isPaused(onKey: key)
        }
        center.removePendingNotificationRequests(withIdentifiers: obsolete.map(\.identifier))

        let today = calendar.startOfDay(for: now)
        var requests: [(fireDate: Date, request: UNNotificationRequest)] = []

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
                let request = UNNotificationRequest(
                    identifier: "habit-\(habit.id.uuidString)-\(key)",
                    content: content(for: habit, day: day, key: key, calendar: calendar),
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                        repeats: false
                    )
                )
                requests.append((fireDate, request))
            }
        }

        for item in requests.sorted(by: { $0.fireDate < $1.fireDate }).prefix(maxPending) {
            try? await center.add(item.request)
        }
    }

    private static func content(for habit: Habit, day: Date, key: String, calendar: Calendar) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = habit.name

        var lines: [String] = []
        if let step = habit.plan.firstStep, !step.isEmpty {
            lines.append("Начни с малого: \(step)")
        }
        let week = habit.weekProgress(containing: day, calendar: calendar)
        if week.planned > 0 {
            lines.append("На этой неделе \(week.completed) из \(week.planned)")
        }
        content.body = lines.isEmpty ? "Отметь, когда выполнишь" : lines.joined(separator: "\n")

        content.sound = .default
        let hasMinimal = !(habit.plan.minimalVersion ?? "").isEmpty
        content.categoryIdentifier = hasMinimal ? categoryWithMinimalID : categoryID
        content.threadIdentifier = habit.id.uuidString
        content.userInfo = [habitIDKey: habit.id.uuidString, dayKey: key]
        return content
    }
}
