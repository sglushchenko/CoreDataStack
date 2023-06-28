//
//  NSManagedObjectContext+Perform.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 28.06.2023.
//

import CoreData

public extension Store {
    func performOnMain(_ closure: @escaping (_ context: NSManagedObjectContext) -> Void) {
        perform(on: self.main(), in: closure)
    }
    
    func performAndWaitOnMain(_ closure: @escaping (_ context: NSManagedObjectContext) -> Void) {
        performAndWait(on: self.main(), in: closure)
    }
    
    func performOnPrivate(_ closure: @escaping (_ context: NSManagedObjectContext) -> Void) {
        perform(on: self.private(), in: closure)
    }
    
    func performAndWaitOnPrivate(_ closure: @escaping (_ context: NSManagedObjectContext) -> Void) {
        performAndWait(on: self.private(), in: closure)
    }
}

private extension Store {
    func perform(on context: NSManagedObjectContext, in closure: @escaping (NSManagedObjectContext) -> Void) {
        context.perform { closure(context) }
    }
    
    func performAndWait(on context: NSManagedObjectContext, in closure: @escaping (NSManagedObjectContext) -> Void) {
        context.performAndWait { closure(context) }
    }
}
