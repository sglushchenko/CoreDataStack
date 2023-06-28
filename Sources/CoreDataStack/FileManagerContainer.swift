//
//  FileManagerContainer.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 28.06.2023.
//

import Foundation

public enum FileManagerContainerFolder {
    case library, caches, documents
}

public protocol FileManagerContainerProtocol {
    var caches: URL { get }
    var documents: URL { get }
    var library: URL { get }
    var logs: URL { get }
    var container: URL { get }
    
    func url(name: String, in folder: FileManagerContainerFolder) -> URL
}

internal class SecureFileManagerContainer: FileManagerContainerProtocol {
    private let applicationGroup: String
    
    public init(applicationGroup: String) {
        self.applicationGroup = applicationGroup
    }
    
    public var container: URL {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroup)!
    }
    
    public var caches: URL {
        return createIfNeeded(directory: "Caches")
    }
    
    public var documents: URL {
        return createIfNeeded(directory: "Documents")
    }
    
    public var library: URL {
        return createIfNeeded(directory: "Library")
    }
    
    public var logs: URL {
        return createIfNeeded(directory: "Logs")
    }
    
    //must be called in main thread, or sometimes we have bad access
    private func createIfNeeded(directory: String) -> URL {
        let fm = FileManager.default
        let resultURL = container.appendingPathComponent(directory)
        
        guard !fm.fileExists(atPath: resultURL.path) else {
            return resultURL
        }
        
        try? fm.createDirectory(at: resultURL, withIntermediateDirectories: true, attributes: nil)
        return resultURL
    }
}

internal class FileManagerContainer: FileManagerContainerProtocol {
    public var caches: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    public var documents: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    public var library: URL {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    }
    
    public var logs: URL {
        caches.appendingPathComponent("Logs")
    }
    
    public var container: URL {
        return Bundle.main.bundleURL
    }
}

public extension FileManagerContainerProtocol {
    func url(name: String, in folder: FileManagerContainerFolder) -> URL {
        switch folder {
        case .caches: return caches.appendingPathComponent(name)
        case .library: return library.appendingPathComponent(name)
        case .documents: return documents.appendingPathComponent(name)
        }
    }
}
