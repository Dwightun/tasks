import SwiftUI

/// Month grid for marking past days retroactively.
struct MonthCalendar: View {
    let habit: Habit
    let onToggle: (Date) -> Void
    let onSetStatus: (Date, DayStatus?, SkipReason?) -> Void

    @State private var monthStart = MonthCalendar.startOfMonth(Date())

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let isCurrentMonth = monthStart >= MonthCalendar.startOfMonth(today, calendar: calendar)
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let leadingBlanks = Habit.mondayIndex(of: monthStart, calendar: calendar)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        VStack(spacing: 10) {
            HStack {
                Button { shift(by: -1) } label: {
                    Image(systemName: "chevron.left").padding(8)
                }
                Spacer()
                Text(Self.titleFormatter.string(from: monthStart).capitalized)
                    .font(.headline)
                Spacer()
                Button { shift(by: 1) } label: {
                    Image(systemName: "chevron.right").padding(8)
                }
                .disabled(isCurrentMonth)
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Habit.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
                // One ForEach for blanks and days: separate ones reuse ids (0, 1, 2…) and LazyVGrid drops the duplicates.
                ForEach(0..<(leadingBlanks + dayCount), id: \.self) { index in
                    if index < leadingBlanks {
                        Color.clear.frame(height: 36)
                    } else {
                        dayCell(
                            date: calendar.date(byAdding: .day, value: index - leadingBlanks, to: monthStart) ?? monthStart,
                            today: today
                        )
                    }
                }
            }
        }
    }

    private func dayCell(date: Date, today: Date) -> some View {
        let calendar = Calendar.current
        let isFuture = date > today
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let key = DayKey.key(for: date, calendar: calendar)
        let status = habit.status(onKey: key)
        let paused = habit.isPaused(onKey: key)
        let highlighted: Bool
        if case .timesPerWeek = habit.periodicity(onKey: key) {
            highlighted = !paused
        } else {
            highlighted = habit.isDue(on: date, calendar: calendar)
        }
        let color = Color(hex: habit.colorHex)

        return Button {
            onToggle(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .foregroundStyle(status == .full ? Color.white : (highlighted ? Color.primary : Color.secondary))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    if status == .full {
                        Circle().fill(color)
                    } else if status == .minimal {
                        Circle().fill(color.opacity(0.4))
                    } else if status == .rest {
                        Circle().fill(Color.secondary.opacity(0.15))
                    } else if status == .skipped {
                        Circle().strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    } else if isToday {
                        Circle().strokeBorder(color, lineWidth: 1.5)
                    }
                }
                .contentShape(Rectangle())
                .opacity(isFuture ? 0.3 : (paused ? 0.45 : 1))
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

    private func shift(by months: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: months, to: monthStart) {
            monthStart = next
        }
    }
}
