import Foundation

enum Periodicity: Codable, Hashable {
    case daily
    /// Monday-first weekday indexes: 0 = Monday ... 6 = Sunday.
    case weekdays(Set<Int>)
}

struct Habit: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var periodicity: Periodicity = .daily
    /// Completed days as "yyyy-MM-dd" keys in the local calendar.
    var completions: Set<String> = []
    var createdAt: Date = Date()
    // New fields must stay optional: synthesized Codable can't fill defaults when decoding older saved data.
    /// Reminder time as minutes since midnight; nil means no reminder.
    var reminderMinutes: Int?

    static let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    static func mondayIndex(of date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    func isDue(on date: Date, calendar: Calendar = .current) -> Bool {
        switch periodicity {
        case .daily:
            return true
        case .weekdays(let days):
            return days.contains(Habit.mondayIndex(of: date, calendar: calendar))
        }
    }

    func isDone(on date: Date) -> Bool {
        completions.contains(DayKey.key(for: date))
    }

    var isDoneToday: Bool { isDone(on: Date()) }

    mutating func toggle(on date: Date = Date()) {
        setDone(!isDone(on: date), dayKey: DayKey.key(for: date))
    }

    mutating func setDone(_ done: Bool, dayKey: String) {
        if done {
            completions.insert(dayKey)
        } else {
            completions.remove(dayKey)
        }
    }

    var periodLabel: String {
        switch periodicity {
        case .daily:
            return "Каждый день"
        case .weekdays(let days):
            if days.count == 7 { return "Каждый день" }
            return days.sorted().map { Habit.weekdaySymbols[$0] }.joined(separator: ", ")
        }
    }

    var reminderLabel: String? {
        reminderMinutes.map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
    }

    func currentStreak(today: Date = Date(), calendar: Calendar = .current) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: today)
        // Today not done yet shouldn't break the streak.
        if isDue(on: cursor, calendar: calendar) && !isDone(on: cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        for _ in 0..<3650 {
            if isDue(on: cursor, calendar: calendar) {
                guard isDone(on: cursor) else { break }
                streak += 1
            }
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    func bestStreak(today: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let firstKey = completions.min(), let first = DayKey.date(from: firstKey, calendar: calendar) else {
            return 0
        }
        let end = calendar.startOfDay(for: today)
        var cursor = max(first, calendar.date(byAdding: .day, value: -3650, to: end) ?? first)
        var best = 0
        var run = 0
        while cursor <= end {
            if isDue(on: cursor, calendar: calendar) {
                if isDone(on: cursor) {
                    run += 1
                    best = max(best, run)
                } else if cursor < end {
                    run = 0
                }
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return best
    }
}

enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
