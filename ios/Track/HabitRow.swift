import SwiftUI

struct HabitRow: View {
    let habit: Habit
    let onOpen: () -> Void
    let onToggle: () -> Void
    let onSetStatus: (DayStatus?, SkipReason?) -> Void
    let onRemoveRepetition: () -> Void

    var body: some View {
        let today = Date()
        let todayKey = DayKey.key(for: today)
        let status = habit.status(onKey: todayKey)
        let paused = habit.activePause(on: today) != nil
        let color = Color(hex: habit.colorHex)

        // Two sibling buttons rather than nested ones, so a tap on the circle never opens the details.
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    if let icon = habit.icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(color)
                            .frame(width: 36, height: 36)
                            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                CheckCircle(
                    color: color,
                    status: status,
                    size: 44,
                    idleColor: Color(.separator),
                    progress: habit.progress(onKey: todayKey)
                )
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: habit.isCompleted(onKey: todayKey)) { _, newValue in newValue }
            .sensoryFeedback(.increase, trigger: habit.count(onKey: todayKey))
            .contextMenu {
                StatusMenuItems(
                    habit: habit,
                    current: status,
                    onSelect: onSetStatus,
                    onRemoveRepetition: onRemoveRepetition
                )
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
        var parts: [String] = []
        if habit.dailyTarget > 1 {
            parts.append("\(habit.count(onKey: DayKey.key(for: today)))/\(habit.dailyTarget) сегодня")
        }
        parts.append(habit.periodLabel)
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
