import SwiftUI

/// GitLab-style contribution grid: one cell per day, shaded by how many habits were completed.
struct ActivityHeatmap: View {
    let habits: [Habit]

    private let weeks = 26
    private let cell: CGFloat = 12
    private let gap: CGFloat = 3
    private let monthRowHeight: CGFloat = 14
    private let accent = Color(hex: "#38D9A9")

    private static let monthSymbols = ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
    private static let weekdayLabels = ["Пн", "", "Ср", "", "Пт", "", ""]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayKey = DayKey.key(for: today)
        let start = startDate(today: today, calendar: calendar)
        let counts = dayCounts()

        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: gap) {
                ForEach(0..<7, id: \.self) { row in
                    Text(Self.weekdayLabels[row])
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary)
                        .frame(height: cell)
                }
            }
            .padding(.top, monthRowHeight + gap)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: gap) {
                    HStack(spacing: gap) {
                        ForEach(0..<weeks, id: \.self) { week in
                            monthLabel(week: week, start: start, calendar: calendar)
                        }
                    }
                    HStack(spacing: gap) {
                        ForEach(0..<weeks, id: \.self) { week in
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { day in
                                    dayCell(
                                        key: DayKey.key(for: date(week: week, day: day, start: start, calendar: calendar)),
                                        todayKey: todayKey,
                                        counts: counts
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .defaultScrollAnchor(.trailing)
        }
    }

    private func date(week: Int, day: Int, start: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: week * 7 + day, to: start) ?? start
    }

    private func monthLabel(week: Int, start: Date, calendar: Calendar) -> some View {
        let month = calendar.component(.month, from: date(week: week, day: 0, start: start, calendar: calendar))
        let previous: Int? = week == 0
            ? nil
            : calendar.component(.month, from: date(week: week - 1, day: 0, start: start, calendar: calendar))
        return Text(month != previous ? Self.monthSymbols[month - 1] : "")
            .font(.system(size: 9))
            .foregroundStyle(Color.secondary)
            .fixedSize()
            .frame(width: cell, height: monthRowHeight, alignment: .leading)
    }

    private func dayCell(key: String, todayKey: String, counts: [String: Int]) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(key > todayKey ? Color.clear : fill(for: counts[key] ?? 0))
            .frame(width: cell, height: cell)
            .overlay {
                if key == todayKey {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.secondary, lineWidth: 1)
                }
            }
    }

    private func fill(for count: Int) -> Color {
        switch count {
        case 0: return Color(.tertiarySystemFill)
        case 1: return accent.opacity(0.35)
        case 2: return accent.opacity(0.65)
        default: return accent
        }
    }

    private func startDate(today: Date, calendar: Calendar) -> Date {
        let thisMonday = calendar.date(byAdding: .day, value: -Habit.mondayIndex(of: today, calendar: calendar), to: today) ?? today
        return calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: thisMonday) ?? thisMonday
    }

    private func dayCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for habit in habits {
            for key in habit.completions {
                counts[key, default: 0] += 1
            }
        }
        return counts
    }
}
