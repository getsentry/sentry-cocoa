//
//  Dictionary+Extras.swift
//  SentrySwift
//
//  Created by David Chavez on 25/05/16.
//
//

import Foundation

extension Dictionary {
    internal mutating func unionInPlace(_ dictionary: Dictionary) {
        dictionary.forEach { self.updateValue(self[$0] ?? $1, forKey: $0) }
    }
    
    // Sets the key and value but only if value is non-nil
    internal func set(_ key: Key, value: Value?) -> Dictionary<Key, Value> {
        guard let value = value else { return self }
        
        var newDict = self
        newDict[key] = value
        
        return newDict
    }
}
