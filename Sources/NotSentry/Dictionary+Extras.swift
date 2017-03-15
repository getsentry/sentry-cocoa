//
//  Dictionary+Extras.swift
//  Sentry
//
//  Created by David Chavez on 5/25/16.
//
//

import Foundation

extension Dictionary {
    /// Returns a dictionary containing the results of mapping the given closure
    /// over the dictionary's values.
    ///
    /// - Parameter transform: A mapping closure. `transform` accepts a
    ///   value of this dictionary as its parameter and returns a transformed
    ///   value of the same or of a different type.
    /// - Returns: A dictionary containing the transformed values of this
    ///   dictionary.
    internal func map<T>(_ transform: (Value) throws -> T) rethrows -> [Key: T] {
        var accum = [Key: T](minimumCapacity: self.count)
        
        for (key, value) in self {
            accum[key] = try transform(value)
        }
        
        return accum
    }
    
    internal mutating func unionInPlace(_ dictionary: Dictionary) {
        dictionary.forEach { self.updateValue(self[$0] ?? $1, forKey: $0) }
    }
    
    // Sets the key and value but only if value is non-nil
    internal func set(_ key: Key, value: Value?) -> [Key: Value] {
        guard let value = value else { return self }
        
        var newDict = self
        newDict[key] = value
        
        return newDict
    }
}
