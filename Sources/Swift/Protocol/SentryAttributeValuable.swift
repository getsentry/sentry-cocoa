/// A protocol that represents values that can be used as structured logging attributes.
///
/// `SentryAttributeValue` provides a protocol-oriented approach for accepting attribute values
/// in public APIs. This allows APIs to accept a wide variety of types without requiring a concrete
/// enum type, making the API more flexible and user-friendly.
///
/// This is the Swift-native API for structured logging attributes. For Swift code, prefer using
/// `SentryAttributeValue` over the Objective-C-compatible `SentryAttribute` class, as it allows
/// you to pass native Swift types directly without wrapping them in a class instance.
///
/// ## Purpose
///
/// This protocol is designed to be used in public API method signatures, particularly for
/// structured logging attributes. For example:
///
/// ```swift
/// func log(_ message: String, attributes: [String: SentryAttributeValue])
/// ```
///
/// Using `SentryAttributeValue` in public APIs provides several benefits:
/// - **Flexibility**: Accepts multiple types (String, Bool, Int, Double, Float, Arrays) without
///   requiring users to wrap values in a concrete enum type
/// - **Type Safety**: The protocol ensures all values can be converted to a structured format
/// - **Conciseness**: Users can pass values directly without explicit conversions
/// - **Dictionary Clarity**: `[String: SentryAttributeValue]` clearly communicates that it's a
///   dictionary and prevents duplicate keys
///
/// ## Conforming Types
///
/// The following types conform to `SentryAttributeValue`:
/// - `String`
/// - `Bool`
/// - `Int`
/// - `Double`
/// - `Float` (converted to Double)
/// - `Array` (with various element types)
///
/// ## Implementation
///
/// Conforming types implement `asSentryAttributeContent` to convert themselves to a
/// `SentryAttributeContent` enum value, which provides the structured representation used
/// internally for encoding and type identification.
public protocol SentryAttributeValue {
    /// Converts the conforming value to a `SentryAttributeContent` enum representation.
    ///
    /// This method is used internally to convert protocol-conforming values to the structured
    /// `SentryAttributeContent` enum format for encoding and type identification.
    ///
    /// - Returns: A `SentryAttributeContent` enum case representing this value.
    var asSentryAttributeContent: SentryAttributeContent { get }
}

extension String: SentryAttributeValue {
    public var asSentryAttributeContent: SentryAttributeContent {
        return .string(self)
    }
}

extension Bool: SentryAttributeValue {
    public var asSentryAttributeContent: SentryAttributeContent {
        return .boolean(self)
    }
}

extension Int: SentryAttributeValue {
    public var asSentryAttributeContent: SentryAttributeContent {
        return .integer(self)
    }
}

extension Double: SentryAttributeValue {
    public var asSentryAttributeContent: SentryAttributeContent {
        return .double(self)
    }
}

extension Float: SentryAttributeValue {
    public var asSentryAttributeContent: SentryAttributeContent {
        return .double(Double(self))
    }
}

extension Array: SentryAttributeValue {
    /// Converts an array to a SentryAttributeContent value.
    ///
    /// This extension cannot be scoped to `where Element == SentryAttributeValue` because:
    /// - Mixed arrays (arrays containing elements of different types) are automatically converted to `[Any]` by Swift
    /// - If we used `where Element == SentryAttributeValue`, mixed arrays would not compile, preventing users
    ///   from passing heterogeneous arrays
    /// - We accept this trade-off: while we can't enforce compile-time safety for mixed arrays, we can convert
    ///   the values to strings at runtime without losing any data
    ///
    /// Arrays can be heterogenous, therefore we must validate if all elements are of the same type.
    /// We must assert the element type too, because due to Objective-C bridging we noticed invalid conversions
    /// of empty String Arrays to Bool Arrays.
    public var asSentryAttributeContent: SentryAttributeContent {
        if Element.self == Bool.self, let values = self as? [Bool] {
            return .booleanArray(values)
        }
        if Element.self == Double.self, let values = self as? [Double] {
            return .doubleArray(values)
        }
        if Element.self == Float.self, let values = self as? [Float] {
            return .doubleArray(values.map(Double.init))
        }
        if Element.self == Int.self, let values = self as? [Int] {
            return .integerArray(values)
        }
        if Element.self == String.self, let values = self as? [String] {
            return .stringArray(values)
        }
        if let values = self as? [SentryAttributeValue] {
            return castArrayToAttributeContent(values: values)
        }
        return .stringArray(self.map { element in
            String(describing: element)
        })
    }

    private func castArrayToAttributeContent(values: [SentryAttributeValue]) -> SentryAttributeContent {
        // Empty arrays cannot determine the intended type, so default to stringArray as a safe fallback
        guard !values.isEmpty else {
            return .stringArray([])
        }
        
        // Check if the values are homogeneous and can be casted to a specific array type
        if let booleanArray = castValuesToBooleanArray(values) {
            return booleanArray
        }
        if let doubleArray = castValuesToDoubleArray(values) {
            return doubleArray
        }
        if let integerArray = castValuesToIntegerArray(values) {
            return integerArray
        }
        if let stringArray = castValuesToStringArray(values) {
            return stringArray
        }
        // If the values are not homogenous we resolve the individual values to strings
        return .stringArray(values.map { value in
            switch value.asSentryAttributeContent {
            case .boolean(let value):
                return String(describing: value)
            case .double(let value):
                return String(describing: value)
            case .integer(let value):
                return String(describing: value)
            case .string(let value):
                return value
            default:
                return String(describing: value)
            }
        })
    }

    func castValuesToBooleanArray(_ values: [SentryAttributeValue]) -> SentryAttributeContent? {
        let mappedBooleanValues = values.compactMap { element -> Bool? in
            guard case .boolean(let value) = element.asSentryAttributeContent else {
                return nil
            }
            return value
        }
        guard mappedBooleanValues.count == values.count else {
            return nil
        }
        return .booleanArray(mappedBooleanValues)
    }

    func castValuesToDoubleArray(_ values: [SentryAttributeValue]) -> SentryAttributeContent? {
        let mappedDoubleValues = values.compactMap { element -> Double? in
            guard case .double(let value) = element.asSentryAttributeContent else {
                return nil
            }
            return value
        }
        guard mappedDoubleValues.count == values.count else {
            return nil
        }
        return .doubleArray(mappedDoubleValues)
    }

    func castValuesToIntegerArray(_ values: [SentryAttributeValue]) -> SentryAttributeContent? {
        let mappedIntegerValues = values.compactMap { element -> Int? in
            guard case .integer(let value) = element.asSentryAttributeContent else {
                return nil
            }
            return value
        }
        guard mappedIntegerValues.count == values.count else {
            return nil
        }
        return .integerArray(mappedIntegerValues)
    }

    func castValuesToStringArray(_ values: [SentryAttributeValue]) -> SentryAttributeContent? {
        let mappedStringValues = values.compactMap { element -> String? in
            guard case .string(let value) = element.asSentryAttributeContent else {
                return nil
            }
            return value
        }
        guard mappedStringValues.count == values.count else {
            return nil
        }
        return .stringArray(mappedStringValues)
    }   
}
