import SwiftUI

/// Separate reorder screen so dragging never competes with the long-press status menu on the main list.
struct ReorderSheet: View {
    @EnvironmentObject private var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.habits) { habit in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: habit.colorHex))
                            .frame(width: 10, height: 10)
                        Text(habit.name)
                    }
                }
                .onMove { source, destination in
                    store.move(fromOffsets: source, toOffset: destination)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Порядок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
