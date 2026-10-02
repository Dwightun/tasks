import SwiftUI

/// Context-menu items for recording what happened on a day.
struct StatusMenuItems: View {
    let habit: Habit
    let current: DayStatus?
    let onSelect: (DayStatus?, SkipReason?) -> Void

    var body: some View {
        Button {
            onSelect(.full, nil)
        } label: {
            Label("Выполнено полностью", systemImage: "checkmark.circle.fill")
        }
        Button {
            onSelect(.minimal, nil)
        } label: {
            Label(minimalTitle, systemImage: "circle.lefthalf.filled")
        }
        Button {
            onSelect(.rest, nil)
        } label: {
            Label("Отдых", systemImage: "moon")
        }
        Menu {
            ForEach(SkipReason.allCases, id: \.self) { reason in
                Button(reason.title) { onSelect(.skipped, reason) }
            }
        } label: {
            Label("Пропуск…", systemImage: "xmark.circle")
        }
        if current != nil {
            Button(role: .destructive) {
                onSelect(nil, nil)
            } label: {
                Label("Снять отметку", systemImage: "arrow.uturn.backward")
            }
        }
    }

    private var minimalTitle: String {
        if let text = habit.plan.minimalVersion, !text.isEmpty {
            return "Минимум: \(text)"
        }
        return "Минимальная версия"
    }
}
