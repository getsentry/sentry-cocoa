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
    /// Converts this value to a `SentryAttributeValue`.
    var asAttributeValue: SentryAttributeValue { get }
}

// MARK: - Default Attributable Conformances

extension String: SentryAttributable {
    public var asAttributeValue: SentryAttributeValue {
        return SentryAttributeValue.string(self)
    }
}

extension Bool: SentryAttributable {
    public var asAttributeValue: SentryAttributeValue {
        return SentryAttributeValue.boolean(self)
    }
}

extension Int: SentryAttributable {
    public var asAttributeValue: SentryAttributeValue {
        return SentryAttributeValue.integer(self)
    }
}

extension Double: SentryAttributable {
    public var asAttributeValue: SentryAttributeValue {
        return SentryAttributeValue.double(self)
    }
}

extension Float: SentryAttributable {
    public var asAttributeValue: SentryAttributeValue {
        return SentryAttributeValue.double(Double(self))
    }
}

extension Array: SentryAttributable where Element: SentryAttributable {
    public var asAttributeValue: SentryAttributeValue {
        // We need to perform a type-check of the Element, because during testing we noticed
        // that Array<Bool> was casted to Array<String>, most likely due to Objective-C bridging.

        if Element.self == String.self, let array = self as? [String] {
            return SentryAttributeValue.stringArray(array)
        }
        if Element.self == Bool.self, let array = self as? [Bool] {
            return SentryAttributeValue.booleanArray(array)
        }
        if Element.self == Int.self, let array = self as? [Int] {
            return SentryAttributeValue.integerArray(array)
        }
        if Element.self == Double.self, let array = self as? [Double] {
            return SentryAttributeValue.doubleArray(array)
        }
        if Element.self == Float.self, let array = self as? [Float] {
            return SentryAttributeValue.doubleArray(array.map(Double.init))
        }
        if let array = self as? [SentryAttribute] {
            // Handle arrays of SentryAttribute objects by checking if all have the same type
            // If all values are the same attribute value type, map to specific typed array
            // Otherwise, convert all values to string array
            
            guard !array.isEmpty else {
                // Empty array defaults to string array
                return SentryAttributeValue.stringArray([])
            }
            
            // Extract wrapped values from all SentryAttribute objects using asAttributeValue
            let wrappedValues = array.map { $0.asAttributeValue }
            
            // Try to extract values of specific types using reduce
            // If all values match a type, return the typed array; otherwise convert to string array
            
            // Try string array
            let stringValues = wrappedValues.reduce(into: [String]()) { result, value in
                if case .string(let str) = value {
                    result.append(str)
                }
            }
            if stringValues.count == wrappedValues.count {
                return SentryAttributeValue.stringArray(stringValues)
            }
            
            // Try boolean array
            let boolValues = wrappedValues.reduce(into: [Bool]()) { result, value in
                if case .boolean(let bool) = value {
                    result.append(bool)
                }
            }
            if boolValues.count == wrappedValues.count {
                return SentryAttributeValue.booleanArray(boolValues)
            }
            
            // Try integer array
            let intValues = wrappedValues.reduce(into: [Int]()) { result, value in
                if case .integer(let int) = value {
                    result.append(int)
                }
            }
            if intValues.count == wrappedValues.count {
                return SentryAttributeValue.integerArray(intValues)
            }
            
            // Try double array
            let doubleValues = wrappedValues.reduce(into: [Double]()) { result, value in
                if case .double(let double) = value {
                    result.append(double)
                }
            }
            if doubleValues.count == wrappedValues.count {
                return SentryAttributeValue.doubleArray(doubleValues)
            }
            
            // Mixed types or array types, convert all to string array
            return SentryAttributeValue.stringArray(wrappedValues.map { String(describing: $0.value) })
        }

        // For other Attributable types, convert each element to its attribute value,
        // then extract the underlying value and convert to string array
        return SentryAttributeValue.string(String(describing: self))
    }
}
