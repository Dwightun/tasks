import SwiftUI

/// GitLab-style contribution grid with month and weekday labels, scrollable back in time.
struct ActivityHeatmap: View {
    let fill: (String) -> Color
    var weeks = 26

    private let cell: CGFloat = 12
    private let gap: CGFloat = 3
    private let monthRowHeight: CGFloat = 14

    private static let monthSymbols = ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
    private static let weekdayLabels = ["Пн", "", "Ср", "", "Пт", "", ""]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = Heatmap.startDate(weeks: weeks, today: today, calendar: calendar)

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
                    HeatmapGrid(weeks: weeks, cell: cell, gap: gap, today: today, fill: fill)
                }
            }
            .defaultScrollAnchor(.trailing)
        }
    }

    private func monthLabel(week: Int, start: Date, calendar: Calendar) -> some View {
        let month = calendar.component(.month, from: Heatmap.date(week: week, day: 0, start: start, calendar: calendar))
        let previous: Int? = week == 0
            ? nil
            : calendar.component(.month, from: Heatmap.date(week: week - 1, day: 0, start: start, calendar: calendar))
        return Text(month != previous ? Self.monthSymbols[month - 1] : "")
            .font(.system(size: 9))
            .foregroundStyle(Color.secondary)
            .fixedSize()
            .frame(width: cell, height: monthRowHeight, alignment: .leading)
    }
}
