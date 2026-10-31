import AppIntents

struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Отметить привычку"
    static var isDiscoverable: Bool = false

    @Parameter(title: "ID привычки")
    var habitID: String

    init() {}

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: habitID) {
            let now = Date()
            let before = HabitStorage.load().first { $0.id == id }
            let habits = HabitStorage.update(habitID: id) { $0.toggle(on: now) }
            if let before, let after = habits.first(where: { $0.id == id }) {
                Analytics.recordMark(before: before, after: after, on: now, source: "widget")
            }
            await ReminderScheduler.reschedule(habits)
        }
        return .result()
    }
}
