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

extension Array: SentryAttributeValuable {
    public var asAttributeValue: SentryAttributeValue {
        // Arrays can be heterogenous, therefore we must validate if all elements are of the same type.
        // We must assert the element type too, because due to Objective-C bridging we noticed invalid conversions
        // of empty String Arrays to Bool Arrays.
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
        if let values = self as? [SentryAttributeValuable] {
            return castArrayToAttributeValue(values: values)
        }
        return .stringArray(self.map { element in
            String(describing: element)
        })
    }

    private func castArrayToAttributeValue(values: [SentryAttributeValuable]) -> SentryAttributeValue {
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
        // If the values are not homogenous we resolve the individual valuables to strings
        return .stringArray(values.map { value in
            switch value.asAttributeValue {
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

    func castValuesToBooleanArray(_ values: [SentryAttributeValuable]) -> SentryAttributeValue? {
        let mappedBooleanValues = values.compactMap { element -> Bool? in
            guard case .boolean(let value) = element.asAttributeValue else {
                return nil
            }
            return value
        }
        guard mappedBooleanValues.count == values.count else {
            return nil
        }
        return .booleanArray(mappedBooleanValues)
    }

    func castValuesToDoubleArray(_ values: [SentryAttributeValuable]) -> SentryAttributeValue? {
        let mappedDoubleValues = values.compactMap { element -> Double? in
            guard case .double(let value) = element.asAttributeValue else {
                return nil
            }
            return value
        }
        guard mappedDoubleValues.count == values.count else {
            return nil
        }
        return .doubleArray(mappedDoubleValues)
    }

    func castValuesToIntegerArray(_ values: [SentryAttributeValuable]) -> SentryAttributeValue? {
        let mappedIntegerValues = values.compactMap { element -> Int? in
            guard case .integer(let value) = element.asAttributeValue else {
                return nil
            }
            return value
        }
        guard mappedIntegerValues.count == values.count else {
            return nil
        }
        return .integerArray(mappedIntegerValues)
    }

    func castValuesToStringArray(_ values: [SentryAttributeValuable]) -> SentryAttributeValue? {
        let mappedStringValues = values.compactMap { element -> String? in
            guard case .string(let value) = element.asAttributeValue else {
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
