import Foundation
import ObjectiveC

/// Extracts all property names from an object using both Objective-C runtime and Swift Mirror.
///
/// This function requires an instance because Swift's `Mirror` can only reflect on instances,
/// not types. While Objective-C runtime introspection works with types, we need the instance
/// for Mirror to capture Swift-only stored properties.
///
/// This combines two approaches:
/// 1. **Objective-C runtime** (`class_copyPropertyList`): Captures all `@objc` properties,
///    including computed ones like `sampleRate`. This is essential because Swift's `Mirror`
///    only reflects stored properties, not computed ones.
/// 2. **Swift Mirror**: Captures Swift-only stored properties that aren't exposed to Objective-C.
///
/// The results are combined into a single set, automatically eliminating duplicates.
///
/// - Parameter instance: The object instance to extract properties from.
/// - Returns: A set of property names declared on the instance's class.
func extractPropertyNames(from instance: AnyObject) -> Set<String> {
    var properties = Set<String>()
    
    // Extract @objc properties using Objective-C runtime
    extractObjcProperties(from: type(of: instance), into: &properties)
    
    // Extract Swift stored properties using Mirror
    extractSwiftProperties(from: instance, into: &properties)
    
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
private func extractSwiftProperties(from instance: AnyObject, into properties: inout Set<String>) {
    let swiftProperties = Mirror(reflecting: instance).children
        .compactMap { $0.label }
        .filter { !$0.hasPrefix("_") } // Skip private backing store properties (e.g., _sampleRate)
    
    properties.formUnion(swiftProperties)
}
