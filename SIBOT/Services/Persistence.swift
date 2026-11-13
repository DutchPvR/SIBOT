import CoreData
import Foundation
import SwiftData

/// One shared SwiftData container so notification actions can write logs
/// even when they arrive while the UI is not showing.
///
/// The diary syncs to the person's private iCloud database (CloudKit), so it follows them
/// to a new phone and survives a reinstall. It is the same store file as before, so
/// everything already on the phone stays and is uploaded on the first sync.
enum Persistence {
    static let cloudContainerID = "iCloud.com.dutchpvr.sibot"

    static let modelTypes: [any PersistentModel.Type] = [
        MealEntry.self, Supplement.self, SupplementLog.self, DailyCheck.self,
        FoodTrial.self, BowelMovement.self, BloatEpisode.self,
    ]

    private static let setup: (container: ModelContainer, syncing: Bool) = {
        let schema = Schema(modelTypes)
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudContainerID))
        #if DEBUG
        initializeCloudKitSchemaIfNeeded(url: cloud.url)
        #endif
        do {
            return (try ModelContainer(for: schema, configurations: cloud), true)
        } catch {
            // A build without the iCloud entitlement (e.g. the simulator check on GitHub):
            // keep the diary on the phone only rather than failing to open.
            print("iCloud sync unavailable, using the local store only: \(error)")
        }
        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return (try ModelContainer(for: schema, configurations: local), false)
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
    }()

    static var container: ModelContainer { setup.container }

    /// False when this build could not turn on iCloud sync.
    static var syncing: Bool { setup.syncing }

    #if DEBUG
    /// Development builds push every record type to the CloudKit development schema once,
    /// so types with no records yet (e.g. food trials) still exist when the schema is
    /// deployed to Production. This is Apple's documented approach for SwiftData + CloudKit.
    private static func initializeCloudKitSchemaIfNeeded(url: URL) {
        let key = "cloudKitSchemaInitialized"
        guard !UserDefaults.standard.bool(forKey: key),
              FileManager.default.ubiquityIdentityToken != nil,
              let model = NSManagedObjectModel.makeManagedObjectModel(for: modelTypes) else { return }
        autoreleasepool {
            let description = NSPersistentStoreDescription(url: url)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudContainerID)
            description.shouldAddStoreAsynchronously = false
            let container = NSPersistentCloudKitContainer(name: "SIBOT", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError {
                print("CloudKit schema setup skipped: \(loadError)")
                return
            }
            do {
                try container.initializeCloudKitSchema()
                UserDefaults.standard.set(true, forKey: key)
            } catch {
                print("CloudKit schema setup failed: \(error)")
            }
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
    }
    #endif
}
