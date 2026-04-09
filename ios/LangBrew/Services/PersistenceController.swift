import CoreData

/// Manages the Core Data stack for offline caching.
/// Schema will be populated incrementally as features are built.
@MainActor
final class PersistenceController: Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private init() {
        // Create an in-code model since we don't have entities yet.
        // Entities will be added as milestones introduce cacheable data.
        let model = NSManagedObjectModel()
        container = NSPersistentContainer(name: "LangBrew", managedObjectModel: model)

        container.loadPersistentStores { _, error in
            if let error {
                print("[PersistenceController] Failed to load store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    /// A context for background operations.
    nonisolated func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
