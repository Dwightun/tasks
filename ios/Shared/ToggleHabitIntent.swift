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
            let habits = HabitStorage.update(habitID: id) { $0.toggle() }
            await ReminderScheduler.reschedule(habits)
        }
        return .result()
    }
}
