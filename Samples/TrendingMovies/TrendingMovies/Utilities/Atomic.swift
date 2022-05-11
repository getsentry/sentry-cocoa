import Foundation

// https://www.objc.io/blog/2018/12/18/atomic-variables/
final class Atomic<A> {
    private let queue = DispatchQueue(label: "dev.movies.atomic")
    private var _value: A
    init(_ value: A) {
        _value = value
    }

    var value: A {
        queue.sync { self._value }
    }

    func mutate(_ transform: (inout A) -> Void) {
        queue.sync {
            transform(&self._value)
        }
    }
}
