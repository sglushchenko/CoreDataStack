//
//  DatabaseStack.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 28.06.2023.
//

import Foundation
public typealias CoreDataSetupCompletion = () -> Void

class CoreDataStack {
    private enum State {
        case notRunned, running, started, error
    }
    
    private let name: String
    private var completionHandlers: [CoreDataSetupCompletion] = []
    
//    var loggerHandler: ((_ message: String,
//                         _ file: String,
//                         _ func: String,
//                         _ line: UInt) -> Void)?
    
    private var state: State = .notRunned
    
    private let queue = DispatchQueue(label: "")
    private var migrator: (any CoreDataMigratorProtocol)?

    ///*
    /// Check is started CoreData stack or not
    ///*
    public var isStarted: Bool { return state == .started }
    
    ///*
    /// @name - Model name
    /// @migrator - Migrator for correct manual migrations step by step
    ///*
    public init(name: String, migrator: (any CoreDataMigratorProtocol)? = nil) {
        self.name = name
        self.migrator = migrator
    }
    
    ///*
    ///Start CoreData stack
    /// @bundle - Bundle is CoreData Model in different Bundle
    ///
    ///*
    public func start(with bundle: Bundle = .main) {
        guard state == .notRunned else { return }
        state = .running
        
        let queue = DispatchQueue(label: "Migration")
        queue.async {
//            Logger.shared.logDebug("Starting store", domain: LogCommonDomain)
            let dbFolderUrl = SharedContainer.shared.container.url(name: self.name, in: .library)

//            DTMigrationLogger.shared.logFolderFiles(atUrl: dbFolderUrl)
            CoreDataStack.createDBFolderIfNeeded(dbFolderUrl)
            CoreDataStack.clearDBFolderIfNeeded(dbFolderUrl, name: self.name)
            
            Store.shared.configureAsync(name: self.name, bundle: bundle, storePath: dbFolderUrl.path, migrator: self.migrator) { (error) in
                if let error = error as NSError? {
//                    Logger.shared.logError("Core Data error: \(error)", domain: LogCommonDomain)
                    NSException(name: NSExceptionName(rawValue: error.domain), reason: error.localizedDescription, userInfo: error.userInfo).raise()
                }
                
                Store.shared.start {
                    self.notify()
                }
            }
        }
    }
    
    ///*
    ///We can get notification when CoreData Stack will be started. You can use it when have migration and it take time.
    ///Should be subscribed before start
    ///*
    public func subscribe(completion: @escaping CoreDataSetupCompletion) {
        if self.isStarted {
//            Logger.shared.logDebug("Store is started already", domain: LogCommonDomain)
            completion()
            return
        }
        
        queue.sync {
            self.completionHandlers.append(completion)
        }
    }
    
    private func notify() {
        DispatchQueue.main.async {
//            Logger.shared.logError("Store started", domain: LogCommonDomain)
            for completion in self.completionHandlers {
                completion()
            }
            
            
            self.queue.sync {
                self.completionHandlers = []
            }
        }
    }
    
    private static func createDBFolderIfNeeded(_ dbFolderUrl: URL) {
        guard !FileManager.default.fileExists(atPath: dbFolderUrl.path) else { return }
        
        do {
            try FileManager.default.createDirectory(at: dbFolderUrl, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print(error)
//            Logger.shared.logError("Error creating DB folder: \(dbFolderUrl), \(error)")
        }
    }
    
    private static func clearDBFolderIfNeeded(_ dbFolderUrl: URL, name: String) {
        guard FileManager.default.fileExists(atPath: dbFolderUrl.path) else { return }
        
        let contents = try? FileManager.default.contentsOfDirectory(atPath: dbFolderUrl.path)
        for content in contents ?? [] {
            if !dbFolderUrl.appendingPathComponent(content).deletingPathExtension().path.hasSuffix(name) {
                try? FileManager.default.removeItem(at: dbFolderUrl.appendingPathComponent(content))
            }
        }
    }
}
