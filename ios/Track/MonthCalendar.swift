import SwiftUI

/// Month grid for marking past days retroactively.
struct MonthCalendar: View {
    let habit: Habit
    let onToggle: (Date) -> Void

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
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 36)
                }
                ForEach(1...dayCount, id: \.self) { day in
                    dayCell(date: calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart, today: today)
                }
            }
        }
    }

    private func dayCell(date: Date, today: Date) -> some View {
        let calendar = Calendar.current
        let isFuture = date > today
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let done = habit.isDone(on: date)
        let due = habit.isDue(on: date, calendar: calendar)
        let color = Color(hex: habit.colorHex)

        return Button {
            onToggle(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .foregroundStyle(done ? Color.white : (due ? Color.primary : Color.secondary))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    if done {
                        Circle().fill(color)
                    } else if isToday {
                        Circle().strokeBorder(color, lineWidth: 1.5)
                    }
                }
                .contentShape(Rectangle())
                .opacity(isFuture ? 0.3 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func shift(by months: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: months, to: monthStart) {
            monthStart = next
        }
    }
}
