import AppIntents
import WidgetKit

struct HabitEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Привычка"
    static var defaultQuery = HabitEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(habit: Habit) {
        id = habit.id.uuidString
        name = habit.name
    }
}

struct HabitEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        HabitStorage.load()
            .filter { identifiers.contains($0.id.uuidString) }
            .map { HabitEntity(habit: $0) }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        HabitStorage.load().map { HabitEntity(habit: $0) }
    }
}

struct HabitListConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Привычки"
    static var description = IntentDescription("Выберите привычки. Если ничего не выбрано, показываются все привычки на сегодня.")

    @Parameter(title: "Привычки")
    var habits: [HabitEntity]?

    init() {}
}

struct HabitActivityConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Активность"
    static var description = IntentDescription("Карта активности одной привычки. Если не выбрана, показываются все привычки вместе.")

    @Parameter(title: "Привычка")
    var habit: HabitEntity?

    init() {}
}
