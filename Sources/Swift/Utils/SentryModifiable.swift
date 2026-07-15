struct SentryModifiable<Value> {
    private var _value: Value
    private(set) var isModified: Bool

    init(_ value: Value, isModified: Bool = false) {
        self._value = value
        self.isModified = isModified
    }

    var value: Value {
        get { _value }
        set {
            _value = newValue
            isModified = true
        }
    }

    mutating func markAsModified() {
        isModified = true
    }
}

extension SentryModifiable where Value: SentryRecursiveModifiable {
    mutating func setRecursivelyModifiedValue(_ newValue: Value) {
        var newValue = newValue
        newValue.markRecursivelyAsModified()
        _value = newValue
        isModified = true
    }

    mutating func markRecursivelyAsModified() {
        _value.markRecursivelyAsModified()
        isModified = true
    }
}

extension SentryModifiable: Equatable where Value: Equatable {}

protocol SentryRecursiveModifiable {
    mutating func markRecursivelyAsModified()
}
