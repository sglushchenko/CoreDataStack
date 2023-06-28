//
//  NSManagedObjectContext.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 28.06.2023.
//


import CoreData

@objc public extension NSManagedObjectContext {
    
    /**
     Save changes to store synchronously
     */
    @objc(saveToStore:)
    func saveToStore() throws {
        var error: Error?
        performAndWait {
            do {
                if hasChanges {
                    try save()
                }
                parent?.performAndWait {
                    Store.shared.postChanges(from: parent)
                }
                
                try parent?.saveToStore()
            } catch let anError {
                error = anError
//                Logger.shared.logError(anError.localizedDescription, domain: LogCommonDomain)
//                Logger.shared.logError("\(String(describing: (error as NSError?)?.userInfo))", domain: LogCommonDomain)
            }
        }
        
        if let error = error { throw error }
    }
    
    /**
     Save changes to store asynchronously
     */
    @objc(saveToStoreWithComplete:)
    func saveToStore(complete: ((_ error: Error?) -> Void)?) {
        perform {
            do {
                if self.hasChanges {
                    try self.save()
                    Store.shared.postChanges(from: self.parent)
                    if let parent = self.parent {
                        parent.saveToStore(complete: complete)
                    } else {
                        DispatchQueue.main.async { complete?(nil) }
                    }
                } else {
                    DispatchQueue.main.async { complete?(nil) }
                }
            } catch let anError {
//                Logger.shared.logError(anError.localizedDescription, domain: LogCommonDomain)
                DispatchQueue.main.async { complete?(anError) }
            }
        }
    }
    
    /**
     Return main(viewContext) context
     */
    @objc(mainContext) static var main: NSManagedObjectContext {
        return Store.shared.main()
    }
    
    /**
     Create new private context
     */
    @objc static func context() -> NSManagedObjectContext {
        return Store.shared.private()
    }
}
