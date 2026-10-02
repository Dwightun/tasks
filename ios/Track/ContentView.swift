import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HabitStore
    @State private var isCreating = false
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.habits.isEmpty {
                        emptyState
                    } else {
                        returnCards
                        ActivityHeatmap(fill: Heatmap.combinedFill(for: store.habits))
                        VStack(spacing: 10) {
                            ForEach(store.habits) { habit in
                                HabitRow(
                                    habit: habit,
                                    onOpen: { path.append(habit.id) },
                                    onToggle: { store.toggleToday(habit.id) },
                                    onSetStatus: { status, reason in
                                        store.setStatus(habit.id, status, on: Date(), reason: reason)
                                    }
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
            .navigationDestination(for: UUID.self) { id in
                HabitDetailView(habitID: id)
            }
            .sheet(isPresented: $isCreating) {
                HabitEditor(habit: nil).environmentObject(store)
            }
        }
    }

    private struct PromptItem: Identifiable {
        let habit: Habit
        let prompt: ReturnPrompt
        var id: UUID { habit.id }
    }

    @ViewBuilder
    private var returnCards: some View {
        let items = store.habits.compactMap { habit in
            habit.returnPrompt().map { PromptItem(habit: habit, prompt: $0) }
        }
        if !items.isEmpty {
            VStack(spacing: 10) {
                ForEach(items) { item in
                    ReturnCard(
                        habit: item.habit,
                        prompt: item.prompt,
                        onMinimalToday: { store.setStatus(item.habit.id, .minimal, on: Date()) },
                        onReason: { reason in
                            store.setStatus(item.habit.id, .skipped, on: item.prompt.missedDay, reason: reason)
                        },
                        onRest: { store.setStatus(item.habit.id, .rest, on: item.prompt.missedDay) }
                    )
                }
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
