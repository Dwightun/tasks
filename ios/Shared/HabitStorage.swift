import Foundation

/// JSON file in the App Group container, shared by the app and the widget.
enum HabitStorage {
    static let appGroupID = "group.com.roma5.track"

    private static var fileURL: URL {
        // Falls back to Documents when the App Group entitlement is absent (unsigned simulator builds).
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("habits.json")
    }

    static func load() -> [Habit] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Habit].self, from: data)) ?? []
    }

    static func save(_ habits: [Habit]) {
        guard let data = try? JSONEncoder().encode(habits) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func toggle(habitID: UUID, on date: Date = Date()) {
        var habits = load()
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[index].toggle(on: date)
        save(habits)
    }
}
