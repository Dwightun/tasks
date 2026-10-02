import Foundation

struct WeekSummary: Equatable {
    let progress: WeekProgress
    /// Reasons from skipped days plus the week-level answer (weighted by the days it explains).
    let reasons: [SkipReason: Int]
    /// Missed opportunities with no record and no week-level reason yet.
    let unexplained: Int
    let rest: Int
}

struct ReviewSuggestion: Equatable {
    enum Action: Equatable {
        case none
        case editPlan
        case changePeriodicity(Periodicity)
        case pause
    }

    let title: String
    let detail: String
    let action: Action
}

enum WeeklyReview {
    /// On Sunday the current week is reviewed; on other days the week that just ended.
    static func defaultWeekStart(today: Date = Date(), calendar: Calendar = .current) -> Date {
        let monday = Habit.monday(of: today, calendar: calendar)
        if Habit.mondayIndex(of: today, calendar: calendar) == 6 { return monday }
        return calendar.date(byAdding: .day, value: -7, to: monday) ?? monday
    }

    /// Plan changes start with a whole week so the week under review is never rewritten.
    static func effectiveDateForChange(today: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: today)
        if Habit.mondayIndex(of: start, calendar: calendar) == 0 { return start }
        return calendar.date(byAdding: .day, value: 7, to: Habit.monday(of: start, calendar: calendar)) ?? start
    }
}

extension Habit {
    func weekSummary(weekStart: Date, today: Date = Date(), calendar: Calendar = .current) -> WeekSummary {
        let monday = Habit.monday(of: weekStart, calendar: calendar)
        let mondayKey = DayKey.key(for: monday, calendar: calendar)
        let todayKey = DayKey.key(for: today, calendar: calendar)
        let progress = weekProgress(containing: monday, calendar: calendar)

        var reasons: [SkipReason: Int] = [:]
        var skipped = 0
        var rest = 0
        var silentDueDays = 0
        var lastKey = mondayKey

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            let key = DayKey.key(for: day, calendar: calendar)
            lastKey = key
            switch entries[key]?.status {
            case .some(.skipped):
                skipped += 1
                if let reason = entries[key]?.reason { reasons[reason, default: 0] += 1 }
            case .some(.rest):
                rest += 1
            case .none:
                if key < todayKey, isDue(on: day, calendar: calendar) { silentDueDays += 1 }
            default:
                break
            }
        }

        var missing: Int
        if case .timesPerWeek = periodicity(onKey: lastKey) {
            // Flexible quota: only a finished week can be short, and not on any particular day.
            missing = lastKey <= todayKey ? max(0, progress.planned - progress.completed - skipped) : 0
        } else {
            missing = silentDueDays
        }

        if let weekReason = weekReasons[mondayKey], missing > 0 {
            reasons[weekReason, default: 0] += missing
            missing = 0
        }

        return WeekSummary(progress: progress, reasons: reasons, unexplained: missing, rest: rest)
    }

    /// One suggestion per habit, following the research routing table: name the obstacle first, then change one thing.
    func reviewSuggestion(weekStart: Date, today: Date = Date(), calendar: Calendar = .current) -> ReviewSuggestion? {
        let summary = weekSummary(weekStart: weekStart, today: today, calendar: calendar)
        let progress = summary.progress
        guard progress.planned > 0 else { return nil }

        // Judge by the plan the week actually had, so an applied change doesn't trigger a new suggestion.
        let monday = Habit.monday(of: weekStart, calendar: calendar)
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        let weekPlan = periodicity(onKey: DayKey.key(for: sunday, calendar: calendar))

        if progress.isMet {
            let previous = calendar.date(byAdding: .day, value: -7, to: monday) ?? monday
            if case .timesPerWeek(let count) = weekPlan, count < 6, progress.minimal == 0,
               weekProgress(containing: previous, calendar: calendar).isMet {
                return ReviewSuggestion(
                    title: "Можно немного добавить",
                    detail: "Две недели подряд план выполнен полностью. Если чувствуете запас — попробуйте \(Habit.timesPerWeekLabel(count + 1)). Если нет, оставьте как есть.",
                    action: .changePeriodicity(.timesPerWeek(count + 1))
                )
            }
            if progress.minimal * 2 > progress.completed {
                return ReviewSuggestion(
                    title: "План выполнен",
                    detail: "В основном минимальной версией — это тоже прогресс: начинать становится привычнее. Оставьте план как есть.",
                    action: .none
                )
            }
            return ReviewSuggestion(title: "План выполнен", detail: "Менять работающий план не нужно.", action: .none)
        }

        let order = SkipReason.allCases
        let top = summary.reasons.max { lhs, rhs in
            lhs.value != rhs.value
                ? lhs.value < rhs.value
                : (order.firstIndex(of: lhs.key) ?? 0) > (order.firstIndex(of: rhs.key) ?? 0)
        }?.key

        guard let reason = top else {
            return ReviewSuggestion(
                title: "Что мешало?",
                detail: "Отметьте главную причину — так будет понятно, что поменять в плане.",
                action: .none
            )
        }

        switch reason {
        case .forgot:
            if reminderMinutes == nil {
                return ReviewSuggestion(
                    title: "Добавить подсказку",
                    detail: "Пропуски из-за того, что забыли. Включите напоминание или привяжите начало к событию, которое точно происходит («после …»).",
                    action: .editPlan
                )
            }
            return ReviewSuggestion(
                title: "Сменить момент подсказки",
                detail: "Напоминание приходит, но не помогает. Попробуйте другое время или привязку к событию, после которого удобно начать.",
                action: .editPlan
            )
        case .noTime:
            if (plan.backupPlan ?? "").isEmpty {
                return ReviewSuggestion(
                    title: "Добавить запасной вариант",
                    detail: "Чаще всего не хватало времени. Решите заранее: если не получится в обычное время — что и когда сделаете вместо.",
                    action: .editPlan
                )
            }
            if let lower = Habit.lowerPeriodicity(than: weekPlan, completed: progress.completed) {
                return ReviewSuggestion(
                    title: "Сделать план реалистичнее",
                    detail: "Времени не хватает даже с запасным вариантом. Выполнимый план лучше идеального: \(lower.label.lowercased()).",
                    action: .changePeriodicity(lower)
                )
            }
            return ReviewSuggestion(
                title: "Пересмотреть окно",
                detail: "Времени не хватает. Подумайте, в какое время это реально помещается, и обновите план.",
                action: .editPlan
            )
        case .tooHard:
            if (plan.minimalVersion ?? "").isEmpty {
                return ReviewSuggestion(
                    title: "Упростить начало",
                    detail: "Трудно начать. Задайте первый шаг и минимальную версию, которую можно сделать даже в тяжёлый день.",
                    action: .editPlan
                )
            }
            return ReviewSuggestion(
                title: "Минимум в трудные дни",
                detail: "Минимальная версия уже есть — в трудный день отмечайте её вместо пропуска. Если и она тяжела, упростите её.",
                action: .editPlan
            )
        case .notEnjoyable:
            return ReviewSuggestion(
                title: "Сделать приятнее",
                detail: "Подумайте, что изменит сам опыт: другой маршрут, музыка или подкаст, компания, время. Запишите это в план.",
                action: .editPlan
            )
        case .circumstances:
            return ReviewSuggestion(
                title: "Пересобрать план",
                detail: "Обстоятельства изменились — выберите новый сигнал начала, время и запасной вариант. История сохранится.",
                action: .editPlan
            )
        case .unwell:
            return ReviewSuggestion(
                title: "Взять паузу",
                detail: "Если нужно восстановиться, пауза сохранит историю и не будет считать дни пропусками.",
                action: .pause
            )
        case .other:
            return ReviewSuggestion(
                title: "Ещё одна неделя",
                detail: "Оставьте план и посмотрите, повторится ли причина.",
                action: .none
            )
        }
    }

    /// A gentler schedule close to what actually happened; nil when there's nothing lower to offer.
    static func lowerPeriodicity(than periodicity: Periodicity, completed: Int) -> Periodicity? {
        switch periodicity {
        case .daily:
            return .timesPerWeek(min(6, max(1, completed + 1)))
        case .weekdays(let days):
            return days.count > 1 ? .timesPerWeek(days.count - 1) : nil
        case .timesPerWeek(let count):
            return count > 1 ? .timesPerWeek(count - 1) : nil
        }
    }
}
