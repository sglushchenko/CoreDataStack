//
//  Store.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 28.06.2023.
//

import Foundation
import CoreData

public class Store {
    private enum State {
        case notRunned, running, started, error
    }
    
    public typealias StoreConfigureCompletion = () -> Void
    public typealias StoreListenerBlock = (_ context: NSManagedObjectContext) -> Void
    public typealias ContextDidSaveListenerBlock = (_ context: NSManagedObjectContext, _ userInfo: [AnyHashable: Any]) -> Void
    
    public static var shared = Store()
    
    private var state: State = .notRunned
    var isStarted: Bool {
        return state == .started
    }
    
    private var listeners: [StoreListenerBlock] = []
    private var completions = [StoreConfigureCompletion]()
    private var contextDidSaveListeners: [ContextDidSaveListenerBlock] = []
    
    private var name: String = ""
    private var container: NSPersistentContainer!
    
    internal var migrator: (any CoreDataMigratorProtocol)?// = { return Migrator<MigrationVersion>() }()
    
    public func configureAsync(name: String, bundle: Bundle = .main, storePath: String, migrator: (any CoreDataMigratorProtocol)? = nil, options: [String: Any]? = nil, completion: @escaping ((Error?) -> Void)) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.configure(name: name, bundle: bundle, storePath: storePath, migrator: migrator, options: options)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
    
    public func configure(name: String, bundle: Bundle = .main, storePath: String, migrator: (any CoreDataMigratorProtocol)? = nil, options: [String: Any]? = nil) throws {
        self.name = name
        
        let storeURL: URL = URL(fileURLWithPath: "\(name).sqlite", relativeTo: URL(fileURLWithPath: storePath))
        
        self.migrateStoreToSharedContainer(with: name)
        
        // CoreData migrates from the current version to the latest without taking intermediate versions
        // In order for the migration to pass through all versions, a custom migration process was written.
        // For it to work, you need to specify the version number for the object model in the "Identifier" field in the user interface ("versionIdentifiers" of the "NSManagedObjectModel" class) and implement Migrator.
        if let migrator = migrator {
            self.migrator = migrator
            self.migrateStoreIfNeeded(at: storeURL, in: bundle) {}
            self.migrator = nil // Release Migrator
        }
        
        guard
            let modelUrl = bundle.url(forResource: name, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelUrl), name.count > 0
        else {
            let userInfo = [NSLocalizedDescriptionKey: "Error loading model from bundle"]
            throw NSError(domain: "StoreErrorDomain", code: -1, userInfo: userInfo)
        }
            
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.setOption("WAL" as NSObject, forKey: "journal_mode")
        storeDescription.shouldAddStoreAsynchronously = true
            
        self.container = NSPersistentContainer(name: name, managedObjectModel: model)
        self.container.persistentStoreDescriptions = [storeDescription]
    }
    
    private func migrateStoreToSharedContainer(with name: String) {
        SharedContainer.shared.moveFile(withName: name, from: NSPersistentContainer.defaultDirectoryURL().path, to: SharedContainer.shared.container.library.path)
    }
    
    private func migrateStoreIfNeeded(at storeURL: URL, in bundle: Bundle = .main, completion: @escaping () -> Void) {
        guard let migrator = self.migrator else { completion(); return }
        let currentVersion = migrator.current
        
        if migrator.requiresMigration(at: storeURL, in: bundle, toVersion: currentVersion) {
            migrator.migrateStore(at: storeURL, in: bundle, toVersion: migrator.current)
        }
    }
    
    public func start(completion: @escaping StoreConfigureCompletion) {
        notify(completion: completion)

        guard state == .notRunned else { return }
        
        state = .running
        self.container.loadPersistentStores { (_, error) in
//            Logger.shared.logDebug("Finished loading persistent stores")
            self.state = .started
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            if let error = error {
                print(error)
//                Logger.shared.logError("Error loading persistent stores: \(error)")
            } else {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(self.managedObjectContextDidSave),
                    name: NSNotification.Name.NSManagedObjectContextDidSave,
                    object: self.container.viewContext)
            }
            
            let completions = self.completions
            self.completions = []
            for completion in completions {
                completion()
            }
        }
    }
    
    public func notify(completion: @escaping StoreConfigureCompletion) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isStarted {
//                Logger.shared.logDebug("Store is started already", domain: LogCommonDomain)
                completion()
            } else {
                self.completions.append(completion)
            }
        }
    }
    
    @objc public func addChangesListener(block: @escaping StoreListenerBlock) {
        self.listeners.append(block)
    }
    
    internal func postChanges(from context: NSManagedObjectContext?) {
        guard let context = context else { return }
        
        for listener in self.listeners {
            listener(context)
        }
    }
    
    public func addContextDidSaveListener(block: @escaping ContextDidSaveListenerBlock) {
        self.contextDidSaveListeners.append(block)
    }
    
    @objc private func managedObjectContextDidSave(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let context = notification.object as? NSManagedObjectContext else { return }
        
        for listener in self.contextDidSaveListeners {
            listener(context, userInfo)
        }
    }
    
    internal func main() -> NSManagedObjectContext {
        guard isStarted else {
            fatalError("Store is not configured.")
        }
        return self.container.viewContext
    }
    
    internal func `private`() -> NSManagedObjectContext {
        guard isStarted else {
            fatalError("Store is not configured.")
        }
        
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = main()
        return privateContext
    }
}
