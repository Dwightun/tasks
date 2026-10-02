import SwiftUI

struct HabitRow: View {
    let habit: Habit
    let onOpen: () -> Void
    let onToggle: () -> Void
    let onSetStatus: (DayStatus?, SkipReason?) -> Void

    var body: some View {
        let today = Date()
        let status = habit.status(onKey: DayKey.key(for: today))
        let paused = habit.activePause(on: today) != nil

        // Two sibling buttons rather than nested ones, so a tap on the circle never opens the details.
        HStack(spacing: 14) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(subtitle(today: today))
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                CheckCircle(color: Color(hex: habit.colorHex), status: status, size: 44, idleColor: Color(.separator))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: habit.isCompleted(onKey: DayKey.key(for: today))) { _, newValue in newValue }
            .contextMenu {
                StatusMenuItems(habit: habit, current: status, onSelect: onSetStatus)
            }
        }
        .padding(14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .opacity(paused ? 0.6 : 1)
    }

    private func subtitle(today: Date) -> String {
        if let pause = habit.activePause(on: today) {
            return "⏸ \(pause.kind.title)" + (pause.end.flatMap { DayKey.date(from: $0) }.map { " до \(Self.shortDate($0))" } ?? "")
        }
        var parts = [habit.periodLabel]
        let week = habit.weekProgress(containing: today)
        if week.planned > 0 { parts.append("\(week.completed)/\(week.planned) за неделю") }
        if let time = habit.reminderLabel { parts.append("🔔 \(time)") }
        return parts.joined(separator: " · ")
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
