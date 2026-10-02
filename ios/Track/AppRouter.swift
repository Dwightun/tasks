import Foundation

/// Navigation requests that can arrive before any view exists (e.g. tapping a notification on cold launch).
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var showWeeklyReview = false
}
