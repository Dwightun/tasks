import Foundation
import WidgetKit

final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit] = []

    init() {
        reload()
    }

    func reload() {
        habits = HabitStorage.load()
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
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].toggle()
        persist()
    }

    private func persist() {
        HabitStorage.save(habits)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
