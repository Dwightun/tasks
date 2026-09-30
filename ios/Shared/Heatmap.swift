import SwiftUI

enum Heatmap {
    static let accent = Color(hex: "#38D9A9")
    static let emptyFill = Color(.tertiarySystemFill)

    /// Monday of the first column, so the last column is the current week.
    static func startDate(weeks: Int, today: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: today)
        let thisMonday = calendar.date(byAdding: .day, value: -Habit.mondayIndex(of: day, calendar: calendar), to: day) ?? day
        return calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: thisMonday) ?? thisMonday
    }

    static func date(week: Int, day: Int, start: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: week * 7 + day, to: start) ?? start
    }

    /// All habits combined: shade grows with the number of habits completed that day.
    static func combinedFill(for habits: [Habit]) -> (String) -> Color {
        var counts: [String: Int] = [:]
        for habit in habits {
            for key in habit.completions {
                counts[key, default: 0] += 1
            }
        }
        return { key in
            switch counts[key] ?? 0 {
            case 0: return emptyFill
            case 1: return accent.opacity(0.35)
            case 2: return accent.opacity(0.65)
            default: return accent
            }
        }
    }

    /// Single habit: its own color on completed days.
    static func habitFill(for habit: Habit) -> (String) -> Color {
        let color = Color(hex: habit.colorHex)
        return { key in habit.completions.contains(key) ? color : emptyFill }
    }
}

/// Weeks as columns, Monday-first rows; future days are left blank.
struct HeatmapGrid: View {
    let weeks: Int
    let cell: CGFloat
    let gap: CGFloat
    let today: Date
    let fill: (String) -> Color

    var body: some View {
        let calendar = Calendar.current
        let todayKey = DayKey.key(for: today, calendar: calendar)
        let start = Heatmap.startDate(weeks: weeks, today: today, calendar: calendar)

        HStack(spacing: gap) {
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { day in
                        cellView(
                            key: DayKey.key(for: Heatmap.date(week: week, day: day, start: start, calendar: calendar), calendar: calendar),
                            todayKey: todayKey
                        )
                    }
                }
            }
        }
    }

    private func cellView(key: String, todayKey: String) -> some View {
        RoundedRectangle(cornerRadius: cell / 4, style: .continuous)
            .fill(key > todayKey ? Color.clear : fill(key))
            .frame(width: cell, height: cell)
            .overlay {
                if key == todayKey {
                    RoundedRectangle(cornerRadius: cell / 4, style: .continuous)
                        .strokeBorder(Color.secondary, lineWidth: 1)
                }
            }
    }
}
