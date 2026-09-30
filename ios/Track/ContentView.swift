import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HabitStore
    @State private var isCreating = false
    @State private var editing: Habit?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.habits.isEmpty {
                        emptyState
                    } else {
                        ActivityHeatmap(habits: store.habits)
                        VStack(spacing: 10) {
                            ForEach(store.habits) { habit in
                                HabitRow(
                                    habit: habit,
                                    onEdit: { editing = habit },
                                    onToggle: { store.toggleToday(habit.id) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Привычки")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isCreating) {
                HabitEditor(habit: nil).environmentObject(store)
            }
            .sheet(item: $editing) { habit in
                HabitEditor(habit: habit).environmentObject(store)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("Пока нет привычек")
                .foregroundStyle(.secondary)
            Button("Добавить первую") { isCreating = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
