import XCTest

final class HabitTests: XCTestCase {
    /// 2026-09-28 is a Monday.
    private func day(_ key: String) -> Date {
        DayKey.date(from: key)!
    }

    private func habit(_ periodicity: Periodicity, created: String = "2026-09-01") -> Habit {
        Habit(name: "Test", colorHex: "#38D9A9", periodicity: periodicity, createdAt: day(created))
    }

    // MARK: Migration

    func testDecodesVersionOneData() throws {
        let json = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Чтение","colorHex":"#4DABF7",
          "periodicity":{"weekdays":{"_0":[0,2,4]}},"completions":["2026-09-28","2026-09-30"],
          "createdAt":780000000,"reminderMinutes":540}]
        """
        let habits = try JSONDecoder().decode([Habit].self, from: Data(json.utf8))
        let migrated = try XCTUnwrap(habits.first)

        XCTAssertEqual(migrated.name, "Чтение")
        XCTAssertEqual(migrated.periodicity, .weekdays([0, 2, 4]))
        XCTAssertEqual(migrated.planHistory, [PlanVersion(since: PlanVersion.beginning, periodicity: .weekdays([0, 2, 4]))])
        XCTAssertEqual(migrated.entries["2026-09-28"]?.status, .full)
        XCTAssertEqual(migrated.entries["2026-09-30"]?.status, .full)
        XCTAssertEqual(migrated.totalCompleted, 2)
        XCTAssertEqual(migrated.reminderMinutes, 540)
        XCTAssertTrue(migrated.pauses.isEmpty)
    }

    func testRoundTripKeepsEverything() throws {
        var original = habit(.timesPerWeek(3))
        original.setStatus(.minimal, onKey: "2026-09-29")
        original.setStatus(.rest, onKey: "2026-09-30")
        original.plan.cue = "После работы"
        original.pauses = [Pause(kind: .travel, start: "2026-10-05", end: "2026-10-09")]
        original.reminderMinutes = 8 * 60

        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([Habit].self, from: data)
        XCTAssertEqual(decoded, [original])
    }

    // MARK: Week progress

    func testWeekdayPlanCountsDueDays() {
        var h = habit(.weekdays([0, 2, 4]))
        h.setStatus(.full, onKey: "2026-09-28")
        h.setStatus(.minimal, onKey: "2026-09-30")

        let week = h.weekProgress(containing: day("2026-10-01"))
        XCTAssertEqual(week, WeekProgress(planned: 3, completed: 2, minimal: 1))
        XCTAssertFalse(week.isMet)
    }

    func testRestAndPauseReducePlannedOpportunities() {
        var h = habit(.weekdays([0, 2, 4]))
        h.setStatus(.full, onKey: "2026-09-28")
        h.setStatus(.rest, onKey: "2026-09-30")
        h.pauses = [Pause(kind: .sick, start: "2026-10-02", end: "2026-10-02")]

        let week = h.weekProgress(containing: day("2026-09-28"))
        XCTAssertEqual(week.planned, 1)
        XCTAssertTrue(week.isMet)
    }

    func testTimesPerWeekQuotaHidesHabitOnceMet() {
        var h = habit(.timesPerWeek(2))
        h.setStatus(.full, onKey: "2026-09-28")
        XCTAssertTrue(h.isPlanned(on: day("2026-09-29")))

        h.setStatus(.full, onKey: "2026-09-29")
        XCTAssertEqual(h.weekProgress(containing: day("2026-09-30")).planned, 2)
        XCTAssertTrue(h.isPlanned(on: day("2026-09-29")), "stays visible on a day it was completed")
        XCTAssertFalse(h.isPlanned(on: day("2026-09-30")))
        XCTAssertTrue(h.isPlanned(on: day("2026-10-05")), "new week, new quota")
    }

    func testPausedDayIsNotPlanned() {
        var h = habit(.daily)
        h.pauses = [Pause(kind: .rest, start: "2026-09-29", end: nil)]
        XCTAssertTrue(h.isPlanned(on: day("2026-09-28")))
        XCTAssertFalse(h.isPlanned(on: day("2026-09-29")))
        XCTAssertFalse(h.isPlanned(on: day("2026-12-31")), "open-ended pause")
    }

    // MARK: Streaks

    func testDailyStreakIgnoresPendingTodayAndPauses() {
        var h = habit(.daily)
        for key in ["2026-09-25", "2026-09-26", "2026-09-27", "2026-09-30"] {
            h.setStatus(.full, onKey: key)
        }
        h.pauses = [Pause(kind: .sick, start: "2026-09-28", end: "2026-09-29")]

        let streak = h.streak(today: day("2026-10-01"))
        XCTAssertEqual(streak.current, 4)
        XCTAssertEqual(streak.best, 4)
        XCTAssertEqual(streak.unit, .days)
    }

    func testMissingDueDayBreaksStreak() {
        var h = habit(.daily)
        h.setStatus(.full, onKey: "2026-09-27")
        h.setStatus(.full, onKey: "2026-09-28")
        h.setStatus(.full, onKey: "2026-09-30")

        let streak = h.streak(today: day("2026-09-30"))
        XCTAssertEqual(streak.current, 1)
        XCTAssertEqual(streak.best, 2)
    }

    func testRestDayKeepsStreak() {
        var h = habit(.daily)
        h.setStatus(.full, onKey: "2026-09-28")
        h.setStatus(.rest, onKey: "2026-09-29")
        h.setStatus(.full, onKey: "2026-09-30")

        XCTAssertEqual(h.streak(today: day("2026-09-30")).current, 2)
    }

    func testWeeklyStreakCountsMetWeeks() {
        var h = habit(.timesPerWeek(2))
        for key in ["2026-09-15", "2026-09-17", "2026-09-22", "2026-09-26", "2026-09-29"] {
            h.setStatus(.full, onKey: key)
        }

        let streak = h.streak(today: day("2026-09-30"))
        XCTAssertEqual(streak.unit, .weeks)
        XCTAssertEqual(streak.current, 2, "current week is still open")
        XCTAssertEqual(streak.best, 2)
    }

    // MARK: Plan versions

    func testPlanChangeDoesNotRewritePastWeeks() {
        var h = habit(.weekdays([0]))
        h.setPeriodicity(.daily, from: day("2026-09-28"))

        XCTAssertEqual(h.weekProgress(containing: day("2026-09-21")).planned, 1)
        XCTAssertEqual(h.weekProgress(containing: day("2026-09-28")).planned, 7)
        XCTAssertEqual(h.planHistory.count, 2)
    }

    func testSameDayRevertLeavesSingleVersion() {
        var h = habit(.daily)
        h.setPeriodicity(.timesPerWeek(3), from: day("2026-09-28"))
        h.setPeriodicity(.daily, from: day("2026-09-28"))

        XCTAssertEqual(h.planHistory.count, 1)
        XCTAssertEqual(h.periodicity, .daily)
    }

    // MARK: Logging

    func testToggleClearsCompletionAndOverridesOtherStatuses() {
        var h = habit(.daily)
        let date = day("2026-09-28")

        h.setStatus(.minimal, onKey: "2026-09-28")
        h.toggle(on: date)
        XCTAssertNil(h.status(onKey: "2026-09-28"))

        h.setStatus(.skipped, onKey: "2026-09-28")
        h.toggle(on: date)
        XCTAssertEqual(h.status(onKey: "2026-09-28"), .full)
    }

    func testTimesPerWeekLabelUsesCorrectPlural() {
        XCTAssertEqual(Habit.timesPerWeekLabel(1), "1 раз в неделю")
        XCTAssertEqual(Habit.timesPerWeekLabel(3), "3 раза в неделю")
        XCTAssertEqual(Habit.timesPerWeekLabel(5), "5 раз в неделю")
    }
}
