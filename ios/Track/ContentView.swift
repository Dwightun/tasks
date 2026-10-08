import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HabitStore
    @ObservedObject private var router = AppRouter.shared
    @State private var isCreating = false
    @State private var creatingTemplate: HabitTemplate?
    @State private var isReordering = false
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.habits.isEmpty {
                        emptyState
                    } else {
                        reviewPrompt
                        returnCards
                        // Appears once there is history to show, and grows week by week.
                        let heatmapWeeks = Heatmap.weeksSpanning(
                            from: store.habits.map(\.startKey).min() ?? DayKey.key(for: Date())
                        )
                        if heatmapWeeks >= 2 {
                            ActivityHeatmap(fill: Heatmap.combinedFill(for: store.habits), weeks: heatmapWeeks)
                        }
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
                ToolbarItemGroup(placement: .topBarLeading) {
                    if !store.habits.isEmpty {
                        Button {
                            router.showWeeklyReview = true
                        } label: {
                            Image(systemName: "chart.bar.xaxis")
                        }
                        .accessibilityLabel("Итоги недели")
                    }
                    if store.habits.count > 1 {
                        Button {
                            isReordering = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel("Порядок привычек")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isCreating = true
                        } label: {
                            Label("Своя привычка", systemImage: "square.and.pencil")
                        }
                        Section("Шаблоны") {
                            ForEach(HabitTemplate.all) { template in
                                Button(template.name) { creatingTemplate = template }
                            }
                        }
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
            .sheet(item: $creatingTemplate) { template in
                HabitEditor(template: template).environmentObject(store)
            }
            .sheet(isPresented: $isReordering) {
                ReorderSheet().environmentObject(store)
            }
            .sheet(isPresented: $router.showWeeklyReview) {
                WeeklyReviewView().environmentObject(store)
            }
        }
    }

    /// Shown Sunday through Tuesday until the week is reviewed, and only if something was planned.
    @ViewBuilder
    private var reviewPrompt: some View {
        let today = Date()
        let weekStart = WeeklyReview.defaultWeekStart(today: today)
        let weekKey = DayKey.key(for: weekStart)
        let isReviewTime = [6, 0, 1].contains(Habit.mondayIndex(of: today))
        let hadPlan = store.habits.contains { $0.weekProgress(containing: weekStart).planned > 0 }

        if isReviewTime, hadPlan, store.lastReviewedWeek != weekKey {
            Button {
                router.showWeeklyReview = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title3)
                        .foregroundStyle(Heatmap.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Итоги недели")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text("Две минуты: что получилось, что мешало, что поменять")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.secondary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("С чего начнём?")
                .font(.title3.weight(.semibold))
            Text("Выберите готовую привычку — её можно поправить перед сохранением. Лучше начать с одной.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)

            VStack(spacing: 10) {
                ForEach(HabitTemplate.all) { template in
                    Button {
                        creatingTemplate = template
                    } label: {
                        templateRow(template)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                isCreating = true
            } label: {
                Label("Своя привычка", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.top, 8)
    }

    private func templateRow(_ template: HabitTemplate) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: template.colorHex))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text([template.periodicity.label, template.plan.minimalVersion.map { "минимум: \($0.lowercased())" }]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(hex: template.colorHex))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
