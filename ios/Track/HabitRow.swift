import SwiftUI

struct HabitRow: View {
    let habit: Habit
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        let color = Color(hex: habit.colorHex)
        let done = habit.isDoneToday

        // Two sibling buttons rather than nested ones, so a tap on the circle never opens the editor.
        HStack(spacing: 14) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(done ? color : Color(.separator), lineWidth: 2)
                    if done {
                        Circle().fill(color)
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 44, height: 44)
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
        let streak = habit.currentStreak()
        return streak > 0 ? "\(habit.periodLabel) · серия \(streak) 🔥" : habit.periodLabel
    }
}
