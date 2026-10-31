import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    @State private var checkInEnabled = ReviewSettings.checkInEnabled
    @State private var checkInTime = SettingsSheet.time(ReviewSettings.checkInMinutes)
    @State private var checkInReminder = ReviewSettings.checkInReminder
    @State private var reviewEnabled = ReviewSettings.isEnabled
    @State private var reviewTime = SettingsSheet.time(ReviewSettings.minutes)
    @State private var isReordering = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Вечерний чек-ин", isOn: $checkInEnabled)
                    if checkInEnabled {
                        DatePicker("Предлагать с", selection: $checkInTime, displayedComponents: .hourAndMinute)
                        Toggle("Напоминание", isOn: $checkInReminder)
                    }
                } footer: {
                    Text("Вечером на главном экране появится вопрос «Как прошёл день?»: оценка и пара слов о том, что повлияло.")
                }

                Section {
                    Toggle("Напоминать в воскресенье", isOn: $reviewEnabled)
                    if reviewEnabled {
                        DatePicker("Время", selection: $reviewTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Итоги недели")
                }

                if store.habits.count > 1 {
                    Section {
                        Button("Порядок привычек") { isReordering = true }
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onChange(of: checkInEnabled) { _, _ in saveCheckIn() }
            .onChange(of: checkInTime) { _, _ in saveCheckIn() }
            .onChange(of: checkInReminder) { _, isOn in
                saveCheckIn()
                if isOn { Task { _ = await ReminderScheduler.requestAuthorization() } }
            }
            .onChange(of: reviewEnabled) { _, _ in saveReview() }
            .onChange(of: reviewTime) { _, _ in saveReview() }
            .sheet(isPresented: $isReordering) {
                ReorderSheet().environmentObject(store)
            }
        }
    }

    private func saveCheckIn() {
        store.updateCheckIn(enabled: checkInEnabled, minutes: Self.minutes(checkInTime), reminder: checkInReminder)
    }

    private func saveReview() {
        store.updateReviewReminder(enabled: reviewEnabled, minutes: Self.minutes(reviewTime))
    }

    private static func minutes(_ date: Date) -> Int {
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (time.hour ?? 0) * 60 + (time.minute ?? 0)
    }

    private static func time(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }
}
