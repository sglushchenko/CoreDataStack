//
//  Migrator.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 28.06.2023.
//

import CoreData

///*
/// Example for Migrator
/// class Migrator: CoreDataMigratorProtocol {
///     typealias T = MigrationVersion
/// }
///*
public protocol CoreDataMigratorProtocol {
    associatedtype T: CoreDataMigrationVersion
}

public protocol CoreDataMigrationVersion: CaseIterable, Equatable {
    static var current: Self { get }
    var nextVersion: Self? { get }
    var identifier: Int? { get }
}

private struct CoreDataMigrationInstructions {
    let source: URL
    let destination: URL
    let mapping: NSMappingModel
}

private struct DTCoreDataMigrationStep {
    let sourceModel: NSManagedObjectModel
    let destinationModel: NSManagedObjectModel
    let mappingModel: NSMappingModel
    
    // MARK: Init

    init(sourceVersion: any CoreDataMigrationVersion, destinationVersion: any CoreDataMigrationVersion, in bundle: Bundle) {
        let sourceModel = NSManagedObjectModel.managedObjectModel(for: sourceVersion, in: bundle)
        let destinationModel = NSManagedObjectModel.managedObjectModel(for: destinationVersion, in: bundle)

        guard let mappingModel = DTCoreDataMigrationStep.mappingModel(fromSourceModel: sourceModel, toDestinationModel: destinationModel, from: bundle) else {
            fatalError("Expected modal mapping not present")
        }

        self.sourceModel = sourceModel
        self.destinationModel = destinationModel
        self.mappingModel = mappingModel
    }

    // MARK: - Mapping

    private static func mappingModel(fromSourceModel sourceModel: NSManagedObjectModel, toDestinationModel destinationModel: NSManagedObjectModel, from bundle: Bundle) -> NSMappingModel? {
        guard let customMapping = customMappingModel(fromSourceModel: sourceModel, toDestinationModel: destinationModel, from: bundle) else {
            return inferredMappingModel(fromSourceModel: sourceModel, toDestinationModel: destinationModel)
        }

        return customMapping
    }

    private static func inferredMappingModel(fromSourceModel sourceModel: NSManagedObjectModel, toDestinationModel destinationModel: NSManagedObjectModel) -> NSMappingModel? {
        return try? NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: destinationModel)
    }

    private static func customMappingModel(fromSourceModel sourceModel: NSManagedObjectModel, toDestinationModel destinationModel: NSManagedObjectModel, from bundle: Bundle) -> NSMappingModel? {
        return NSMappingModel(from: [bundle], forSourceModel: sourceModel, destinationModel: destinationModel)
    }
}

private extension CoreDataMigrationVersion {
    // MARK: - Compatible

    static func compatibleVersionForStoreMetadata(_ metadata: [String: Any], in bundle: Bundle = .main) -> Self? {
        let modelURLs = bundle.urls(forResourcesWithExtension: "momd", subdirectory: nil)?.flatMap { momdURL -> [URL] in
            return bundle.urls(forResourcesWithExtension: "mom", subdirectory: momdURL.lastPathComponent) ?? []
        } ?? []
        var models: [NSManagedObjectModel] = []
        models = modelURLs
            .compactMap { NSManagedObjectModel(contentsOf: $0) }
            .filter {
                $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
            }
            .sorted { $0.identifier < $1.identifier }
        
        let compatibleVersion = Self.allCases.first {
            return $0.identifier == models.last?.identifier
        }

        return compatibleVersion
    }
}

private extension NSManagedObjectModel {

    // MARK: - Resource
    static func managedObjectModel(for version: any CoreDataMigrationVersion, in bundle: Bundle) -> NSManagedObjectModel {
        let modelURLs = bundle.urls(forResourcesWithExtension: "momd", subdirectory: nil)?
            .flatMap { momdURL -> [URL] in
                return bundle.urls(forResourcesWithExtension: "mom", subdirectory: momdURL.lastPathComponent) ?? []
            } ?? []
        
        let _model = modelURLs
            .compactMap { NSManagedObjectModel(contentsOf: $0) }
            .first { $0.identifier == version.identifier }
        
        guard let model = _model else {
            fatalError("unable to load model in bundle")
        }
        return model
    }
    
    static func managedObjectModel(forResource resource: String) -> NSManagedObjectModel {
        let mainBundle = Bundle.main
        let subdirectory = "CoreDataMigration_Example.momd"
        let omoURL = mainBundle.url(forResource: resource, withExtension: "omo", subdirectory: subdirectory) // optimised model file
        let momURL = mainBundle.url(forResource: resource, withExtension: "mom", subdirectory: subdirectory)

        guard let url = omoURL ?? momURL else {
            fatalError("unable to find model in bundle")
        }

        guard let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("unable to load model in bundle")
        }

        return model
    }
    
    static func compatibleModelForStoreMetadata(_ metadata: [String: Any], bundle: Bundle) -> NSManagedObjectModel? {
        return NSManagedObjectModel.mergedModel(from: [bundle], forStoreMetadata: metadata)
    }
}

private extension NSPersistentStoreCoordinator {

    // MARK: - Destroy

    static func destroyStore(at storeURL: URL) {
        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            try persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
        } catch let error {
            fatalError("failed to destroy persistent store at \(storeURL), error: \(error)")
        }
    }

    // MARK: - Replace

    static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) {
        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            try persistentStoreCoordinator.replacePersistentStore(at: targetURL, destinationOptions: nil, withPersistentStoreFrom: sourceURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
        } catch let error {
            fatalError("failed to replace persistent store at \(targetURL) with \(sourceURL), error: \(error)")
        }
    }

    // MARK: - Meta

    static func metadata(at storeURL: URL) -> [String: Any]? {
        return try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil)
    }

    // MARK: - Add

    func addPersistentStore(at storeURL: URL, options: [AnyHashable: Any]) -> NSPersistentStore {
        do {
            return try addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
        } catch let error {
            fatalError("failed to add persistent store to coordinator, error: \(error)")
        }
    }
}

internal extension CoreDataMigratorProtocol {
    var current: T {
        return T.current
    }
    // MARK: - Check
    
    func requiresMigration(at storeURL: URL, in bundle: Bundle = .main, toVersion version: some CoreDataMigrationVersion) -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }

        if let compatibleVersion = T.compatibleVersionForStoreMetadata(metadata, in: bundle) {
            return (compatibleVersion != version as! Self.T)
        } else {
            try? FileManager.default.removeItem(at: storeURL)
            return false
        }
    }

    //Omitted other methods
    // MARK: - Migration

    func migrateStore(at storeURL: URL, in bundle: Bundle = .main, toVersion version: some CoreDataMigrationVersion) {
        forceWALCheckpointingForStore(at: storeURL, bundle: bundle)

        var currentURL = storeURL
        let migrationSteps = self.migrationStepsForStore(at: storeURL, in: bundle, toVersion: version as! Self.T)

        for migrationStep in migrationSteps {
            let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
            autoreleasepool {
                let manager = NSMigrationManager(sourceModel: migrationStep.sourceModel, destinationModel: migrationStep.destinationModel)

                do {
                    let observerEntityName = manager.observe(\.currentEntityMapping) { (value, _) in
//                        Logger.shared.logVerbose(value.currentEntityMapping.name)
                    }
                    let observerProgress = manager.observe(\.migrationProgress) { (manager: NSMigrationManager, _) in
//                        Logger.shared.logVerbose(String(manager.migrationProgress))
                    }
                    try manager.migrateStore(from: currentURL,
                                             sourceType: NSSQLiteStoreType,
                                             options: nil,
                                             with: migrationStep.mappingModel,
                                             toDestinationURL: destinationURL,
                                             destinationType: NSSQLiteStoreType,
                                             destinationOptions: nil)
                    observerEntityName.invalidate()
                    observerProgress.invalidate()
                } catch let error {
                    fatalError("failed attempting to migrate from \(migrationStep.sourceModel) to \(migrationStep.destinationModel), error: \(error)")
                }
            }
            currentURL = destinationURL
        }
        
        if currentURL != storeURL {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try? FileManager.default.removeItem(at: storeURL)
            }
            try? FileManager.default.moveItem(at: currentURL, to: storeURL)
        }
    }

    private func migrationStepsForStore(at storeURL: URL, in bundle: Bundle = .main, toVersion destinationVersion: T) -> [DTCoreDataMigrationStep] {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let sourceVersion = T.compatibleVersionForStoreMetadata(metadata, in: bundle) else {
                fatalError("unknown store version at URL \(storeURL)")
            }

        return migrationSteps(fromSourceVersion: sourceVersion, toDestinationVersion: destinationVersion, in: bundle)
    }

    private func migrationSteps(fromSourceVersion sourceVersion: T,
                                toDestinationVersion destinationVersion: T,
                                in bundle: Bundle) -> [DTCoreDataMigrationStep] {
        var sourceVersion = sourceVersion
        var migrationSteps = [DTCoreDataMigrationStep]()

        while sourceVersion != destinationVersion, let nextVersion = sourceVersion.nextVersion {
            let migrationStep = DTCoreDataMigrationStep(sourceVersion: sourceVersion, destinationVersion: nextVersion, in: bundle)
            migrationSteps.append(migrationStep)

            sourceVersion = nextVersion
        }
        return migrationSteps
    }

        // MARK: - WAL

    private func forceWALCheckpointingForStore(at storeURL: URL, bundle: Bundle) {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let currentModel = NSManagedObjectModel.compatibleModelForStoreMetadata(metadata, bundle: bundle) else {
            return
        }

        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)

            let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            let store = persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
            try persistentStoreCoordinator.remove(store)
        } catch let error {
            fatalError("failed to force WAL checkpointing, error: \(error)")
        }
    }
}
