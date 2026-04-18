import SwiftUI

extension UploadStatus {
    var color: Color {
        switch self {
        case .pending:   return .orange
        case .uploading: return .blue
        case .done:      return .green
        case .failed:    return .red
        }
    }
}
