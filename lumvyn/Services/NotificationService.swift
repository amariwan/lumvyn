import Foundation
import os
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    private let logger = Logger(subsystem: "tasio.lumvyn", category: "NotificationService")

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                self.logger.error("Notification auth error: \(String(describing: error))")
            }
            self.logger.info("Notifications granted: \(granted)")
        }
    }

    func sendUploadCompleteNotification(successCount: Int, failureCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Upload abgeschlossen", comment: "Upload finished notification title")
        if failureCount > 0 {
            content.body = String(format: NSLocalizedString("UploadSummary", comment: "Upload summary with failures"), successCount, failureCount)
        } else {
            content.body = NSLocalizedString("Alle Dateien wurden erfolgreich hochgeladen.", comment: "All files uploaded successfully")
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "lumvyn.upload.complete",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                self.logger.error("Notification error: \(String(describing: error))")
            }
        }
    }
}
