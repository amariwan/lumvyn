import Foundation
import SwiftUI
import Combine

enum InAppNotificationType {
    case info, success, warning, error
}

struct InAppNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String?
    let type: InAppNotificationType
}

final class InAppNotificationCenter: ObservableObject {
    static let shared = InAppNotificationCenter()

    @Published var current: InAppNotification?

    private init() {}

    func show(title: String, message: String? = nil, type: InAppNotificationType = .info, duration: TimeInterval = 4.0) {
        DispatchQueue.main.async {
            let n = InAppNotification(title: title, message: message, type: type)
            withAnimation { self.current = n }

            guard duration > 0 else { return }

            Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await MainActor.run {
                    withAnimation { if self.current?.id == n.id { self.current = nil } }
                }
            }
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            withAnimation { self.current = nil }
        }
    }
}
