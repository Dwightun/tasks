import SwiftUI

struct PauseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (Pause.Kind, Date?) -> Void

    @State private var kind: Pause.Kind = .rest
    @State private var hasEnd = true
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Причина", selection: $kind) {
                        ForEach(Pause.Kind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("До определённой даты", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Последний день", selection: $endDate, in: Date()..., displayedComponents: .date)
                    }
                } footer: {
                    Text("На паузе напоминания не приходят, дни не считаются пропусками и серия не прерывается. История сохраняется.")
                }
            }
            .navigationTitle("Пауза")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Начать") {
                        onStart(kind, hasEnd ? endDate : nil)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
