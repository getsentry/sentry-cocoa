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
        switch self {
        case let stringArray as [String]:
            return SentryAttribute(stringArray: stringArray)
        case let integerArray as [Int]:
            return SentryAttribute(integerArray: integerArray)
        case let boolArray as [Bool]:
            return SentryAttribute(booleanArray: boolArray)
        case let doubleArray as [Double]:
            return SentryAttribute(doubleArray: doubleArray)
        case let floatArray as [Float]:
            return SentryAttribute(floatArray: floatArray)
        case let attributeArray as [SentryAttribute]:
            // Handle arrays of SentryAttribute objects using the dedicated initializer
            // which properly handles homogeneous arrays and converts mixed types to string arrays
            return SentryAttribute(array: attributeArray)
        default:
            // For other Attributable types, convert each element to its attribute value,
            // then extract the underlying value and convert to string array
            return SentryAttribute(array: self.map(\.asAttribute))
        }
    }
}
