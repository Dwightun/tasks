import SwiftUI

@main
struct TrackApp: App {
    @StateObject private var store = HabitStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            // The widget may have toggled habits while the app was in the background.
            if phase == .active { store.reload() }
        }
    }
}
