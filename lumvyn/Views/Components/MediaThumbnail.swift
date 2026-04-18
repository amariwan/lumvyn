import SwiftUI

struct MediaThumbnail: View {
    let mediaType: RemoteMediaType
    let status: UploadStatus

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(status.color.opacity(0.12))
                .frame(width: 46, height: 46)

            if status == .uploading {
                ProgressView()
                    .controlSize(.small)
                    .tint(status.color)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(status.color)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: status)
    }

    private var iconName: String {
        switch status {
        case .uploading: return "arrow.up.circle.fill"
        case .done:      return "checkmark.circle.fill"
        case .failed:    return "exclamationmark.circle.fill"
        case .pending:
            switch mediaType {
            case .video: return "film"
            case .photo: return "photo"
            case .unknown: return "photo"
            }
        }
    }
}
