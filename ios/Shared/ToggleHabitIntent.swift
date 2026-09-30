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
            HabitStorage.toggle(habitID: id)
        }
        return .result()
    }
}
