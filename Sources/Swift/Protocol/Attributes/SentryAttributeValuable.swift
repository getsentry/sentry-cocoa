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

extension Array: SentryAttributeValuable where Element: SentryAttributeValuable {
    public var asAttributeValue: SentryAttributeValue {
        // Arrays can be heterogenous, therefore we must validate if all elements
        // are of the same type
        if let values = self as? [Bool] {
            return .booleanArray(values)
        }
        if let values = self as? [Double] {
            return .doubleArray(values)
        }
        if let values = self as? [Float] {
            return .doubleArray(values.map(Double.init))
        }
        if let values = self as? [Int] {
            return .integerArray(values)
        }
        if let values = self as? [String] {
            return .stringArray(values)
        }
        return .stringArray(self.map { element in
            String(describing: element)
        })
    }
}
