import Foundation
import ObjectiveC

/// Extracts all property names from a class using both Objective-C runtime and Swift Mirror.
///
/// This combines two approaches:
/// 1. **Objective-C runtime** (`class_copyPropertyList`): Captures all `@objc` properties,
///    including computed ones like `sampleRate`. This is essential because Swift's `Mirror`
///    only reflects stored properties, not computed ones.
/// 2. **Swift Mirror**: Captures Swift-only stored properties that aren't exposed to Objective-C.
///
/// The results are combined into a single set, automatically eliminating duplicates.
///
/// - Parameter type: The class type to extract properties from.
/// - Returns: A set of property names declared on the class.
func extractPropertyNames(from type: AnyClass) -> Set<String> {
    var properties = Set<String>()
    
    // Extract @objc properties using Objective-C runtime
    extractObjcProperties(from: type, into: &properties)
    
    // Extract Swift stored properties using Mirror
    extractSwiftProperties(from: type, into: &properties)
    
    return properties
}

// MARK: - Private Helpers

/// Extracts @objc properties using Objective-C runtime introspection.
private func extractObjcProperties(from type: AnyClass, into properties: inout Set<String>) {
    var propertyCount: UInt32 = 0
    guard let propertyList = class_copyPropertyList(type, &propertyCount) else {
        return
    }
    
    defer { free(propertyList) }
    
    for i in 0..<Int(propertyCount) {
        let property = propertyList[i]
        let name = String(cString: property_getName(property))
        properties.insert(name)
    }
}

/// Extracts Swift stored properties using Mirror reflection.
/// Excludes private backing store properties (those starting with underscore).
private func extractSwiftProperties(from type: AnyClass, into properties: inout Set<String>) {
    // Create an instance to reflect on
    guard let nsObjectType = type as? NSObject.Type else {
        return
    }
    
    let instance = nsObjectType.init()
    let mirror = Mirror(reflecting: instance)
    
    for child in mirror.children {
        if let label = child.label {
            // Skip private backing store properties (e.g., _sampleRate)
            if label.hasPrefix("_") {
                continue
            }
            properties.insert(label)
        }
    }
}
