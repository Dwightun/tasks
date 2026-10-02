import Foundation

enum Periodicity: Codable, Hashable {
    case daily
    /// Monday-first weekday indexes: 0 = Monday ... 6 = Sunday.
    case weekdays(Set<Int>)
    /// Flexible weekly quota without fixed days.
    case timesPerWeek(Int)
}

/// What actually happened on a day. A day without an entry means "no data", not a confirmed miss.
enum DayStatus: String, Codable, CaseIterable {
    case full
    case minimal
    case rest
    case skipped
}

enum SkipReason: String, Codable, CaseIterable {
    case forgot
    case noTime
    case tooHard
    case notEnjoyable
    case circumstances
    case unwell
    case other

    var title: String {
        switch self {
        case .forgot: return "Забыл"
        case .noTime: return "Не было времени"
        case .tooHard: return "Трудно начать"
        case .notEnjoyable: return "Не хотелось"
        case .circumstances: return "Изменились обстоятельства"
        case .unwell: return "Плохое самочувствие"
        case .other: return "Другое"
        }
    }
}

struct DayEntry: Codable, Hashable {
    var status: DayStatus
    var reason: SkipReason?
    var note: String?
}

/// Optional plan details; every field may stay empty.
struct PlanDetails: Codable, Hashable {
    var purpose: String?
    var cue: String?
    var firstStep: String?
    var minimalVersion: String?
    var obstacle: String?
    var backupPlan: String?
    var preparation: String?
}

/// Schedule in effect from `since` (inclusive), so lowering the goal doesn't rewrite past weeks.
struct PlanVersion: Codable, Hashable {
    /// Applies to all history recorded before plan versioning existed.
    static let beginning = "0000-01-01"

    var since: String
    var periodicity: Periodicity
}

struct Pause: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case rest
        case sick
        case travel

        var title: String {
            switch self {
            case .rest: return "Отдых"
            case .sick: return "Болезнь"
            case .travel: return "Поездка"
            }
        }
    }

    var kind: Kind
    /// Inclusive day keys; nil end means open-ended.
    var start: String
    var end: String?

    func contains(_ key: String) -> Bool {
        key >= start && (end.map { key <= $0 } ?? true)
    }
}

struct Habit: Identifiable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    /// Reminder time as minutes since midnight; nil means no reminder.
    var reminderMinutes: Int?
    var plan: PlanDetails
    /// Never empty; the last element is the current plan.
    var planHistory: [PlanVersion]
    /// Day key ("yyyy-MM-dd") → what happened.
    var entries: [String: DayEntry]
    var pauses: [Pause]

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        periodicity: Periodicity = .daily,
        createdAt: Date = Date(),
        reminderMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.reminderMinutes = reminderMinutes
        self.plan = PlanDetails()
        self.planHistory = [PlanVersion(since: DayKey.key(for: createdAt), periodicity: periodicity)]
        self.entries = [:]
        self.pauses = []
    }

    static let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    static func mondayIndex(of date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    // MARK: Plan

    var periodicity: Periodicity {
        planHistory.last?.periodicity ?? .daily
    }

    func periodicity(onKey key: String) -> Periodicity {
        (planHistory.last(where: { $0.since <= key }) ?? planHistory.first)?.periodicity ?? .daily
    }

    /// Changes the schedule from `date` on, keeping earlier weeks judged by the plan they had.
    mutating func setPeriodicity(_ periodicity: Periodicity, from date: Date = Date()) {
        guard periodicity != self.periodicity else { return }
        let key = DayKey.key(for: date)
        if let last = planHistory.last, last.since >= key {
            planHistory[planHistory.count - 1].periodicity = periodicity
        } else {
            planHistory.append(PlanVersion(since: key, periodicity: periodicity))
        }
        // Undoing a same-day change shouldn't leave a duplicate version behind.
        if planHistory.count >= 2, planHistory[planHistory.count - 2].periodicity == periodicity {
            planHistory.removeLast()
        }
    }

    var periodLabel: String {
        switch periodicity {
        case .daily:
            return "Каждый день"
        case .weekdays(let days):
            if days.count == 7 { return "Каждый день" }
            return days.sorted().map { Habit.weekdaySymbols[$0] }.joined(separator: ", ")
        case .timesPerWeek(let count):
            return Habit.timesPerWeekLabel(count)
        }
    }

    static func timesPerWeekLabel(_ count: Int) -> String {
        let word = (2...4).contains(count % 10) && !(12...14).contains(count % 100) ? "раза" : "раз"
        return "\(count) \(word) в неделю"
    }

    var reminderLabel: String? {
        reminderMinutes.map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
    }

    // MARK: Days

    func status(onKey key: String) -> DayStatus? {
        entries[key]?.status
    }

    func isCompleted(onKey key: String) -> Bool {
        let dayStatus = self.status(onKey: key)
        return dayStatus == .full || dayStatus == .minimal
    }

    func isCompleted(on date: Date) -> Bool {
        isCompleted(onKey: DayKey.key(for: date))
    }

    func isPaused(onKey key: String) -> Bool {
        pauses.contains { $0.contains(key) }
    }

    mutating func setStatus(_ status: DayStatus?, onKey key: String, reason: SkipReason? = nil) {
        if let status {
            entries[key] = DayEntry(status: status, reason: status == .skipped ? reason : nil)
        } else {
            entries.removeValue(forKey: key)
        }
    }

    func activePause(on date: Date) -> Pause? {
        let key = DayKey.key(for: date)
        return pauses.last(where: { $0.contains(key) })
    }

    mutating func startPause(_ kind: Pause.Kind, from date: Date = Date(), until end: Date?) {
        let startKey = DayKey.key(for: date)
        pauses.removeAll { $0.contains(startKey) || $0.start > startKey }
        pauses.append(Pause(kind: kind, start: startKey, end: end.map { DayKey.key(for: $0) }))
    }

    /// Ends the pause covering `date` so that `date` itself counts again.
    mutating func endPause(on date: Date = Date(), calendar: Calendar = .current) {
        let key = DayKey.key(for: date, calendar: calendar)
        guard let index = pauses.lastIndex(where: { $0.contains(key) }) else { return }
        if pauses[index].start >= key {
            pauses.remove(at: index)
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: date) {
            pauses[index].end = DayKey.key(for: yesterday, calendar: calendar)
        }
    }

    /// One-tap logging: a completed day is cleared, anything else becomes a full completion.
    mutating func toggle(on date: Date = Date()) {
        let key = DayKey.key(for: date)
        setStatus(isCompleted(onKey: key) ? nil : .full, onKey: key)
    }

    var totalCompleted: Int {
        entries.values.filter { $0.status == .full || $0.status == .minimal }.count
    }

    /// First day that counts for statistics: creation, or an earlier retroactive mark.
    var startKey: String {
        let created = DayKey.key(for: createdAt)
        return entries.keys.min().map { min($0, created) } ?? created
    }
}

// MARK: - Codable

extension Habit: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, colorHex, createdAt, reminderMinutes, plan, planHistory, entries, pauses
        // v1 format
        case periodicity, completions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#38D9A9"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        reminderMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderMinutes)
        plan = try c.decodeIfPresent(PlanDetails.self, forKey: .plan) ?? PlanDetails()
        pauses = try c.decodeIfPresent([Pause].self, forKey: .pauses) ?? []

        if let history = try c.decodeIfPresent([PlanVersion].self, forKey: .planHistory), !history.isEmpty {
            planHistory = history
        } else {
            let legacy = try c.decodeIfPresent(Periodicity.self, forKey: .periodicity) ?? .daily
            planHistory = [PlanVersion(since: PlanVersion.beginning, periodicity: legacy)]
        }

        if let entries = try c.decodeIfPresent([String: DayEntry].self, forKey: .entries) {
            self.entries = entries
        } else {
            let legacy = try c.decodeIfPresent(Set<String>.self, forKey: .completions) ?? []
            self.entries = Dictionary(uniqueKeysWithValues: legacy.map { ($0, DayEntry(status: .full)) })
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(reminderMinutes, forKey: .reminderMinutes)
        try c.encode(plan, forKey: .plan)
        try c.encode(planHistory, forKey: .planHistory)
        try c.encode(entries, forKey: .entries)
        try c.encode(pauses, forKey: .pauses)
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
