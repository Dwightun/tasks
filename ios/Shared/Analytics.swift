import Foundation
import TelemetryDeck

/// Anonymous usage signals (no personal data, no habit names).
/// A no-op until a TelemetryDeck App ID is injected at build time.
enum Analytics {
    private static var isStarted = false

    static func start() {
        guard
            !isStarted,
            let appID = Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String,
            !appID.isEmpty
        else { return }
        TelemetryDeck.initialize(config: .init(appID: appID))
        isStarted = true
    }

    static func send(_ event: String, _ parameters: [String: String] = [:]) {
        start()
        guard isStarted else { return }
        TelemetryDeck.signal(event, parameters: parameters)
    }

    /// One logging action, plus a "comeback" when it closes the gap after a missed day (the research's return metric).
    static func recordMark(before: Habit, after: Habit, on date: Date, source: String) {
        let key = DayKey.key(for: date)
        let isToday = Calendar.current.isDateInToday(date)
        guard let status = after.status(onKey: key) else {
            send("Habit.unmarked", ["source": source])
            return
        }
        send("Habit.marked", [
            "source": source,
            "status": status.rawValue,
            "day": isToday ? "today" : "past",
        ])
        if isToday, !before.isCompleted(onKey: key), after.isCompleted(onKey: key),
           before.returnPrompt(today: date) != nil {
            send("Habit.comeback", ["source": source])
        }
    }
}
