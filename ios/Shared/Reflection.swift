import Foundation

/// Evening check-in: how the day felt and what influenced it. Kept next to habits, not derived from them.
struct DayReflection: Codable, Hashable {
    /// 1 (hard day) ... 5 (great day).
    var mood: Int
    var note: String?

    static let moodSymbols = ["😞", "😕", "😐", "🙂", "😄"]
    static let moodTitles = ["Тяжело", "Так себе", "Нормально", "Хорошо", "Отлично"]

    var symbol: String { DayReflection.moodSymbols[min(max(mood, 1), 5) - 1] }
    var title: String { DayReflection.moodTitles[min(max(mood, 1), 5) - 1] }
}

/// Day key → reflection, stored in the App Group next to habits.
enum ReflectionStorage {
    private static var fileURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: HabitStorage.appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("reflections.json")
    }

    static func load() -> [String: DayReflection] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: DayReflection].self, from: data)) ?? [:]
    }

    static func save(_ reflections: [String: DayReflection]) {
        guard let data = try? JSONEncoder().encode(reflections) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
