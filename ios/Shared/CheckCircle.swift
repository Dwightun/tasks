import SwiftUI

struct CheckCircle: View {
    let color: Color
    let done: Bool
    var size: CGFloat = 22
    /// Ring color while not done; defaults to the habit color.
    var idleColor: Color?

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(done ? color : (idleColor ?? color), lineWidth: 2)
            if done {
                Circle().fill(color)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: size, height: size)
    }
}
