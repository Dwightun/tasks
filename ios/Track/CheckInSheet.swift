import SwiftUI

/// Evening check-in: mood plus a free note, shown next to what was actually done that day.
struct CheckInSheet: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    let date: Date
    private let isExisting: Bool
    @State private var mood: Int?
    @State private var note: String

    init(date: Date, existing: DayReflection?, preselectedMood: Int? = nil) {
        self.date = date
        isExisting = existing != nil
        _mood = State(initialValue: preselectedMood ?? existing?.mood)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        let completed = store.habits.filter { $0.isCompleted(on: date) }

        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { value in
                            moodButton(value)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Как прошёл день?")
                }

                Section("Что повлияло") {
                    TextField("Например: выспался, тяжёлая встреча, прогулка с другом", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Отмечено за день") {
                    if completed.isEmpty {
                        Text("Ничего не отмечено — и так бывает.")
                            .foregroundStyle(Color.secondary)
                    } else {
                        ForEach(completed) { habit in
                            Label(habit.name, systemImage: habit.icon ?? "checkmark.circle")
                                .foregroundStyle(Color(hex: habit.colorHex))
                        }
                    }
                }

                if isExisting {
                    Section {
                        Button("Удалить запись", role: .destructive) {
                            store.setReflection(nil, on: date)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { save() }
                        .disabled(mood == nil)
                }
            }
        }
    }

    private var title: String {
        if Calendar.current.isDateInToday(date) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(date) { return "Вчера" }
        return HabitRow.shortDate(date)
    }

    private func moodButton(_ value: Int) -> some View {
        let selected = mood == value
        return Button {
            mood = value
        } label: {
            VStack(spacing: 4) {
                Text(DayReflection.moodSymbols[value - 1])
                    .font(.system(size: 30))
                Text(DayReflection.moodTitles[value - 1])
                    .font(.caption2)
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selected ? Color(.tertiarySystemFill) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .opacity(mood == nil || selected ? 1 : 0.5)
        }
        .buttonStyle(.borderless)
    }

    private func save() {
        guard let mood else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setReflection(DayReflection(mood: mood, note: trimmed.isEmpty ? nil : trimmed), on: date)
        dismiss()
    }
}
