import Foundation
import SwiftUI
import WidgetKit

extension Notification.Name {
    /// Posted when habits change outside the store (e.g. the "Done" notification action).
    static let habitsChangedExternally = Notification.Name("habitsChangedExternally")
}

final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []
    @Published private(set) var lastReviewedWeek: String? = ReviewSettings.lastReviewedWeek
    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: .habitsChangedExternally, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() {
        habits = HabitStorage.load()
        rescheduleReminders()
    }

    func upsert(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        } else {
            habits.append(habit)
        }
        persist()
    }

    /// The stored order is also the order in widgets.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func delete(_ id: UUID) {
        habits.removeAll { $0.id == id }
        persist()
    }

    func toggleToday(_ id: UUID) {
        toggle(id, on: Date())
    }

    func toggle(_ id: UUID, on date: Date) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].toggle(on: date)
        persist()
    }

    func setStatus(_ id: UUID, _ status: DayStatus?, on date: Date, reason: SkipReason? = nil) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].setStatus(status, onKey: DayKey.key(for: date), reason: reason)
        persist()
    }

    func startPause(_ id: UUID, kind: Pause.Kind, until end: Date?) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].startPause(kind, until: end)
        persist()
    }

    func endPause(_ id: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].endPause()
        persist()
    }

    func setWeekReason(_ id: UUID, weekStart: Date, reason: SkipReason?) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        let key = DayKey.key(for: Habit.monday(of: weekStart))
        habits[index].weekReasons[key] = reason
        persist()
    }

    /// Schedule changes from a review start with the next full week.
    func applyPeriodicity(_ id: UUID, _ periodicity: Periodicity) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].setPeriodicity(periodicity, from: WeeklyReview.effectiveDateForChange())
        persist()
    }

    func markReviewed(weekStart: Date) {
        let key = DayKey.key(for: Habit.monday(of: weekStart))
        ReviewSettings.lastReviewedWeek = key
        lastReviewedWeek = key
    }

    func updateReviewReminder(enabled: Bool, minutes: Int) {
        ReviewSettings.isEnabled = enabled
        ReviewSettings.minutes = minutes
        rescheduleReminders()
    }

    func rescheduleReminders() {
        let snapshot = habits
        Task { await ReminderScheduler.reschedule(snapshot) }
    }

    private func persist() {
        HabitStorage.save(habits)
        WidgetCenter.shared.reloadAllTimelines()
        rescheduleReminders()
    }
}
