/// A protocol that allows types to be converted to a `SentryAttribute`.
///
/// Types conforming to this protocol can be used directly as attribute values
/// in metrics and logs. This enables using constants and variables directly
/// without explicit conversion.
///
/// Example:
/// ```swift
/// let endpoint = "api/users"
/// SentrySDK.metrics.count(key: "requests", value: 1, attributes: ["endpoint": endpoint])
/// ```
public protocol SentryAttributable: Encodable {
    /// Converts this value to a `SentryAttribute`.
    var asAttribute: SentryAttribute { get }
}

// MARK: - Default Attributable Conformances

extension String: SentryAttributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(string: self)
    }
}

extension Bool: SentryAttributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(boolean: self)
    }
}

extension Int: SentryAttributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(integer: self)
    }
}

extension Double: SentryAttributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(double: self)
    }
}

extension Float: SentryAttributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(float: self)
    }
}

extension Array: SentryAttributable where Element: SentryAttributable {
    public var asAttribute: SentryAttribute {
        // Create typed arrays directly for type safety
        if let stringArray = self as? [String] {
            return SentryAttribute(stringArray: stringArray)
        } else if let boolArray = self as? [Bool] {
            return SentryAttribute(booleanArray: boolArray)
        } else if let intArray = self as? [Int] {
            return SentryAttribute(integerArray: intArray)
        } else if let doubleArray = self as? [Double] {
            return SentryAttribute(doubleArray: doubleArray)
        } else if let floatArray = self as? [Float] {
            return SentryAttribute(floatArray: floatArray)
        } else {
            // For other Attributable types, convert to string array
            return SentryAttribute(stringArray: self.map { String(describing: $0) })
        }
    }
}
