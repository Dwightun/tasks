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
        original.weekReasons = ["2026-09-21": .noTime]
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

    func testSkipReasonIsKeptOnlyForSkippedDays() {
        var h = habit(.daily)
        h.setStatus(.skipped, onKey: "2026-09-28", reason: .noTime)
        h.setStatus(.rest, onKey: "2026-09-29", reason: .noTime)

        XCTAssertEqual(h.entries["2026-09-28"]?.reason, .noTime)
        XCTAssertNil(h.entries["2026-09-29"]?.reason)
    }

    // MARK: Return after a miss

    func testReturnPromptAfterUnrecordedDueDay() {
        var h = habit(.daily)
        h.setStatus(.full, onKey: "2026-09-28")

        let prompt = h.returnPrompt(today: day("2026-09-30"))
        XCTAssertEqual(prompt, ReturnPrompt(missedDay: day("2026-09-29"), nextOpportunity: day("2026-09-30")))
    }

    func testReturnPromptPointsToNextScheduledDay() {
        var h = habit(.weekdays([0, 2]))
        h.setStatus(.full, onKey: "2026-09-28")

        let prompt = h.returnPrompt(today: day("2026-10-01"))
        XCTAssertEqual(prompt?.missedDay, day("2026-09-30"))
        XCTAssertEqual(prompt?.nextOpportunity, day("2026-10-05"))
    }

    func testNoReturnPromptOnceMissIsExplainedOrHandled() {
        var h = habit(.daily)
        h.setStatus(.full, onKey: "2026-09-28")

        var explained = h
        explained.setStatus(.skipped, onKey: "2026-09-29", reason: .forgot)
        XCTAssertNil(explained.returnPrompt(today: day("2026-09-30")))

        var rested = h
        rested.setStatus(.rest, onKey: "2026-09-29")
        XCTAssertNil(rested.returnPrompt(today: day("2026-09-30")))

        var doneToday = h
        doneToday.setStatus(.minimal, onKey: "2026-09-30")
        XCTAssertNil(doneToday.returnPrompt(today: day("2026-09-30")))

        var paused = h
        paused.startPause(.sick, from: day("2026-09-30"), until: nil)
        XCTAssertNil(paused.returnPrompt(today: day("2026-09-30")))

        XCTAssertNil(habit(.timesPerWeek(3)).returnPrompt(today: day("2026-09-30")))
    }

    // MARK: Pauses

    func testEndingPauseKeepsPastDaysPaused() {
        var h = habit(.daily)
        h.startPause(.travel, from: day("2026-09-25"), until: nil)
        h.endPause(on: day("2026-09-30"))

        XCTAssertTrue(h.isPaused(onKey: "2026-09-29"))
        XCTAssertFalse(h.isPaused(onKey: "2026-09-30"))
    }

    func testEndingPauseStartedTodayRemovesIt() {
        var h = habit(.daily)
        h.startPause(.rest, from: day("2026-09-30"), until: day("2026-10-03"))
        h.endPause(on: day("2026-09-30"))

        XCTAssertTrue(h.pauses.isEmpty)
    }

    func testStartingPauseReplacesOverlappingOne() {
        var h = habit(.daily)
        h.startPause(.rest, from: day("2026-09-28"), until: day("2026-10-05"))
        h.startPause(.sick, from: day("2026-09-30"), until: day("2026-10-02"))

        XCTAssertEqual(h.pauses, [Pause(kind: .sick, start: "2026-09-30", end: "2026-10-02")])
    }

    // MARK: Weekly review

    func testWeekSummaryCountsReasonsAndUnexplainedDays() {
        var h = habit(.weekdays([0, 2, 4]))
        h.setStatus(.full, onKey: "2026-09-21")
        h.setStatus(.skipped, onKey: "2026-09-23", reason: .noTime)

        let summary = h.weekSummary(weekStart: day("2026-09-21"), today: day("2026-10-01"))
        XCTAssertEqual(summary.progress, WeekProgress(planned: 3, completed: 1, minimal: 0))
        XCTAssertEqual(summary.reasons, [.noTime: 1])
        XCTAssertEqual(summary.unexplained, 1)

        h.weekReasons["2026-09-21"] = .forgot
        let explained = h.weekSummary(weekStart: day("2026-09-21"), today: day("2026-10-01"))
        XCTAssertEqual(explained.reasons, [.noTime: 1, .forgot: 1])
        XCTAssertEqual(explained.unexplained, 0)
    }

    func testSuggestionFollowsMainReasonWithStableTieBreak() {
        var h = habit(.weekdays([0, 2, 4]))
        h.setStatus(.full, onKey: "2026-09-21")
        h.setStatus(.skipped, onKey: "2026-09-23", reason: .noTime)

        let noTime = h.reviewSuggestion(weekStart: day("2026-09-21"), today: day("2026-10-01"))
        XCTAssertEqual(noTime?.title, "Добавить запасной вариант")
        XCTAssertEqual(noTime?.action, .editPlan)

        // Equal counts: the reason listed first in SkipReason wins.
        h.weekReasons["2026-09-21"] = .forgot
        XCTAssertEqual(h.reviewSuggestion(weekStart: day("2026-09-21"), today: day("2026-10-01"))?.title, "Добавить подсказку")
    }

    func testNoTimeWithBackupPlanSuggestsRealisticFrequency() {
        var h = habit(.daily)
        h.plan.backupPlan = "Утром"
        for key in ["2026-09-21", "2026-09-22", "2026-09-23"] { h.setStatus(.full, onKey: key) }
        for key in ["2026-09-24", "2026-09-25", "2026-09-26", "2026-09-27"] {
            h.setStatus(.skipped, onKey: key, reason: .noTime)
        }

        let suggestion = h.reviewSuggestion(weekStart: day("2026-09-21"), today: day("2026-10-01"))
        XCTAssertEqual(suggestion?.action, .changePeriodicity(.timesPerWeek(4)))
    }

    func testIncreaseIsOfferedAfterTwoFullWeeksAndNotRepeatedOnceApplied() {
        var h = habit(.timesPerWeek(2))
        for key in ["2026-09-21", "2026-09-23", "2026-09-28", "2026-09-30"] { h.setStatus(.full, onKey: key) }
        let review = (weekStart: day("2026-09-28"), today: day("2026-10-04"))

        let suggestion = h.reviewSuggestion(weekStart: review.weekStart, today: review.today)
        XCTAssertEqual(suggestion?.action, .changePeriodicity(.timesPerWeek(3)))

        h.setPeriodicity(.timesPerWeek(3), from: WeeklyReview.effectiveDateForChange(today: review.today))
        XCTAssertEqual(h.periodicity, .timesPerWeek(3))
        XCTAssertEqual(h.reviewSuggestion(weekStart: review.weekStart, today: review.today), suggestion)
        XCTAssertEqual(h.weekProgress(containing: review.weekStart).planned, 2, "reviewed week keeps its plan")
    }

    func testUnwellSuggestsPause() {
        var h = habit(.daily)
        h.setStatus(.skipped, onKey: "2026-09-22", reason: .unwell)
        XCTAssertEqual(h.reviewSuggestion(weekStart: day("2026-09-21"), today: day("2026-10-01"))?.action, .pause)
    }

    func testReviewWeekAndEffectiveDate() {
        XCTAssertEqual(WeeklyReview.defaultWeekStart(today: day("2026-10-04")), day("2026-09-28"), "Sunday reviews its own week")
        XCTAssertEqual(WeeklyReview.defaultWeekStart(today: day("2026-09-30")), day("2026-09-21"))
        XCTAssertEqual(WeeklyReview.effectiveDateForChange(today: day("2026-09-30")), day("2026-10-05"))
        XCTAssertEqual(WeeklyReview.effectiveDateForChange(today: day("2026-09-28")), day("2026-09-28"))
    }

    func testChangeFromTodayReplacesScheduledFutureVersion() {
        var h = habit(.daily)
        h.setPeriodicity(.timesPerWeek(3), from: day("2026-10-05"))
        h.setPeriodicity(.timesPerWeek(5), from: day("2026-09-30"))

        XCTAssertEqual(h.planHistory.map(\.periodicity), [.daily, .timesPerWeek(5)])
        XCTAssertEqual(h.periodicity(onKey: "2026-10-01"), .timesPerWeek(5))
    }

    func testHeatmapGrowsFromStartWeek() {
        XCTAssertEqual(Heatmap.weeksSpanning(from: "2026-09-30", today: day("2026-10-01")), 1)
        XCTAssertEqual(Heatmap.weeksSpanning(from: "2026-09-27", today: day("2026-10-01")), 2)
        XCTAssertEqual(Heatmap.weeksSpanning(from: "2025-01-01", today: day("2026-10-01")), 26)
    }

    func testTimesPerWeekLabelUsesCorrectPlural() {
        XCTAssertEqual(Habit.timesPerWeekLabel(1), "1 раз в неделю")
        XCTAssertEqual(Habit.timesPerWeekLabel(3), "3 раза в неделю")
        XCTAssertEqual(Habit.timesPerWeekLabel(5), "5 раз в неделю")
    }
}
