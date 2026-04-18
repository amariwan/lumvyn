import SwiftUI

struct StatusChip: View {
    let status: UploadStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .clipShape(Capsule())
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: status)
    }
}
