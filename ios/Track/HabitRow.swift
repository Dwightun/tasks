import SwiftUI

struct HabitRow: View {
    let habit: Habit
    let onOpen: () -> Void
    let onToggle: () -> Void

    var body: some View {
        let done = habit.isDoneToday

        // Two sibling buttons rather than nested ones, so a tap on the circle never opens the details.
        HStack(spacing: 14) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                CheckCircle(color: Color(hex: habit.colorHex), done: done, size: 44, idleColor: Color(.separator))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: done) { _, newValue in newValue }
        }
        .padding(14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var subtitle: String {
        var parts = [habit.periodLabel]
        if let time = habit.reminderLabel { parts.append("🔔 \(time)") }
        let streak = habit.currentStreak()
        if streak > 0 { parts.append("серия \(streak) 🔥") }
        return parts.joined(separator: " · ")
    }
}
