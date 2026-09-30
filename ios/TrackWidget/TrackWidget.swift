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
            ? all.filter { $0.isDue(on: now) }
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
        let done = habit.isDone(on: date)

        Button(intent: ToggleHabitIntent(habitID: habit.id)) {
            HStack(spacing: 8) {
                CheckCircle(color: Color(hex: habit.colorHex), done: done, size: 22)
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
                    CheckCircle(color: Color(hex: habit.colorHex), done: habit.isDone(on: entry.date), size: 20)
                }
                .buttonStyle(.plain)
            }
        } else {
            let due = entry.habits.filter { $0.isDue(on: entry.date) }
            let done = due.filter { $0.isDone(on: entry.date) }.count
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

@main
struct TrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitListWidget()
        HabitActivityWidget()
    }
}
