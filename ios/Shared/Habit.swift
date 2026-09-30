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
        let key = DayKey.key(for: date)
        if completions.contains(key) {
            completions.remove(key)
        } else {
            completions.insert(key)
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
}

enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
