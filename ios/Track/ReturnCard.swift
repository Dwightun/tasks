import SwiftUI

enum RelativeDay {
    private static let accusative = ["в понедельник", "во вторник", "в среду", "в четверг", "в пятницу", "в субботу", "в воскресенье"]

    static func phrase(for date: Date, today: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: date)
        ).day ?? 0
        switch days {
        case 0: return "сегодня"
        case 1: return "завтра"
        case -1: return "вчера"
        default: return accusative[Habit.mondayIndex(of: date, calendar: calendar)]
        }
    }
}

/// Calm nudge after a missed opportunity: keeps history intact and points to the next realistic chance.
struct ReturnCard: View {
    let habit: Habit
    let prompt: ReturnPrompt
    let onMinimalToday: () -> Void
    let onReason: (SkipReason) -> Void
    let onRest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: habit.colorHex))
                    .frame(width: 10, height: 10)
                Text(habit.name)
                    .font(.subheadline.weight(.semibold))
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if isNextToday {
                    Button("Сделать минимум", action: onMinimalToday)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: habit.colorHex))
                }
                Menu {
                    ForEach(SkipReason.allCases, id: \.self) { reason in
                        Button(reason.title) { onReason(reason) }
                    }
                    Divider()
                    Button("Это был день отдыха", action: onRest)
                } label: {
                    Text("Что помешало?")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var isNextToday: Bool {
        prompt.nextOpportunity.map { Calendar.current.isDateInToday($0) } ?? false
    }

    private var message: String {
        let missed = RelativeDay.phrase(for: prompt.missedDay)
        let start = missed.prefix(1).uppercased() + missed.dropFirst()
        let next = prompt.nextOpportunity.map { "Следующая возможность — \(RelativeDay.phrase(for: $0))." } ?? ""
        return "\(start) не получилось — так бывает. \(next)"
    }
}
