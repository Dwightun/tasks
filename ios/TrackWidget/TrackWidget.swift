import AppIntents
import SwiftUI
import WidgetKit

private func nextMidnight(after date: Date = Date()) -> Date {
    let calendar = Calendar.current
    return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(3600)
}

// MARK: - Habit list widget

struct HabitListEntry: TimelineEntry {
    let date: Date
    let habits: [Habit]
}

struct HabitListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitListEntry {
        HabitListEntry(date: Date(), habits: [
            Habit(name: "Зарядка", colorHex: "#38D9A9"),
            Habit(name: "Чтение", colorHex: "#4DABF7"),
        ])
    }

    func snapshot(for configuration: HabitListConfigIntent, in context: Context) async -> HabitListEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: HabitListConfigIntent, in context: Context) async -> Timeline<HabitListEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .after(nextMidnight()))
    }

    private func entry(for configuration: HabitListConfigIntent) -> HabitListEntry {
        let now = Date()
        let all = HabitStorage.load()
        let selectedIDs = (configuration.habits ?? []).map(\.id)
        let habits = selectedIDs.isEmpty
            ? all.filter { $0.isPlanned(on: now) }
            : selectedIDs.compactMap { id in all.first { $0.id.uuidString == id } }
        return HabitListEntry(date: now, habits: habits)
    }
}

struct HabitListWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitListEntry

    private var limit: Int {
        family == .systemLarge ? 8 : 3
    }

    var body: some View {
        Group {
            if entry.habits.isEmpty {
                Text("На сегодня привычек нет")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.habits.prefix(limit)) { habit in
                        HabitWidgetRow(habit: habit, date: entry.date)
                    }
                    if entry.habits.count > limit {
                        Text("ещё \(entry.habits.count - limit)")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct HabitWidgetRow: View {
    let habit: Habit
    let date: Date

    var body: some View {
        let done = habit.isCompleted(on: date)

        Button(intent: ToggleHabitIntent(habitID: habit.id)) {
            HStack(spacing: 8) {
                CheckCircle(color: Color(hex: habit.colorHex), status: habit.status(onKey: DayKey.key(for: date)), size: 22, progress: habit.progress(onKey: DayKey.key(for: date)))
                Text(habit.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(done ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct HabitListWidget: Widget {
    // Same kind as the original static widget, so widgets already on the Home Screen keep working.
    let kind = "TrackWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: HabitListConfigIntent.self, provider: HabitListProvider()) { entry in
            HabitListWidgetView(entry: entry)
        }
        .configurationDisplayName("Привычки")
        .description("Отмечайте привычки прямо с экрана «Домой». Удерживайте виджет → «Изменить», чтобы выбрать привычки.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Activity widget

struct ActivityEntry: TimelineEntry {
    let date: Date
    /// nil means all habits combined.
    let habit: Habit?
    let habits: [Habit]
}

struct ActivityProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ActivityEntry {
        ActivityEntry(date: Date(), habit: nil, habits: [])
    }

    func snapshot(for configuration: HabitActivityConfigIntent, in context: Context) async -> ActivityEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: HabitActivityConfigIntent, in context: Context) async -> Timeline<ActivityEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .after(nextMidnight()))
    }

    private func entry(for configuration: HabitActivityConfigIntent) -> ActivityEntry {
        let habits = HabitStorage.load()
        let selected = configuration.habit.flatMap { entity in
            habits.first { $0.id.uuidString == entity.id }
        }
        return ActivityEntry(date: Date(), habit: selected, habits: habits)
    }
}

struct ActivityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ActivityEntry

    private var weeks: Int {
        family == .systemSmall ? 8 : 20
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            HeatmapGrid(weeks: weeks, cell: 11, gap: 3, today: entry.date, fill: fill)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var fill: (String) -> Color {
        if let habit = entry.habit {
            return Heatmap.habitFill(for: habit)
        }
        return Heatmap.combinedFill(for: entry.habits)
    }

    @ViewBuilder
    private var header: some View {
        if let habit = entry.habit {
            HStack(spacing: 6) {
                Text(habit.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button(intent: ToggleHabitIntent(habitID: habit.id)) {
                    CheckCircle(color: Color(hex: habit.colorHex), status: habit.status(onKey: DayKey.key(for: entry.date)), size: 20, progress: habit.progress(onKey: DayKey.key(for: entry.date)))
                }
                .buttonStyle(.plain)
            }
        } else {
            let due = entry.habits.filter { $0.isPlanned(on: entry.date) }
            let done = due.filter { $0.isCompleted(on: entry.date) }.count
            HStack(spacing: 6) {
                Text("Все привычки")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(done)/\(due.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

struct HabitActivityWidget: Widget {
    let kind = "TrackActivityWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: HabitActivityConfigIntent.self, provider: ActivityProvider()) { entry in
            ActivityWidgetView(entry: entry)
        }
        .configurationDisplayName("Активность")
        .description("Карта активности привычки. Удерживайте виджет → «Изменить», чтобы выбрать привычку.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock Screen widget

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitListEntry {
        HabitListEntry(date: Date(), habits: [Habit(name: "Прогулка", colorHex: "#69DB7C")])
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitListEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitListEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(nextMidnight())))
    }

    private func currentEntry() -> HabitListEntry {
        let now = Date()
        return HabitListEntry(date: now, habits: HabitStorage.load().filter { $0.isPlanned(on: now) })
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitListEntry

    private var done: Int {
        entry.habits.filter { $0.isCompleted(on: entry.date) }.count
    }

    private var nextHabit: Habit? {
        entry.habits.first { !$0.isCompleted(on: entry.date) }
    }

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            if entry.habits.isEmpty {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "checkmark")
                }
            } else {
                Gauge(value: Double(done), in: 0...Double(entry.habits.count)) {
                    Image(systemName: "checkmark")
                } currentValueLabel: {
                    Text("\(done)/\(entry.habits.count)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        case .accessoryInline:
            Text(entry.habits.isEmpty ? "Привычки: на сегодня всё" : "Привычки: \(done) из \(entry.habits.count)")
        default:
            rectangular
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let habit = nextHabit {
            Button(intent: ToggleHabitIntent(habitID: habit.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                        Text(habit.name)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Text("Сегодня \(done) из \(entry.habits.count) · нажмите, чтобы отметить")
                        .font(.caption)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("На сегодня всё")
                        .font(.headline)
                }
                Text(entry.habits.isEmpty ? "Нет запланированных привычек" : "Выполнено \(done) из \(entry.habits.count)")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TodayWidget: Widget {
    let kind = "TrackTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Сегодня")
        .description("Прогресс за день и отметка ближайшей привычки прямо с экрана блокировки.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Single habit Lock Screen widget

struct SingleHabitEntry: TimelineEntry {
    let date: Date
    let habit: Habit?
}

struct SingleHabitProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SingleHabitEntry {
        var sample = Habit(name: "Вода", colorHex: "#4DABF7")
        sample.icon = "drop"
        return SingleHabitEntry(date: Date(), habit: sample)
    }

    func snapshot(for configuration: SingleHabitConfigIntent, in context: Context) async -> SingleHabitEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SingleHabitConfigIntent, in context: Context) async -> Timeline<SingleHabitEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .after(nextMidnight()))
    }

    private func entry(for configuration: SingleHabitConfigIntent) -> SingleHabitEntry {
        let now = Date()
        let habits = HabitStorage.load()
        let chosen = configuration.habit.flatMap { entity in habits.first { $0.id.uuidString == entity.id } }
        let fallback = habits.first { $0.isPlanned(on: now) && !$0.isCompleted(on: now) }
            ?? habits.first { $0.isPlanned(on: now) }
            ?? habits.first
        return SingleHabitEntry(date: now, habit: chosen ?? fallback)
    }
}

struct SingleHabitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SingleHabitEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var content: some View {
        if let habit = entry.habit {
            let key = DayKey.key(for: entry.date)
            let progress = habit.progress(onKey: key)
            Button(intent: ToggleHabitIntent(habitID: habit.id)) {
                if family == .accessoryCircular {
                    Gauge(value: progress) {
                        Image(systemName: habit.icon ?? "checkmark")
                    } currentValueLabel: {
                        Image(systemName: habit.isCompleted(onKey: key) ? "checkmark" : (habit.icon ?? "circle"))
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: habit.icon ?? "circle")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name)
                                .font(.headline)
                                .lineLimit(1)
                            Text(statusText(habit, key: key))
                                .font(.caption)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        } else {
            Text("Нет привычек")
                .font(.caption)
        }
    }

    private func statusText(_ habit: Habit, key: String) -> String {
        if habit.isCompleted(onKey: key) { return "Выполнено ✓" }
        if habit.dailyTarget > 1 { return "\(habit.count(onKey: key)) из \(habit.dailyTarget) · нажмите +1" }
        return "Нажмите, чтобы отметить"
    }
}

struct SingleHabitWidget: Widget {
    let kind = "TrackSingleHabitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SingleHabitConfigIntent.self, provider: SingleHabitProvider()) { entry in
            SingleHabitWidgetView(entry: entry)
        }
        .configurationDisplayName("Привычка")
        .description("Иконка и прогресс одной привычки; нажатие отмечает выполнение.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

@main
struct TrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitListWidget()
        HabitActivityWidget()
        TodayWidget()
        SingleHabitWidget()
    }
}
