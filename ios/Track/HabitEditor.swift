import SwiftUI

struct HabitEditor: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Habit
    @State private var usesWeekdays: Bool
    @State private var weekdays: Set<Int>
    @State private var reminderOn: Bool
    @State private var reminderTime: Date
    @State private var notificationsDenied = false
    private let isNew: Bool

    static let palette = ["#FF6B6B", "#FFA94D", "#FFD43B", "#69DB7C", "#38D9A9", "#4DABF7", "#748FFC", "#DA77F2"]

    init(habit: Habit?) {
        let initial = habit ?? Habit(name: "", colorHex: HabitEditor.palette.randomElement() ?? "#38D9A9")
        _draft = State(initialValue: initial)
        isNew = habit == nil
        if case .weekdays(let days) = initial.periodicity {
            _usesWeekdays = State(initialValue: true)
            _weekdays = State(initialValue: days)
        } else {
            _usesWeekdays = State(initialValue: false)
            _weekdays = State(initialValue: [0, 1, 2, 3, 4])
        }
        let minutes = initial.reminderMinutes ?? 9 * 60
        _reminderOn = State(initialValue: initial.reminderMinutes != nil)
        _reminderTime = State(initialValue: Calendar.current.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()
        ) ?? Date())
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $draft.name)
                }

                Section("Цвет") {
                    HStack(spacing: 0) {
                        ForEach(Self.palette, id: \.self) { hex in
                            colorSwatch(hex)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Периодичность") {
                    Picker("Периодичность", selection: $usesWeekdays) {
                        Text("Каждый день").tag(false)
                        Text("Дни недели").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if usesWeekdays {
                        HStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { index in
                                weekdayChip(index)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Напоминание", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("Время", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    if reminderOn && notificationsDenied {
                        Text("Уведомления выключены. Включите их в Настройках → Dwightun Habits → Уведомления.")
                    } else if reminderOn {
                        Text("Придёт только в дни по расписанию и только если привычка ещё не отмечена.")
                    }
                }
                .onChange(of: reminderOn) { _, isOn in
                    if isOn {
                        Task { await checkNotificationPermission() }
                    }
                }
                .task {
                    if reminderOn { await checkNotificationPermission() }
                }

                if !isNew {
                    Section {
                        Button("Удалить привычку", role: .destructive) {
                            store.delete(draft.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Новая привычка" : "Изменить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    // Buttons inside a Form row need .borderless, otherwise a tap fires every button in the row.
    private func colorSwatch(_ hex: String) -> some View {
        Button {
            draft.colorHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 28, height: 28)
                .overlay {
                    if draft.colorHex == hex {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
    }

    private func weekdayChip(_ index: Int) -> some View {
        let selected = weekdays.contains(index)
        return Button {
            if selected {
                weekdays.remove(index)
            } else {
                weekdays.insert(index)
            }
        } label: {
            Text(Habit.weekdaySymbols[index])
                .font(.footnote.weight(selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(selected ? Color(.systemBackground) : Color.secondary)
                .background(
                    selected ? Color.primary : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.borderless)
    }

    private func checkNotificationPermission() async {
        let granted = await ReminderScheduler.requestAuthorization()
        notificationsDenied = !granted
    }

    private func save() {
        draft.name = trimmedName
        draft.periodicity = (usesWeekdays && !weekdays.isEmpty) ? .weekdays(weekdays) : .daily
        if reminderOn {
            let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            draft.reminderMinutes = (time.hour ?? 9) * 60 + (time.minute ?? 0)
        } else {
            draft.reminderMinutes = nil
        }
        store.upsert(draft)
        dismiss()
    }
}
