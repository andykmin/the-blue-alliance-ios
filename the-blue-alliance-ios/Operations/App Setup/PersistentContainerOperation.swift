import CoreData
import CoreSpotlight
import Foundation

class PersistentContainerOperation: TBAOperation {

    var persistentContainer: NSPersistentContainer

    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer

        super.init()
    }

    override func execute() {
        // persistentStore.setOption(coreSpotlightDelegate, forKey:NSCoreDataCoreSpotlightExporter)
        // persistentContainer.persistentStoreDescriptions = [persistentStore]
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            // NSPersistentStoreDescription
            /*
             Typical reasons for an error here include:
             * The parent directory does not exist, cannot be created, or disallows writing.
             * The persistent store is not accessible, due to permissions or data protection when the device is locked.
             * The device is out of space.
             * The store could not be migrated to the current model version.
             Check the error message to determine what the actual problem was.
             */
            self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
            self.persistentContainer.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
            self.completionError = error
            self.finish()
        })
    }

}
