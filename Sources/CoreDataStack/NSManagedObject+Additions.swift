//
//  NSManagedObject+Additions.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 29.06.2023.
//

import Foundation
import CoreData

public extension NSManagedObject {
    static func fetchOne<T: NSManagedObject>(in context: NSManagedObjectContext = .context(), attribute: String? = nil, value: Any? = nil, completion: @escaping (_ item: T?) -> Void) {
        self.fetch(in: context, attribute: attribute, value: value) { result in
            completion(try? result.get().first)
        }
    }
    
    static func fetch<T: NSManagedObject>(in context: NSManagedObjectContext = .context(), attribute: String? = nil, value: Any? = nil, completion: @escaping (_ result: Result<[T], Error>) -> Void) {
        if value != nil && attribute == nil {
            completion(.failure("Attribute cannot be nil if value is not nil"))
            return
        }
        
        var predicate: NSPredicate?
        if let attribute = attribute {
            if let value = value as? NSObject {
                predicate = NSPredicate(format: "%@ = %@", attribute, value)
            } else {
                predicate = NSPredicate(format: "%@ = nil", attribute)
            }
        }
        
        fetch(in: context, with: predicate, completion: completion)
    }
    
    static func fetch<T: NSManagedObject>(in context: NSManagedObjectContext, with predicate: NSPredicate? = nil, completion: @escaping (_ result: Result<[T], Error>) -> Void) {
        context.perform {
            let request: NSFetchRequest<Self> = Self.createFetchRequest()
            request.predicate = predicate
            do {
                let result = try context.fetch(request) as? [T]
                completion(.success(result ?? []))
            }
            catch let error {
                completion(.failure(error))
            }
        }
    }
    
    static func fetch<T: NSManagedObject>(in context: NSManagedObjectContext, with predicate: NSPredicate? = nil) -> [T] {
        var result: [T] = []
        context.performAndWait {
            let request: NSFetchRequest<Self> = Self.createFetchRequest()
            request.predicate = predicate
            do {
                result = try context.fetch(request) as? [T] ?? []
            }
            catch let error {
                print(error)
            }
        }
        return result
    }
}

public extension NSManagedObject {
    class func createFetchRequest<T: NSFetchRequestResult>() -> NSFetchRequest<T> {
        return NSFetchRequest<T>(entityName: entityName())
    }
    
    public class func entityName() -> String {
        return String(describing: self)
    }
}

public extension NSManagedObject {
    static func create(in context: NSManagedObjectContext, with block: (_ managedObject: Self) -> Void) -> Self {
        let object = Self.init(context: context)
        block(object)
        return object
    }
    
    static func create(in context: NSManagedObjectContext) -> Self {
        let object = Self.init(context: context)
        return object
    }
}

public extension NSManagedObject {
    func `in`(_ context: NSManagedObjectContext) -> Self? {
        let object = context.object(with: self.objectID)
        return try? context.existingObject(with: object.objectID) as? Self// as? T
    }
}
