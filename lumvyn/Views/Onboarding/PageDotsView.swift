import SwiftUI

struct PageDotsView: View {
    let total: Int
    let current: Int

    var body: some View {
        VStack(spacing: 10) {
            Text("\(current + 1) / \(total)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.35))
                .monospacedDigit()

            HStack(spacing: 7) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index == current ? Color.white : Color.white.opacity(0.28))
                        .frame(width: index == current ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
                }
            }
        }
    }
}
