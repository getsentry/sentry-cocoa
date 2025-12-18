import Foundation
import ObjectiveC
@testable import Sentry

/// Extracts property names from Objective-C classes using runtime introspection.
/// Used by SentryOptionsDocumentationSyncTests to validate documentation coverage.
struct ObjcPropertyExtractor {
    
    /// Extracts all @objc property names from a class using Objective-C runtime introspection.
    ///
    /// We use the Objective-C runtime instead of Swift's `Mirror` because `Mirror` only reflects
    /// *stored* properties, not computed ones. Many Options properties like `sampleRate` are
    /// computed properties with private backing stores (e.g., `_sampleRate`). Using `Mirror`
    /// would return the private backing store names instead of the public property names that
    /// need documentation coverage.
    ///
    /// - Parameter type: The class type to extract properties from. Defaults to `Options.self`.
    /// - Returns: A set of property names declared on the class.
    func extractPropertyNames(from type: AnyClass = Options.self) -> Set<String> {
        var properties = Set<String>()
        
        var propertyCount: UInt32 = 0
        guard let propertyList = class_copyPropertyList(type, &propertyCount) else {
            return properties
        }
        
        defer { free(propertyList) }
        
        for i in 0..<Int(propertyCount) {
            let property = propertyList[i]
            let name = String(cString: property_getName(property))
            properties.insert(name)
        }
        
        return properties
    }
}
