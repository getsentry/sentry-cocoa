// Read-write accessor for value types stored in @objc wrapper classes.
//
// Wraps a getter/setter closure pair so struct properties can be mutated
// in place from Objective-C (e.g. `options.dataCollection.userInfo = NO`)
// without the change being lost to an ephemeral copy.
internal final class Accessor<T> {
    private let getter: () -> T
    private let setter: (T) -> Void

    var value: T {
        get { getter() }
        set { setter(newValue) }
    }

    init(get: @escaping () -> T, set: @escaping (T) -> Void) {
        self.getter = get
        self.setter = set
    }

    init<Root: AnyObject>(root: Root, keyPath: ReferenceWritableKeyPath<Root, T>) {
        self.getter = { root[keyPath: keyPath] }
        self.setter = { root[keyPath: keyPath] = $0 }
    }

    init(_ value: T) {
        var value = value
        self.getter = { value }
        self.setter = { value = $0 }
    }

    func child<U>(
        _ keyPath: WritableKeyPath<T, U>
    ) -> Accessor<U> {
        Accessor<U>(
            get: { self.value[keyPath: keyPath] },
            set: { self.value[keyPath: keyPath] = $0 }
        )
    }
}
