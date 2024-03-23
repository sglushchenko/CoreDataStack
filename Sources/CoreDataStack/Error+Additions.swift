//
//  File.swift
//  
//
//  Created by Serhii Hlushchenko on 23.03.2024.
//

import Foundation

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
