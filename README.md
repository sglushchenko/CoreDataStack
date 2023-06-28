# CoreDataStack

A description of this package.

In progress

# Usage

### Default usage

    let coreDataStack = CoreDataStack(name: "Database")
    coreDataStack.start()
    
### Migration usage

#### Implement Migrator versions

Set CoreDataModel identifier versions and implement steps between versions

    enum MigrationVersion: CoreDataMigrationVersion {
        case version1
        case version2
        case version3
        
        static var current: Self {
            guard let current = allCases.last else {
                fatalError("no model versions found")
            }

            return current
        }
        
        var nextVersion: Self? {
            switch self {
            case .version1:
                return .version2
            case .version2:
                return .version3
            case .version3:
                return nil
            }
        }
        
        var identifier: Int? {
            switch self {
            case .version1: return 1
            case .version2: return 2
            case .version3: return 3
            }
        }
    }

#### Implement Migrator

    class Migrator: CoreDataMigratorProtocol {
        typealias T = MigrationVersion
    }

#### Use Migrator
    let coreDataStack = CoreDataStack(name: "Database", migrator: Migrator())
    if coreDataStack.isStarted {
        // Nothing or callback
    } else {
        coreDataStack.subscribe(completion: {
            // Nothing or callback. stack was started
        })
            
        coreDataStack.start()
    }
    
#### Use NSManagedContext

//Main
        let context = NSManagedObjectContext.main
        context.performAndWait {
            ...
        }
        try? context.saveToStore()    
        
//Private
        let context = NSManagedObjectContext.context()
        context.performAndWait {
            
        }
        try? context.saveToStore()  

//Alternative

//Main
        Store.shared.performOnMain { context in
            ...
            
            try? context.saveToStore()
        }
        
//Private
        Store.shared.performOnPrivate { context in
            ...
            
            try? context.saveToStore()
        }
        
        
