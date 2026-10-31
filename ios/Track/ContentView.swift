import SwiftUI
import WidgetKit

struct ContentView: View {
    @EnvironmentObject private var store: HabitStore
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("widgetTipDismissed") private var widgetTipDismissed = false
    @State private var hasWidget = true
    @State private var isCreating = false
    @State private var creatingTemplate: HabitTemplate?
    @State private var isShowingSettings = false
    @State private var pendingMood: Int?
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.habits.isEmpty {
                        emptyState
                    } else {
                        reviewPrompt
                        checkInCard
                        returnCards
                        widgetTip
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
                                    },
                                    onRemoveRepetition: { store.removeRepetition(habit.id, on: Date()) }
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
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Настройки")
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
            .fullScreenCover(isPresented: Binding(
                get: { !onboardingCompleted && store.habits.isEmpty },
                set: { _ in }
            )) {
                OnboardingView { skipped in
                    onboardingCompleted = true
                    Analytics.send(skipped ? "Onboarding.skipped" : "Onboarding.completed")
                }
            }
            .task(id: scenePhase) {
                if scenePhase == .active { hasWidget = await installedWidgetCount() > 0 }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsSheet().environmentObject(store)
            }
            .sheet(isPresented: $router.showCheckIn, onDismiss: { pendingMood = nil }) {
                CheckInSheet(date: Date(), existing: store.reflection(on: Date()), preselectedMood: pendingMood)
                    .environmentObject(store)
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

    /// The widget is the core of one-tap logging; the tip hides itself once any widget is installed.
    @ViewBuilder
    private var widgetTip: some View {
        if !hasWidget, !widgetTipDismissed {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.title3)
                    .foregroundStyle(Heatmap.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Добавьте виджет")
                        .font(.subheadline.weight(.semibold))
                    Text("Удерживайте экран «Домой» → «Изменить» → «Добавить виджет» → «Привычки». Отмечать станет можно одним касанием.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    widgetTipDismissed = true
                    Analytics.send("WidgetTip.dismissed")
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Скрыть подсказку")
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func installedWidgetCount() async -> Int {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                continuation.resume(returning: (try? result.get())?.count ?? 0)
            }
        }
    }

    /// From the chosen evening time: one tap on a mood opens the check-in with it preselected.
    @ViewBuilder
    private var checkInCard: some View {
        let now = Date()
        let time = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minutesNow = (time.hour ?? 0) * 60 + (time.minute ?? 0)

        if ReviewSettings.checkInEnabled, minutesNow >= ReviewSettings.checkInMinutes {
            if let reflection = store.reflection(on: now) {
                Button {
                    router.showCheckIn = true
                } label: {
                    HStack(spacing: 10) {
                        Text(reflection.symbol)
                            .font(.title2)
                        Text("Сегодня: \(reflection.title.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text("Изменить")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Как прошёл день?")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 0) {
                        ForEach(1...5, id: \.self) { mood in
                            Button {
                                pendingMood = mood
                                router.showCheckIn = true
                            } label: {
                                Text(DayReflection.moodSymbols[mood - 1])
                                    .font(.system(size: 30))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(DayReflection.moodTitles[mood - 1])
                        }
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private func templateSubtitle(_ template: HabitTemplate) -> String {
        var parts: [String] = [template.periodicity.label]
        if template.dailyTarget > 1 {
            parts.append("\(template.dailyTarget) раз в день")
        }
        if let minimal = template.plan.minimalVersion {
            parts.append("минимум: \(minimal.lowercased())")
        }
        return parts.joined(separator: " · ")
    }

    private func templateRow(_ template: HabitTemplate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: template.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: template.colorHex))
                .frame(width: 36, height: 36)
                .background(Color(hex: template.colorHex).opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(templateSubtitle(template))
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
