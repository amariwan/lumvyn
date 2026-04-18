//
//  Persistence.swift
//  lumvyn
//
//  Created by Aland Baban on 11.04.26.
//

import CoreData
import os

private let persistenceLogger = Logger(subsystem: "tasio.lumvyn", category: "Persistence")

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        do {
            try result.container.viewContext.save()
        } catch {
            let nsError = error as NSError
            persistenceLogger.error("Persistence preview save error: \(nsError.localizedDescription, privacy: .public), \(String(describing: nsError.userInfo), privacy: .public)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "lumvyn")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                persistenceLogger.error("Failed to load persistent stores: \(error.localizedDescription, privacy: .public), \(String(describing: error.userInfo), privacy: .public)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
