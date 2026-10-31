import Foundation

/// Weekly review preferences, shared with the widget so its reschedules keep the review reminder.
enum ReviewSettings {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: HabitStorage.appGroupID) ?? .standard
    }

    private static let enabledKey = "weeklyReviewEnabled"
    private static let minutesKey = "weeklyReviewMinutes"
    private static let lastReviewedKey = "lastReviewedWeek"

    static var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    /// Sunday reminder time, minutes since midnight.
    static var minutes: Int {
        get { defaults.object(forKey: minutesKey) as? Int ?? 19 * 60 }
        set { defaults.set(newValue, forKey: minutesKey) }
    }

    private static let checkInEnabledKey = "checkInEnabled"
    private static let checkInMinutesKey = "checkInMinutes"
    private static let checkInReminderKey = "checkInReminder"

    /// Evening check-in card on the main screen.
    static var checkInEnabled: Bool {
        get { defaults.object(forKey: checkInEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: checkInEnabledKey) }
    }

    /// From what time the check-in is offered, minutes since midnight.
    static var checkInMinutes: Int {
        get { defaults.object(forKey: checkInMinutesKey) as? Int ?? 20 * 60 }
        set { defaults.set(newValue, forKey: checkInMinutesKey) }
    }

    /// Daily notification for the check-in; off unless the user asks for it.
    static var checkInReminder: Bool {
        get { defaults.object(forKey: checkInReminderKey) as? Bool ?? false }
        set { defaults.set(newValue, forKey: checkInReminderKey) }
    }

    /// Monday key of the last week the user went through.
    static var lastReviewedWeek: String? {
        get { defaults.string(forKey: lastReviewedKey) }
        set { defaults.set(newValue, forKey: lastReviewedKey) }
    }
}
