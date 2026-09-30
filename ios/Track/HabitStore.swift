import Foundation
import WidgetKit

extension Notification.Name {
    /// Posted when habits change outside the store (e.g. the "Done" notification action).
    static let habitsChangedExternally = Notification.Name("habitsChangedExternally")
}

final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []
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
