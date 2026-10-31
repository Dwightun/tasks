import Foundation

/// Ready-made starting points; the user reviews and edits them in the editor before saving.
struct HabitTemplate: Identifiable {
    let id: String
    let name: String
    let colorHex: String
    let icon: String
    var dailyTarget = 1
    let periodicity: Periodicity
    let plan: PlanDetails

    func makeHabit() -> Habit {
        var habit = Habit(name: name, colorHex: colorHex, periodicity: periodicity)
        habit.icon = icon
        habit.dailyTarget = dailyTarget
        habit.plan = plan
        return habit
    }

    static let all: [HabitTemplate] = [
        HabitTemplate(
            id: "walk",
            name: "Прогулка",
            colorHex: "#69DB7C",
            icon: "figure.walk",
            periodicity: .timesPerWeek(3),
            plan: PlanDetails(
                cue: "После работы",
                firstStep: "Надеть кроссовки и выйти",
                minimalVersion: "10 минут вокруг дома",
                obstacle: "Задержался на работе",
                backupPlan: "Пройтись утром перед работой"
            )
        ),
        HabitTemplate(
            id: "reading",
            name: "Чтение",
            colorHex: "#4DABF7",
            icon: "book",
            periodicity: .daily,
            plan: PlanDetails(
                cue: "Когда ложусь в кровать",
                firstStep: "Открыть книгу",
                minimalVersion: "Одна страница",
                preparation: "Книга на тумбочке"
            )
        ),
        HabitTemplate(
            id: "water",
            name: "Стакан воды утром",
            colorHex: "#38D9A9",
            icon: "sun.max",
            periodicity: .daily,
            plan: PlanDetails(
                cue: "Сразу после пробуждения",
                firstStep: "Налить стакан воды",
                minimalVersion: "Несколько глотков",
                preparation: "Стакан у кровати с вечера"
            )
        ),
        HabitTemplate(
            id: "water-day",
            name: "Вода",
            colorHex: "#4DABF7",
            icon: "drop",
            dailyTarget: 6,
            periodicity: .daily,
            plan: PlanDetails(
                cue: "После каждого приёма пищи и утром",
                firstStep: "Налить стакан",
                preparation: "Бутылка воды на рабочем столе"
            )
        ),
        HabitTemplate(
            id: "exercise",
            name: "Зарядка",
            colorHex: "#FFA94D",
            icon: "figure.yoga",
            periodicity: .weekdays([0, 1, 2, 3, 4]),
            plan: PlanDetails(
                cue: "После того как умылся",
                firstStep: "Встать на коврик",
                minimalVersion: "Одно упражнение"
            )
        ),
        HabitTemplate(
            id: "workout",
            name: "Тренировка",
            colorHex: "#FF6B6B",
            icon: "dumbbell",
            periodicity: .timesPerWeek(2),
            plan: PlanDetails(
                firstStep: "Собрать сумку и выйти",
                minimalVersion: "20 минут дома",
                obstacle: "Не успеваю в зал",
                backupPlan: "Короткая тренировка дома",
                preparation: "Сумка с формой у двери с вечера"
            )
        ),
        HabitTemplate(
            id: "no-phone",
            name: "Без телефона перед сном",
            colorHex: "#748FFC",
            icon: "iphone.slash",
            periodicity: .daily,
            plan: PlanDetails(
                cue: "Когда ложусь в кровать",
                firstStep: "Поставить телефон на зарядку вне спальни",
                minimalVersion: "Не брать телефон последние 10 минут"
            )
        ),
    ]
}
