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

                    HStack(spacing: 10) {
                        statTile(value: habit.currentStreak(), label: "Серия")
                        statTile(value: habit.bestStreak(), label: "Рекорд")
                        statTile(value: habit.completions.count, label: "Всего")
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

    private func statTile(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
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
