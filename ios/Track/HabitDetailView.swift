import SwiftUI

struct HabitDetailView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    let habitID: UUID
    @State private var isEditing = false

    private var habit: Habit? {
        store.habits.first { $0.id == habitID }
    }

    var body: some View {
        if let habit {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(subtitle(for: habit))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)

                    weekTile(habit.weekProgress(containing: Date()))

                    let streak = habit.streak()
                    HStack(spacing: 10) {
                        statTile(value: "\(streak.current)", label: streakLabel("Серия", streak.unit))
                        statTile(value: "\(streak.best)", label: streakLabel("Рекорд", streak.unit))
                        statTile(value: "\(habit.totalCompleted)", label: "Всего")
                    }

                    card("Активность") {
                        ActivityHeatmap(fill: Heatmap.habitFill(for: habit))
                    }

                    card("История") {
                        MonthCalendar(habit: habit) { date in
                            store.toggle(habitID, on: date)
                        }
                        Text("Нажмите на день, чтобы отметить или снять выполнение.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Изменить") { isEditing = true }
                }
            }
            .sheet(isPresented: $isEditing) {
                HabitEditor(habit: habit).environmentObject(store)
            }
        } else {
            // The habit was deleted from the editor: leave the screen.
            Color.clear.onAppear { dismiss() }
        }
    }

    private func subtitle(for habit: Habit) -> String {
        var parts = [habit.periodLabel]
        if let time = habit.reminderLabel { parts.append("напоминание в \(time)") }
        return parts.joined(separator: " · ")
    }

    private func weekTile(_ week: WeekProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Эта неделя")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(week.completed) из \(week.planned)")
                    .font(.largeTitle.weight(.bold))
                    .monospacedDigit()
                if week.minimal > 0 {
                    Text("в т.ч. минимум: \(week.minimal)")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            ProgressView(value: Double(min(week.completed, max(week.planned, 1))), total: Double(max(week.planned, 1)))
                .tint(Color(hex: habit?.colorHex ?? "#38D9A9"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func streakLabel(_ title: String, _ unit: Streak.Unit) -> String {
        unit == .weeks ? "\(title), нед." : "\(title), дн."
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
