import SwiftUI

/// First-run story for people who dropped trackers after a broken streak:
/// misses are normal, log honestly, start with one habit and a widget.
struct OnboardingView: View {
    let onFinish: (_ skipped: Bool) -> Void

    @State private var page = 0
    private let lastPage = 2
    private let accent = Heatmap.accent

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < lastPage {
                    Button("Пропустить") { onFinish(true) }
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                missesPage.tag(0)
                loggingPage.tag(1)
                startPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    onFinish(false)
                }
            } label: {
                Text(page < lastPage ? "Далее" : "Выбрать первую привычку")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Pages

    private var missesPage: some View {
        pageLayout(
            title: "Пропуск — не провал",
            text: "Многие бросают трекеры после первого срыва: серия обнулилась — и всё, мотивация пропала. Здесь история не сгорает, а после пропуска приложение просто подскажет, когда удобно вернуться."
        ) {
            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { index in
                    CheckCircle(color: accent, status: index == 3 ? nil : .full, size: 30, idleColor: Color(.separator))
                }
            }
        }
    }

    private var loggingPage: some View {
        pageLayout(
            title: "Отмечайте честно",
            text: "Не только «сделал или нет». Удерживайте кружок, чтобы выбрать другой вариант."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                legendRow(.full, "Выполнено", "просто нажмите")
                legendRow(.minimal, "Минимум", "когда сил мало — тоже засчитывается")
                legendRow(.rest, "Отдых", "не ломает серию")
                legendRow(.skipped, "Пропуск с причиной", "поможет в итогах недели")
            }
        }
    }

    private var startPage: some View {
        pageLayout(
            title: "Начните с одной",
            text: "Одна привычка, которую вы делаете, лучше пяти брошенных. Добавьте её виджетом на экран «Домой» или блокировки — отмечать можно одним касанием, не открывая приложение."
        ) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(accent)
        }
    }

    // MARK: Building blocks

    private func pageLayout<Illustration: View>(
        title: String,
        text: String,
        @ViewBuilder illustration: () -> Illustration
    ) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            illustration()
                .frame(minHeight: 120)
            VStack(spacing: 12) {
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
    }

    private func legendRow(_ status: DayStatus, _ title: String, _ hint: String) -> some View {
        HStack(spacing: 14) {
            CheckCircle(color: accent, status: status, size: 34, idleColor: Color(.separator))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
