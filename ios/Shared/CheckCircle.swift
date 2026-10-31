import SwiftUI

struct CheckCircle: View {
    let color: Color
    let status: DayStatus?
    var size: CGFloat = 22
    /// Ring color while nothing is recorded; defaults to the habit color.
    var idleColor: Color?
    /// Share of daily repetitions done, drawn for the partial status.
    var progress: Double = 0

    var body: some View {
        ZStack {
            switch status {
            case .some(.full):
                Circle().fill(color)
                symbol("checkmark", Color.white)
            case .some(.partial):
                Circle().strokeBorder(idleColor ?? color.opacity(0.3), lineWidth: 2)
                Circle()
                    .inset(by: 1)
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: max(2, size / 10), lineCap: .round))
                    .rotationEffect(.degrees(-90))
            case .some(.minimal):
                Circle().fill(color.opacity(0.45))
                Circle().strokeBorder(color, lineWidth: 2)
                symbol("checkmark", Color.white)
            case .some(.rest):
                Circle().fill(Color.secondary.opacity(0.2))
                symbol("moon.fill", Color.secondary)
            case .some(.skipped):
                Circle().strokeBorder(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                symbol("xmark", Color.secondary)
            case .none:
                Circle().strokeBorder(idleColor ?? color, lineWidth: 2)
            }
        }
        .frame(width: size, height: size)
    }

    private func symbol(_ name: String, _ tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(tint)
    }
}
