import SwiftUI

/// Weekly plan-vs-fact review: name the main obstacle, then accept at most one change per habit.
struct WeeklyReviewView: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    @State private var weekStart = WeeklyReview.defaultWeekStart()
    @State private var editing: Habit?
    @State private var pausing: HabitRef?
    @State private var reminderOn = ReviewSettings.isEnabled
    @State private var reminderTime = WeeklyReviewView.time(fromMinutes: ReviewSettings.minutes)

    private struct HabitRef: Identifiable {
        let id: UUID
    }

    private let defaultWeekStart = WeeklyReview.defaultWeekStart()

    var body: some View {
        let today = Date()
        let habits = store.habits.filter { habit in
            let summary = habit.weekSummary(weekStart: weekStart, today: today)
            return summary.progress.planned > 0 || summary.progress.completed > 0
        }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    weekHeader
                    if habits.isEmpty {
                        Text("На этой неделе ничего не было запланировано.")
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        totals(habits, today: today)
                        ForEach(habits) { habit in
                            habitCard(habit, today: today)
                        }
                    }
                    reminderSettings
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Итоги недели")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        store.markReviewed(weekStart: weekStart)
                        dismiss()
                    }
                }
            }
            .sheet(item: $editing) { habit in
                HabitEditor(habit: habit).environmentObject(store)
            }
            .sheet(item: $pausing) { ref in
                PauseSheet { kind, end in
                    store.startPause(ref.id, kind: kind, until: end)
                }
            }
        }
    }

    // MARK: Sections

    private var weekHeader: some View {
        let calendar = Calendar.current
        let sunday = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return HStack {
            Button { shiftWeek(by: -1) } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            Spacer()
            Text("\(HabitRow.shortDate(weekStart)) – \(HabitRow.shortDate(sunday))")
                .font(.headline)
            Spacer()
            Button { shiftWeek(by: 1) } label: {
                Image(systemName: "chevron.right").padding(8)
            }
            .disabled(weekStart >= defaultWeekStart)
        }
        .buttonStyle(.borderless)
    }

    private func totals(_ habits: [Habit], today: Date) -> some View {
        let progress = habits.map { $0.weekSummary(weekStart: weekStart, today: today).progress }
        let planned = progress.reduce(0) { $0 + $1.planned }
        let completed = progress.reduce(0) { $0 + min($1.completed, $1.planned) }
        let minimal = progress.reduce(0) { $0 + $1.minimal }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Выполнено по плану")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            Text("\(completed) из \(planned)")
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            if minimal > 0 {
                Text("из них минимальной версией: \(minimal)")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func habitCard(_ habit: Habit, today: Date) -> some View {
        let summary = habit.weekSummary(weekStart: weekStart, today: today)
        let suggestion = habit.reviewSuggestion(weekStart: weekStart, today: today)
        let color = Color(hex: habit.colorHex)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(habit.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(summary.progress.completed) из \(summary.progress.planned)")
                    .font(.headline)
                    .monospacedDigit()
            }

            dayStrip(habit, color: color)

            if !summary.reasons.isEmpty {
                Text("Мешало: " + reasonsText(summary.reasons))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }

            if summary.unexplained > 0 {
                Menu {
                    ForEach(SkipReason.allCases, id: \.self) { reason in
                        Button(reason.title) {
                            store.setWeekReason(habit.id, weekStart: weekStart, reason: reason)
                        }
                    }
                } label: {
                    Label("Что мешало? Без отметки: \(summary.unexplained)", systemImage: "questionmark.circle")
                        .font(.subheadline)
                }
            }

            if let suggestion {
                suggestionBox(suggestion, habit: habit, color: color)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dayStrip(_ habit: Habit, color: Color) -> some View {
        let calendar = Calendar.current
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                let key = DayKey.key(for: day, calendar: calendar)
                let planned = habit.isDue(on: day, calendar: calendar)
                VStack(spacing: 4) {
                    Text(Habit.weekdaySymbols[offset])
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                    CheckCircle(
                        color: color,
                        status: habit.status(onKey: key),
                        size: 22,
                        idleColor: planned ? Color(.separator) : Color(.separator).opacity(0.3)
                    )
                    .opacity(habit.isPaused(onKey: key) ? 0.4 : 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func suggestionBox(_ suggestion: ReviewSuggestion, habit: Habit, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.title)
                .font(.subheadline.weight(.semibold))
            Text(suggestion.detail)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            actionButton(suggestion.action, habit: habit, color: color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func actionButton(_ action: ReviewSuggestion.Action, habit: Habit, color: Color) -> some View {
        switch action {
        case .none:
            EmptyView()
        case .editPlan:
            Button("Открыть план") { editing = habit }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .pause:
            Button("Поставить на паузу") { pausing = HabitRef(id: habit.id) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .changePeriodicity(let periodicity):
            if habit.periodicity == periodicity {
                Label("Применено: \(periodicity.label.lowercased()) с \(HabitRow.shortDate(WeeklyReview.effectiveDateForChange()))", systemImage: "checkmark")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            } else {
                Button("Применить: \(periodicity.label.lowercased())") {
                    store.applyPeriodicity(habit.id, periodicity)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
                .controlSize(.small)
            }
        }
    }

    private var reminderSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Напоминать в воскресенье", isOn: $reminderOn)
            if reminderOn {
                DatePicker("Время", selection: $reminderTime, displayedComponents: .hourAndMinute)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: reminderOn) { _, _ in saveReminder() }
        .onChange(of: reminderTime) { _, _ in saveReminder() }
    }

    // MARK: Helpers

    private func saveReminder() {
        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        store.updateReviewReminder(enabled: reminderOn, minutes: (time.hour ?? 19) * 60 + (time.minute ?? 0))
    }

    private func shiftWeek(by weeks: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: 7 * weeks, to: weekStart) {
            weekStart = min(next, defaultWeekStart)
        }
    }

    private func reasonsText(_ reasons: [SkipReason: Int]) -> String {
        SkipReason.allCases
            .compactMap { reason in reasons[reason].map { "\(reason.title.lowercased()) ×\($0)" } }
            .joined(separator: ", ")
    }

    private static func time(fromMinutes minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }
}
