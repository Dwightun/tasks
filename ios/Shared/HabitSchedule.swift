import Foundation

struct WeekProgress: Equatable {
    /// Opportunities the plan asked for this week (after pauses and rest days).
    let planned: Int
    /// Days completed in full or as the minimal version.
    let completed: Int
    let minimal: Int

    var isMet: Bool { planned > 0 && completed >= planned }
}

struct ReturnPrompt: Equatable {
    let missedDay: Date
    let nextOpportunity: Date?
}

struct Streak: Equatable {
    enum Unit { case days, weeks }

    let current: Int
    let best: Int
    let unit: Unit
}

extension Habit {
    /// Fixed-day obligation: true only for daily/weekday plans on a scheduled, non-paused day.
    func isDue(on date: Date, calendar: Calendar = .current) -> Bool {
        let key = DayKey.key(for: date, calendar: calendar)
        guard key >= startKey, !isPaused(onKey: key) else { return false }
        switch periodicity(onKey: key) {
        case .daily:
            return true
        case .weekdays(let days):
            return days.contains(Habit.mondayIndex(of: date, calendar: calendar))
        case .timesPerWeek:
            return false
        }
    }

    /// Whether the habit belongs on today's list and should be reminded about.
    /// Weekly-quota habits stay until the quota is met (or remain visible once done today).
    func isPlanned(on date: Date, calendar: Calendar = .current) -> Bool {
        let key = DayKey.key(for: date, calendar: calendar)
        guard !isPaused(onKey: key), status(onKey: key) != .rest else { return false }
        switch periodicity(onKey: key) {
        case .daily, .weekdays:
            return isDue(on: date, calendar: calendar)
        case .timesPerWeek(let count):
            return isCompleted(onKey: key) || weekProgress(containing: date, calendar: calendar).completed < count
        }
    }

    func weekProgress(containing date: Date, calendar: Calendar = .current) -> WeekProgress {
        let monday = Habit.monday(of: date, calendar: calendar)
        var completed = 0
        var minimal = 0
        var available = 0
        var due = 0

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            let key = DayKey.key(for: day, calendar: calendar)
            let dayStatus = self.status(onKey: key)
            if dayStatus == .full || dayStatus == .minimal { completed += 1 }
            if dayStatus == .minimal { minimal += 1 }
            guard key >= startKey, !isPaused(onKey: key), dayStatus != .rest else { continue }
            available += 1
            if isDue(on: day, calendar: calendar) { due += 1 }
        }

        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        let planned: Int
        if case .timesPerWeek(let count) = periodicity(onKey: DayKey.key(for: sunday, calendar: calendar)) {
            planned = min(count, available)
        } else {
            planned = due
        }
        return WeekProgress(planned: planned, completed: completed, minimal: minimal)
    }

    /// Daily/weekday plans count due days; weekly quotas count successful weeks.
    /// Pauses, rest days and the still-open current period never break a streak.
    func streak(today: Date = Date(), calendar: Calendar = .current) -> Streak {
        let todayStart = calendar.startOfDay(for: today)
        let todayKey = DayKey.key(for: todayStart, calendar: calendar)
        guard let start = DayKey.date(from: startKey, calendar: calendar) else {
            return Streak(current: 0, best: 0, unit: .days)
        }
        // Bound the walk for corrupt or very old data.
        let earliest = calendar.date(byAdding: .day, value: -3650, to: todayStart) ?? start
        let from = max(start, earliest)

        var run = 0
        var best = 0
        func record(hit: Bool?) {
            guard let hit else { return }
            if hit {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }

        if case .timesPerWeek = periodicity {
            var monday = Habit.monday(of: from, calendar: calendar)
            let thisMonday = Habit.monday(of: todayStart, calendar: calendar)
            while monday <= thisMonday {
                let progress = weekProgress(containing: monday, calendar: calendar)
                if progress.planned == 0 {
                    record(hit: nil)
                } else if progress.isMet {
                    record(hit: true)
                } else {
                    record(hit: monday == thisMonday ? nil : false)
                }
                guard let next = calendar.date(byAdding: .day, value: 7, to: monday) else { break }
                monday = next
            }
            return Streak(current: run, best: best, unit: .weeks)
        }

        var day = from
        while day <= todayStart {
            let key = DayKey.key(for: day, calendar: calendar)
            if status(onKey: key) == .rest || !isDue(on: day, calendar: calendar) {
                record(hit: nil)
            } else if isCompleted(onKey: key) {
                record(hit: true)
            } else {
                record(hit: key == todayKey ? nil : false)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return Streak(current: run, best: best, unit: .days)
    }

    /// Prompt to come back after a miss: the most recent due day before today passed without any record.
    /// Weekly quotas are judged per week, so they don't get a day-level prompt.
    func returnPrompt(today: Date = Date(), calendar: Calendar = .current, lookbackDays: Int = 7) -> ReturnPrompt? {
        let todayStart = calendar.startOfDay(for: today)
        let todayKey = DayKey.key(for: todayStart, calendar: calendar)
        if case .timesPerWeek = periodicity(onKey: todayKey) { return nil }
        guard !isPaused(onKey: todayKey), !isCompleted(onKey: todayKey) else { return nil }

        for offset in 1...lookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { break }
            let key = DayKey.key(for: day, calendar: calendar)
            guard isDue(on: day, calendar: calendar), status(onKey: key) != .rest else { continue }
            guard status(onKey: key) == nil else { return nil }
            return ReturnPrompt(missedDay: day, nextOpportunity: nextOpportunity(from: todayStart, calendar: calendar))
        }
        return nil
    }

    /// Today if it's due and not yet done, otherwise the next due day within two weeks.
    func nextOpportunity(from date: Date = Date(), calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: date)
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { break }
            if isDue(on: day, calendar: calendar), !isCompleted(on: day) {
                return day
            }
        }
        return nil
    }

    static func monday(of date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -mondayIndex(of: day, calendar: calendar), to: day) ?? day
    }
}
