public protocol SentryAttributeValuable {
    var asAttributeValue: SentryAttributeValue { get }
}

extension String: SentryAttributeValuable {
    public var asAttributeValue: SentryAttributeValue {
        return .string(self)
    }
}

extension Bool: SentryAttributeValuable {
    public var asAttributeValue: SentryAttributeValue {
        return .boolean(self)
    }
}

extension Int: SentryAttributeValuable {
    public var asAttributeValue: SentryAttributeValue {
        return .integer(self)
    }
}

extension Double: SentryAttributeValuable {
    public var asAttributeValue: SentryAttributeValue {
        return .double(self)
    }
}

extension Float: SentryAttributeValuable {
    public var asAttributeValue: SentryAttributeValue {
        return .double(Double(self))
    }
}
