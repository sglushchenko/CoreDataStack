//
//  SharedContainer.swift
//  SecureChat
//
//  Created by Sergey Glushchenko on 28.06.2023.
//

import Foundation

public class SharedContainer {
    public static let shared = SharedContainer()
    
    public private(set) var userDefaults: UserDefaults = UserDefaults.standard
    
    public var applicationGroup: String? {
        didSet {
            userDefaults = UserDefaults(suiteName: applicationGroup)!
            if let applicationGroup = applicationGroup {
                container = SecureFileManagerContainer(applicationGroup: applicationGroup)
            } else {
                container = FileManagerContainer()
            }
        }
    }
    
    public private(set) var container: FileManagerContainerProtocol = FileManagerContainer()
    
    internal func moveFile(withName name: String, from oldDir: String, to newDir: String) {
        let fm = FileManager.default
        let source = (oldDir as NSString).appendingPathComponent(name)
        
        guard fm.fileExists(atPath: source) else { return }
        
//        Logger.shared.logDebug("Shared container: moving file \(name)", domain: LogCallDomain)
        
        let dest = (newDir as NSString).appendingPathComponent(name)
        try? fm.moveItem(atPath: source, toPath: dest)
    }
}
