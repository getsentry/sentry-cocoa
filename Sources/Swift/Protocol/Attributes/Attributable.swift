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
public protocol Attributable: Encodable {
    /// Converts this value to a `SentryAttribute`.
    var asAttribute: SentryAttribute { get }
}

// MARK: - Default Attributable Conformances

extension String: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(string: self)
    }
}

extension Bool: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(boolean: self)
    }
}

extension Int: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(integer: self)
    }
}

extension Double: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(double: self)
    }
}

extension Float: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(float: self)
    }
}

extension Array: Attributable where Element: Attributable {
    public var asAttribute: SentryAttribute {
        return SentryAttribute(array: self.map { attr in
            SentryAttribute(value: attr)
        })
    }
}
