import SwiftUI

struct ProgressMeta: View {
    let progress: Double
    let fileSize: Int64?
    let uploadRate: Double
    let status: UploadStatus

    var body: some View {
        HStack(spacing: 8) {
            Text("\(Int(progress * 100))%")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            if let fileSize = fileSize, fileSize > 0, uploadRate > 0, status == .uploading {
                let remaining = Double(fileSize) * (1.0 - progress)
                let seconds = Int(remaining / max(uploadRate, 1))
                Text(timeString(from: seconds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func timeString(from seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
