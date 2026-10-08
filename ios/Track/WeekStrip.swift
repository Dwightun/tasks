import SwiftUI

/// Current week as seven tappable days; long press records minimal, rest or a skip.
struct WeekStrip: View {
    let habit: Habit
    let onToggle: (Date) -> Void
    let onSetStatus: (Date, DayStatus?, SkipReason?) -> Void

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monday = Habit.monday(of: today, calendar: calendar)

        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                dayView(
                    date: calendar.date(byAdding: .day, value: offset, to: monday) ?? monday,
                    index: offset,
                    today: today,
                    calendar: calendar
                )
            }
        }
    }

    private func dayView(date: Date, index: Int, today: Date, calendar: Calendar) -> some View {
        let key = DayKey.key(for: date, calendar: calendar)
        let status = habit.status(onKey: key)
        let isFuture = date > today
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let paused = habit.isPaused(onKey: key)
        let planned: Bool
        if case .timesPerWeek = habit.periodicity(onKey: key) {
            planned = !paused
        } else {
            planned = habit.isDue(on: date, calendar: calendar)
        }

        return Button {
            onToggle(date)
        } label: {
            VStack(spacing: 6) {
                Text(Habit.weekdaySymbols[index])
                    .font(.caption2.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.primary : Color.secondary)
                CheckCircle(
                    color: Color(hex: habit.colorHex),
                    status: status,
                    size: 34,
                    idleColor: planned ? Color(.separator) : Color(.separator).opacity(0.35)
                )
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .opacity(isFuture ? 0.35 : (paused ? 0.45 : 1))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .contextMenu {
            if !isFuture {
                StatusMenuItems(habit: habit, current: status) { newStatus, reason in
                    onSetStatus(date, newStatus, reason)
                }
            }
        }
    }
}
