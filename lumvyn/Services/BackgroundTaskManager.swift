#if os(iOS)
    import BackgroundTasks
    import Foundation
    import os

    final class BackgroundTaskManager {
        static let uploadTaskIdentifier = "com.lumvyn.mediaBackup"
        static let mirrorTaskIdentifier = "com.lumvyn.mirrorSync"

        private static let logger = Logger(
            subsystem: "tasio.lumvyn", category: "BackgroundTaskManager")
        private static var activeTasks: [String: Task<Void, Never>] = [:]

        static func register(queueManager: UploadQueueManager, watcher: PhotoLibraryWatcher) {
            let scheduler = BGTaskScheduler.shared

            scheduler.register(forTaskWithIdentifier: uploadTaskIdentifier, using: nil) { task in
                handleTask(task, identifier: uploadTaskIdentifier) {
                    await watcher.scanLibrary()
                    await queueManager.startIfNeeded()
                }
            }

            scheduler.register(forTaskWithIdentifier: mirrorTaskIdentifier, using: nil) { task in
                handleTask(task, identifier: mirrorTaskIdentifier) {
                    await queueManager.runMirrorSyncIfNeeded()
                }
            }
        }

        static func scheduleBackgroundProcessing() {
            scheduleTask(identifier: uploadTaskIdentifier, delay: 15 * 60)
            scheduleTask(identifier: mirrorTaskIdentifier, delay: 60 * 60)
        }

        private static func handleTask(
            _ task: BGTask, identifier: String, action: @escaping @Sendable () async -> Void
        ) {
            scheduleTask(identifier: identifier)

            let workTask = Task {
                await action()
                task.setTaskCompleted(success: !Task.isCancelled)
                activeTasks[identifier] = nil
            }

            activeTasks[identifier] = workTask

            task.expirationHandler = {
                workTask.cancel()
                activeTasks[identifier] = nil
            }
        }

        private static func scheduleTask(identifier: String, delay: TimeInterval? = nil) {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)

            let request = BGProcessingTaskRequest(identifier: identifier)
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false

            let timeOffset = delay ?? (2 * 60 * 60)
            request.earliestBeginDate = Date(timeIntervalSinceNow: timeOffset)

            #if targetEnvironment(simulator)
                logger.info(
                    "BGTaskScheduler wird im Simulator nicht unterstützt. Task: \(identifier)")
            #else
                do {
                    try BGTaskScheduler.shared.submit(request)
                    logger.info(
                        "Task erfolgreich geplant: \(identifier), Startet frühestens in: \(timeOffset)s"
                    )
                } catch {
                    if let taskError = error as? BGTaskScheduler.Error {
                        logger.error(
                            "BGTaskScheduler Fehler (\(taskError.code.rawValue)): \(error.localizedDescription)"
                        )
                    } else {
                        logger.error("Unbekannter Fehler beim Submit: \(error)")
                    }
                }
            #endif
        }
    }
#endif
