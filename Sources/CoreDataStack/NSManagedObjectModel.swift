//
//  NSManagedObjectModel.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 28.06.2023.
//


import CoreData

internal extension NSManagedObjectModel {
    var identifier: Int {
        Int(versionIdentifiers.first as? String ?? "") ?? 0
    }
}
