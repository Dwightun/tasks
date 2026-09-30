import AppIntents
import SwiftUI
import WidgetKit

struct HabitEntry: TimelineEntry {
    let date: Date
    let habits: [Habit]
}

struct HabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date(), habits: [
            Habit(name: "Зарядка", colorHex: "#38D9A9"),
            Habit(name: "Чтение", colorHex: "#4DABF7"),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> HabitEntry {
        let now = Date()
        return HabitEntry(date: now, habits: HabitStorage.load().filter { $0.isDue(on: now) })
    }
}

struct TrackWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitEntry

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
        let color = Color(hex: habit.colorHex)
        let done = habit.isDone(on: date)

        Button(intent: ToggleHabitIntent(habitID: habit.id)) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().strokeBorder(color, lineWidth: 2)
                    if done {
                        Circle().fill(color)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 22, height: 22)

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

struct TrackWidget: Widget {
    let kind = "TrackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            TrackWidgetView(entry: entry)
        }
        .configurationDisplayName("Привычки")
        .description("Отмечайте привычки прямо с экрана «Домой».")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct TrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrackWidget()
    }
}
