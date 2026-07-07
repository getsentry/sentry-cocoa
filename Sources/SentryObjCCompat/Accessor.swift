// Read-write accessor for value types stored in @objc wrapper classes.
//
// Wraps a getter/setter closure pair so struct properties can be mutated
// in place from Objective-C (e.g. `options.dataCollection.userInfo = NO`)
// without the change being lost to an ephemeral copy.
//
// Standalone storage delegates to Box<T> for the same resilience reasons
// documented in Box.swift.
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

    init(_ value: T) {
        var box = Box(value)
        self.getter = { box.value }
        self.setter = { box = Box($0) }
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
